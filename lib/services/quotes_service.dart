import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Quote {
  final String id;
  final String text;
  final String textAr;
  final String textKu;
  final DateTime createdAt;
  
  // Getter for English text (uses text field)
  String get textEn => text;

  Quote({required this.id, required this.text, required this.textAr, required this.textKu, required this.createdAt});

  factory Quote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Quote(
      id: doc.id,
      text: data['text'] ?? '',
      textAr: data['textAr'] ?? data['text'] ?? '',
      textKu: data['textKu'] ?? data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Define fromJson for cache loading
  factory Quote.fromJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return Quote(
      id: map['id'],
      text: map['text'] ?? '',
      textAr: map['textAr'] ?? '',
      textKu: map['textKu'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  // Define toJson for caching
  String toJson() => json.encode({
    'id': id,
    'text': text,
    'textAr': textAr,
    'textKu': textKu,
    'createdAt': createdAt.toIso8601String(),
  });

  Map<String, dynamic> toMap() => {
    'text': text,
    'textAr': textAr,
    'textKu': textKu,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class QuotesService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Developer email - the only one who can manage content
  static const String developerEmail = 'yusfkarim2001@gmail.com';
  
  List<Quote> _quotes = [];
  int _currentQuoteIndex = 0;
  
  List<Quote> get quotes => _quotes;
  Quote? get currentQuote => _quotes.isNotEmpty ? _quotes[_currentQuoteIndex % _quotes.length] : null;
  int get currentIndex => _currentQuoteIndex;
  int get totalQuotes => _quotes.length;
  
  bool get isDeveloper {
    final user = _auth.currentUser;
    return user != null && user.email == developerEmail;
  }

  // Auto-translate Arabic text to English
  Future<String> translateToEnglish(String arabicText) async {
    if (arabicText.isEmpty) return '';
    try {
      final translated = await _translateArToEn(arabicText);
      return translated;
    } catch (e) {
      debugPrint('Translation error: $e');
      return ''; // Return empty if translation fails
    }
  }

  /// Translate Arabic to English using Google's keyless "gtx" endpoint.
  /// Returns the original text if the translation service is unreachable.
  static Future<String> _translateArToEn(String text) async {
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': 'ar',
      'tl': 'en',
      'dt': 't',
      'q': text,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) return text;
    final decoded = jsonDecode(res.body);
    final segments = decoded[0] as List;
    final buffer = StringBuffer();
    for (final seg in segments) {
      buffer.write(seg[0]);
    }
    return buffer.toString();
  }

  Future<void> loadQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load from local cache first (Offline First)
    final cachedData = prefs.getStringList('cached_quotes');
    if (cachedData != null) {
      _quotes = cachedData.map((json) => Quote.fromJson(json)).toList();
      notifyListeners();
    }
    
    // 2. Sync from Firebase — only overwrite if it has data
    try {
      final snapshot = await _firestore
          .collection('quotes')
          .orderBy('createdAt', descending: false)
          .limit(30)
          .get(const GetOptions(source: Source.serverAndCache));
      
      if (snapshot.docs.isNotEmpty) {
        _quotes = snapshot.docs.map((doc) => Quote.fromFirestore(doc)).toList();
        _cacheQuotes();
        await _loadUserQuoteIndex();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading quotes from Firebase: $e');
    }

    // 3. Add default quote if empty (Fallback)
    if (_quotes.isEmpty) {
      _quotes = [
        Quote(
          id: 'default_1',
          text: 'Recovery is a journey, not a destination.',
          textAr: 'التعافي رحلة، وليس وجهة.',
          textKu: 'چاکبوونەوە گەشتێکە، نەک شوێنی گەیشتن.',
          createdAt: DateTime.now(),
        ),
      ];
      notifyListeners();
    }
  }

  Future<void> _loadUserQuoteIndex() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['lastQuoteIndex'] != null) {
          _currentQuoteIndex = doc.data()!['lastQuoteIndex'] as int;
          // Ensure index is valid
          if (_quotes.isNotEmpty && _currentQuoteIndex >= _quotes.length) {
            _currentQuoteIndex = 0;
          }
        }
      } catch (e) {
        debugPrint('Error loading quote index: $e');
      }
    } else {
      // For anonymous/guest users, use local storage
      final prefs = await SharedPreferences.getInstance();
      _currentQuoteIndex = prefs.getInt('lastQuoteIndex') ?? 0;
      if (_quotes.isNotEmpty && _currentQuoteIndex >= _quotes.length) {
        _currentQuoteIndex = 0;
      }
    }
  }

  Future<void> _saveUserQuoteIndex() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'lastQuoteIndex': _currentQuoteIndex,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving quote index: $e');
      }
    } else {
      // For anonymous/guest users, use local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastQuoteIndex', _currentQuoteIndex);
    }
  }

  Future<void> _cacheQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    final quotesJson = _quotes.map((q) => q.toJson()).toList();
    await prefs.setStringList('cached_quotes', quotesJson);
  }

  void nextQuote() {
    if (_quotes.isNotEmpty) {
      _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
      _saveUserQuoteIndex();
      notifyListeners();
    }
  }

  void previousQuote() {
    if (_quotes.isNotEmpty) {
      _currentQuoteIndex = (_currentQuoteIndex - 1 + _quotes.length) % _quotes.length;
      _saveUserQuoteIndex();
      notifyListeners();
    }
  }

  Future<void> addQuote(String textAr, {String? textKu, String? textEn}) async {
    if (!isDeveloper) return;
    
    try {
      // Auto-translate Arabic to English if not provided
      String textEnFinal = textEn ?? '';
      if (textEnFinal.isEmpty && textAr.isNotEmpty) {
        textEnFinal = await translateToEnglish(textAr);
      }
      
      // Kurdish text is optional, don't auto-translate
      final textKuFinal = textKu ?? '';
      
      await _firestore.collection('quotes').add({
        'text': textEnFinal, // Default field (English)
        'textAr': textAr,
        'textKu': textKuFinal,
        'textEn': textEnFinal,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await loadQuotes();
    } catch (e) {
      debugPrint('Error adding quote: $e');
    }
  }

  Future<void> updateQuote(String id, String textAr, {String? textKu, String? textEn}) async {
    if (!isDeveloper) return;
    
    try {
      final data = {
        'textAr': textAr,
        if (textKu != null) 'textKu': textKu,
        if (textEn != null) 'textEn': textEn,
        if (textEn != null) 'text': textEn, // Update legacy/default field
      };
      
      await _firestore.collection('quotes').doc(id).update(data);
      await loadQuotes();
    } catch (e) {
      debugPrint('Error updating quote: $e');
    }
  }

  Future<void> deleteQuote(String id) async {
    if (!isDeveloper) return;
    
    try {
      await _firestore.collection('quotes').doc(id).delete();
      if (_currentQuoteIndex >= _quotes.length - 1) {
        _currentQuoteIndex = 0;
      }
      await loadQuotes();
    } catch (e) {
      debugPrint('Error deleting quote: $e');
    }
  }
}
