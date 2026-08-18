import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'supabase_service.dart';

class CommitmentLetter {
  final String id;
  final String content;
  final String userName;
  final DateTime createdAt;

  CommitmentLetter({
    required this.id,
    required this.content,
    required this.userName,
    required this.createdAt,
  });

  factory CommitmentLetter.fromJson(Map<String, dynamic> json) {
    return CommitmentLetter(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      userName: json['userName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'userName': userName,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Offline-first commitment service.
///
/// Architecture: Local (SharedPreferences) → Source of Truth → Sync Queue → Firebase.
/// - All writes are saved locally FIRST and notify the UI immediately.
/// - Remote changes are MERGED into local (local always wins for pending edits).
/// - Pending operations are queued and replayed to Firebase in the background,
///   and retried later if the network/Firebase is unavailable.
class CommitmentService extends ChangeNotifier {
  List<CommitmentLetter> _letters = [];
  int _currentIndex = 0;

  static const String _lettersKey = 'commitment_letters';
  static const String _pendingKey = 'commitment_pending_ops';

  /// Pending operations: [{op: 'create'|'update'|'delete', id, letter?, ts}]
  List<Map<String, dynamic>> _pendingOps = [];
  Timer? _retryTimer;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CommitmentLetter> get letters => _letters;
  int get totalLetters => _letters.length;
  CommitmentLetter? get currentLetter =>
      _letters.isNotEmpty ? _letters[_currentIndex] : null;
  bool get hasPendingSync => _pendingOps.isNotEmpty;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference? get _collection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('commitment_letters');
  }

  /// Load local data first, then merge remote in the background.
  Future<void> loadLetters() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final lettersJson = prefs.getString(_lettersKey);
      if (lettersJson != null && lettersJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(lettersJson);
        _letters =
            decoded.map((e) => CommitmentLetter.fromJson(e)).toList();
        _letters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final pendingJson = prefs.getString(_pendingKey);
      if (pendingJson != null && pendingJson.isNotEmpty) {
        _pendingOps =
            (jsonDecode(pendingJson) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error loading commitment letters: $e');
    }
    notifyListeners();

    // Merge remote (never overwrite local) and flush pending sync.
    await _mergeFromRemote();
    unawaited(_flushPendingSync());
  }

  /// Merge remote letters into local WITHOUT wiping local data.
  /// Local is the source of truth; remote-only letters are added.
  Future<void> _mergeFromRemote() async {
    final col = _collection;
    if (col == null) return;
    try {
      final snapshot = await col.get();
      if (snapshot.docs.isEmpty) return;

      final localIds = _letters.map((l) => l.id).toSet();
      var changed = false;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final remote = CommitmentLetter.fromJson(data);
        if (!localIds.contains(remote.id)) {
          _letters.add(remote);
          changed = true;
        }
      }

      if (changed) {
        _letters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveLocally();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error merging commitment letters from Firestore: $e');
    }
  }

  Future<void> _saveLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lettersKey,
        jsonEncode(_letters.map((l) => l.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving commitment letters locally: $e');
    }
  }

  Future<void> _savePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, jsonEncode(_pendingOps));
    } catch (e) {
      debugPrint('Error saving commitment pending ops: $e');
    }
  }

  void _enqueue(String op, String id, {CommitmentLetter? letter}) {
    _pendingOps.removeWhere((o) => o['id'] == id);
    _pendingOps.add({
      'op': op,
      'id': id,
      if (letter != null) 'letter': letter.toJson(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    unawaited(_savePending());
    unawaited(_flushPendingSync());
  }

  /// Replay pending operations to Firebase in order.
  /// Keeps items that fail so they can be retried later.
  Future<void> _flushPendingSync() async {
    if (_pendingOps.isEmpty) return;
    final col = _collection;
    if (col == null) return; // offline / not logged in — keep queue

    final ops = List<Map<String, dynamic>>.from(_pendingOps);
    for (final op in ops) {
      final id = op['id'] as String;
      try {
        if (op['op'] == 'delete') {
          await col.doc(id).delete();
        } else {
          final letter =
              CommitmentLetter.fromJson(op['letter'] as Map<String, dynamic>);
          await col.doc(id).set(letter.toJson());
        }
        _pendingOps.removeWhere((o) => o['id'] == id);
        await _savePending();
      } catch (e) {
        debugPrint('Commitment pending sync failed (will retry): $e');
        break; // stop; retry on next occasion
      }
    }

    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_pendingOps.isEmpty) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () {
      unawaited(_flushPendingSync());
    });
  }

  void nextLetter() {
    if (_letters.isNotEmpty) {
      _currentIndex = (_currentIndex + 1) % _letters.length;
      notifyListeners();
    }
  }

  void previousLetter() {
    if (_letters.isNotEmpty) {
      _currentIndex = (_currentIndex - 1 + _letters.length) % _letters.length;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _letters.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  Future<bool> addLetter(String content, String userName) async {
    try {
      final letter = CommitmentLetter(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        userName: userName,
        createdAt: DateTime.now(),
      );
      _letters.insert(0, letter);
      _currentIndex = 0;
      await _saveLocally();
      notifyListeners();

      _enqueue('create', letter.id, letter: letter);

      // Best-effort Supabase sync (never blocks, never throws).
      SupabaseService.saveCommitmentLetters(
        _letters.map((l) => l.toJson()).toList(),
      ).catchError((e) => debugPrint('Supabase Commitment Sync Error: $e'));

      return true;
    } catch (e) {
      debugPrint('Error adding commitment letter: $e');
      return false;
    }
  }

  Future<void> updateLetter(String id, String content) async {
    final index = _letters.indexWhere((l) => l.id == id);
    if (index == -1) return;
    final updatedLetter = CommitmentLetter(
      id: id,
      content: content,
      userName: _letters[index].userName,
      createdAt: _letters[index].createdAt,
    );
    _letters[index] = updatedLetter;
    await _saveLocally();
    notifyListeners();

    _enqueue('update', id, letter: updatedLetter);
  }

  Future<void> deleteLetter(String id) async {
    _letters.removeWhere((l) => l.id == id);
    if (_currentIndex >= _letters.length && _letters.isNotEmpty) {
      _currentIndex = _letters.length - 1;
    }
    await _saveLocally();
    notifyListeners();

    _enqueue('delete', id);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  String formatDate(DateTime date, String language) {
    final months = language == 'arabic'
        ? [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر'
          ]
        : language == 'kurdish'
            ? [
                'کانوونی دووەم',
                'شوبات',
                'ئازار',
                'نیسان',
                'ئایار',
                'حوزەیران',
                'تەمووز',
                'ئاب',
                'ئەیلوول',
                'تشرینی یەکەم',
                'تشرینی دووەم',
                'کانوونی یەکەم'
              ]
            : [
                'January',
                'February',
                'March',
                'April',
                'May',
                'June',
                'July',
                'August',
                'September',
                'October',
                'November',
                'December'
              ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
