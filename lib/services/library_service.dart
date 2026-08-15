import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AWS Signature v4 for Cloudflare R2
class R2Signer {
  final String accessKey;
  final String secretKey;
  final String region;
  final String service;

  R2Signer({
    required this.accessKey,
    required this.secretKey,
    this.region = 'auto',
    this.service = 's3',
  });

  Map<String, String> signRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Uint8List payload,
  }) {
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatAmzDate(now);

    // Add required headers
    final signedHeaders = Map<String, String>.from(headers);
    signedHeaders['x-amz-date'] = amzDate;
    signedHeaders['x-amz-content-sha256'] = _hexEncode(sha256.convert(payload).bytes);
    signedHeaders['host'] = uri.host;

    // Create canonical request
    final canonicalHeaders = _getCanonicalHeaders(signedHeaders);
    final signedHeadersList = _getSignedHeadersList(signedHeaders);
    
    final canonicalRequest = [
      method,
      uri.path,
      uri.query,
      canonicalHeaders,
      '',
      signedHeadersList,
      signedHeaders['x-amz-content-sha256']!,
    ].join('\n');

    // Create string to sign
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hexEncode(sha256.convert(utf8.encode(canonicalRequest)).bytes),
    ].join('\n');

    // Calculate signature
    final signingKey = _getSignatureKey(secretKey, dateStamp, region, service);
    final signature = _hexEncode(Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).bytes);

    // Create authorization header
    final authorization = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeadersList, Signature=$signature';

    signedHeaders['Authorization'] = authorization;
    return signedHeaders;
  }

  String _formatDate(DateTime dt) => 
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  String _formatAmzDate(DateTime dt) => 
      '${_formatDate(dt)}T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}Z';

  String _getCanonicalHeaders(Map<String, String> headers) {
    final sortedKeys = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
    return sortedKeys.map((k) => '$k:${headers.entries.firstWhere((e) => e.key.toLowerCase() == k).value.trim()}').join('\n');
  }

  String _getSignedHeadersList(Map<String, String> headers) {
    final sortedKeys = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
    return sortedKeys.join(';');
  }

  List<int> _getSignatureKey(String key, String dateStamp, String region, String service) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  String _hexEncode(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Helper function to parse DateTime from various formats (Timestamp, String, etc.)
DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return DateTime.now();
    }
  }
  return DateTime.now();
}

class BookCategory {
  final String id;
  final String nameAr;
  final String nameKu;
  final String nameEn;
  final DateTime createdAt;

  BookCategory({
    required this.id,
    required this.nameAr,
    required this.nameKu,
    required this.nameEn,
    required this.createdAt,
  });

  String getName(String languageCode) {
    switch (languageCode) {
      case 'arabic': return nameAr;
      case 'kurdish': return nameKu;
      default: return nameEn;
    }
  }

  factory BookCategory.fromJson(Map<String, dynamic> json) => BookCategory(
    id: json['id'] ?? '',
    nameAr: json['nameAr'] ?? '',
    nameKu: json['nameKu'] ?? '',
    nameEn: json['nameEn'] ?? '',
    createdAt: _parseDateTime(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameAr': nameAr,
    'nameKu': nameKu,
    'nameEn': nameEn,
    'createdAt': createdAt.toIso8601String(),
  };
}

class Book {
  final String id;
  final String title;
  final String author;
  final String categoryId;
  final String pdfUrl;
  final String? coverUrl;
  final String? downloadUrl; // Separate download link (e.g., MediaFire)
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.categoryId,
    required this.pdfUrl,
    this.coverUrl,
    this.downloadUrl,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    author: json['author'] ?? '',
    categoryId: json['categoryId'] ?? '',
    pdfUrl: json['pdfUrl'] ?? '',
    coverUrl: json['coverUrl'],
    downloadUrl: json['downloadUrl'],
    createdAt: _parseDateTime(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'categoryId': categoryId,
    'pdfUrl': pdfUrl,
    'coverUrl': coverUrl,
    'downloadUrl': downloadUrl,
    'createdAt': createdAt.toIso8601String(),
  };
}

class LibraryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Developer emails - always admin
  static const List<String> _developerEmails = [
    'yusfkarim2001@gmail.com',
    'yusfkarim1001@gmail.com',
  ];

  // Cloudflare R2 Configuration
  static const String _endPoint = '7c89b13a3804e7e74371b0d7af933b54.r2.cloudflarestorage.com';
  static const String _accessKey = '7d7b4651ff418c11d22b1060e4597da2';
  static const String _secretKey = '1d26ad535f9fcef7d8cb55c5546fc7bd6015304311751b0ff5f35b9fa44f4d2d';
  static const String _bucketName = 'yusf';

  // Public URL base for Cloudflare R2
  final String _publicUrlBase = 'https://pub-97d42e49218f4a3087b8d7bfa65201f9.r2.dev';

  final R2Signer _signer = R2Signer(
    accessKey: _accessKey,
    secretKey: _secretKey,
    region: 'auto',
  );

  List<BookCategory> _categories = [];
  List<Book> _books = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  bool _isAdmin = false;
  
  Set<String> get favoriteIds => _favoriteIds;
  List<BookCategory> get categories => List.unmodifiable(_categories);
  List<Book> get books => List.unmodifiable(_books);
  bool get isLoading => _isLoading;
  bool get isAdmin => _isAdmin;

  String? get _userId => _auth.currentUser?.uid;
  String? get _userEmail => _auth.currentUser?.email;

  /// Check if current user is developer by email
  bool get _isDeveloperByEmail {
    final email = _userEmail;
    if (email == null) return false;
    return _developerEmails.any((e) => e.toLowerCase() == email.toLowerCase());
  }

  Future<void> loadData() async {
    // 1. Initial Loading State
    _isLoading = true;
    notifyListeners();

    // 2. Load from Local Cache (SharedPreferences) IMMEDIATELY
    try {
      final prefs = await SharedPreferences.getInstance();
      final catStr = prefs.getString('library_categories_cache');
      final bookStr = prefs.getString('library_books_cache');

      if (catStr != null && bookStr != null) {
        final catList = jsonDecode(catStr) as List;
        _categories = catList.map((c) => BookCategory.fromJson(c)).toList();

        final bookList = jsonDecode(bookStr) as List;
        _books = bookList.map((b) => Book.fromJson(b)).toList();
        
        // Load favorites
        final favList = prefs.getStringList('favorite_books') ?? [];
        _favoriteIds = favList.toSet();

        // Data loaded from cache, stop the main spinner so user can see something
        _isLoading = false;
        notifyListeners();
        debugPrint('✅ Library data loaded from local cache. Favorites: ${_favoriteIds.length}');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading library cache: $e');
    }

    // 3. Check for Internet Connection before attempting Online Fetch
    bool hasInternet = true; // Assume true initially
    // Check internet only on non-web platforms because InternetAddress throws UnsupportedError on web
    if (!kIsWeb) {
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          hasInternet = false;
        }
      } catch (_) {
        hasInternet = false;
      }
    }

    if (!hasInternet) {
      debugPrint('🌐 Offline: Skipping Firestore library refresh');
      _isLoading = false;
      notifyListeners();
      return; 
    }

    // 4. If Online, Refresh from Firestore in the Background
    try {
      debugPrint('🌐 Online: Refreshing library from Firestore...');
      
      // Check admin status
      await _checkAdminStatus().timeout(const Duration(seconds: 3)).catchError((_) => debugPrint('Admin check timeout'));

      // Load categories
      final catSnapshot = await _firestore.collection('library_categories')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
          
      final newCategories = catSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BookCategory.fromJson(data);
      }).toList();
      
      // Sort categories
      newCategories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _categories = newCategories;

      // Load books
      final bookSnapshot = await _firestore.collection('library_books')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
          
      final newBooks = bookSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Book.fromJson(data);
      }).toList();
      _books = newBooks;

      // Save to SharedPreferences for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('library_categories_cache', jsonEncode(_categories.map((c) => c.toJson()).toList()));
      await prefs.setString('library_books_cache', jsonEncode(_books.map((b) => b.toJson()).toList()));
      
      // Also fetch favorites from Firestore if logged in
      if (_userId != null) {
        try {
          final favSnapshot = await _firestore.collection('users').doc(_userId).collection('favorites').get();
          _favoriteIds = favSnapshot.docs.map((doc) => doc.id).toSet();
          await prefs.setStringList('favorite_books', _favoriteIds.toList());
        } catch (e) {
          debugPrint('❌ Firebase favorites sync failed: $e');
        }
      }
      
      debugPrint('✅ Library data refreshed from online and cached');
    } catch (e) {
      debugPrint('❌ Error refreshing library data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkAdminStatus() async {
    // Developer by email is always admin
    if (_isDeveloperByEmail) {
      _isAdmin = true;
      return;
    }

    if (_userId == null) {
      _isAdmin = false;
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        _isAdmin = data?['isAdmin'] == true;
      } else {
        _isAdmin = false;
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      _isAdmin = false;
    }
  }

  List<Book> getBooksForCategory(String categoryId) {
    if (categoryId == 'all') return _books;
    return _books.where((b) => b.categoryId == categoryId).toList();
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

  // Admin functions - no admin check since content_management_screen is already for developers
  Future<bool> addCategory(String nameAr, String nameKu, String nameEn) async {
    try {
      // Auto translate to English if empty
      String finalNameEn = nameEn;
      if (nameEn.isEmpty && nameAr.isNotEmpty) {
        try {
          finalNameEn = await _translateArToEn(nameAr);
        } catch (e) {
          finalNameEn = nameAr; // Fallback
        }
      }

      final docRef = await _firestore.collection('library_categories').add({
        'nameAr': nameAr,
        'nameKu': nameKu.isNotEmpty ? nameKu : nameAr, // Use Arabic if Kurdish empty
        'nameEn': finalNameEn,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _categories.add(BookCategory(
        id: docRef.id,
        nameAr: nameAr,
        nameKu: nameKu.isNotEmpty ? nameKu : nameAr,
        nameEn: finalNameEn,
        createdAt: DateTime.now(),
      ));

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _firestore.collection('library_categories').doc(categoryId).delete();
      _categories.removeWhere((c) => c.id == categoryId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }

  /// Add book using URLs (free, unlimited - user provides URLs from Google Drive, Dropbox, etc.)
  Future<bool> addBook({
    required String title,
    required String author,
    required String categoryId,
    required String pdfUrl,
    String? coverUrl,
    String? downloadUrl,
  }) async {
    try {
      final bookId = DateTime.now().millisecondsSinceEpoch.toString();

      // Save to Firestore
      await _firestore.collection('library_books').doc(bookId).set({
        'title': title,
        'author': author,
        'categoryId': categoryId,
        'pdfUrl': pdfUrl,
        'coverUrl': coverUrl,
        'downloadUrl': downloadUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _books.add(Book(
        id: bookId,
        title: title,
        author: author,
        categoryId: categoryId,
        pdfUrl: pdfUrl,
        coverUrl: coverUrl,
        downloadUrl: downloadUrl,
        createdAt: DateTime.now(),
      ));

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding book: $e');
      return false;
    }
  }

  /// Upload PDF file to Cloudflare R2 - returns URL or null on failure
  Future<String?> uploadPdfFile(Uint8List fileBytes, String fileName) async {
    try {
      // Sanitize filename
      String sanitizedFileName = fileName.replaceAll(RegExp(r'\s+'), '_');
      final String objectName = 'pdfs/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
      
      debugPrint('Uploading PDF to Cloudflare R2: $objectName');
      
      final uri = Uri.https(_endPoint, '/$_bucketName/$objectName');

      final headers = {
        'Content-Type': 'application/pdf',
        'Content-Length': fileBytes.length.toString(),
      };

      final signedHeaders = _signer.signRequest(
        method: 'PUT',
        uri: uri,
        headers: headers,
        payload: fileBytes,
      );

      final response = await http.put(
        uri,
        headers: signedHeaders,
        body: fileBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = '$_publicUrlBase/$objectName';
        debugPrint('PDF Upload successful: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('PDF Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading PDF to R2: $e');
      return null;
    }
  }

  /// Upload cover image to Cloudflare R2 - returns URL or null on failure
  Future<String?> uploadCoverImage(Uint8List imageBytes, String fileName) async {
    try {
      // Sanitize filename  
      String sanitizedFileName = fileName.replaceAll(RegExp(r'\s+'), '_');
      final String objectName = 'covers/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
      
      debugPrint('Uploading cover to Cloudflare R2: $objectName');
      
      // Determine content type based on extension
      String contentType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (fileName.toLowerCase().endsWith('.webp')) {
        contentType = 'image/webp';
      }
      
      final uri = Uri.https(_endPoint, '/$_bucketName/$objectName');

      final headers = {
        'Content-Type': contentType,
        'Content-Length': imageBytes.length.toString(),
      };

      final signedHeaders = _signer.signRequest(
        method: 'PUT',
        uri: uri,
        headers: headers,
        payload: imageBytes,
      );

      final response = await http.put(
        uri,
        headers: signedHeaders,
        body: imageBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = '$_publicUrlBase/$objectName';
        debugPrint('Cover Upload successful: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('Cover Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading cover to R2: $e');
      return null;
    }
  }


  /// Add book with file upload support
  Future<bool> addBookWithFiles({
    required String title,
    required String author,
    required String categoryId,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Uint8List? coverBytes,
    String? coverFileName,
    String? pdfUrl,
    String? coverUrl,
  }) async {
    try {
      String? finalPdfUrl = pdfUrl;
      String? finalCoverUrl = coverUrl;

      // Upload PDF if bytes provided
      if (pdfBytes != null && pdfFileName != null) {
        finalPdfUrl = await uploadPdfFile(pdfBytes, pdfFileName);
        if (finalPdfUrl == null) return false;
      }

      // Upload cover if bytes provided
      if (coverBytes != null && coverFileName != null) {
        finalCoverUrl = await uploadCoverImage(coverBytes, coverFileName);
      }

      if (finalPdfUrl == null || finalPdfUrl.isEmpty) return false;

      // Use the regular addBook method
      return await addBook(
        title: title,
        author: author,
        categoryId: categoryId,
        pdfUrl: finalPdfUrl,
        coverUrl: finalCoverUrl,
      );
    } catch (e) {
      debugPrint('Error adding book with files: $e');
      return false;
    }
  }

  Future<bool> deleteBook(String bookId) async {
    debugPrint('🗑️ deleteBook called with ID: $bookId');
    try {
      // Delete from storage (ignore errors)
      try {
        await _storage.ref().child('library_books/$bookId.pdf').delete();
        debugPrint('🗑️ Deleted PDF from storage');
      } catch (e) {
        debugPrint('⚠️ Storage PDF delete failed (ok): $e');
      }
      
      try {
        await _storage.ref().child('library_covers/$bookId.jpg').delete();
        debugPrint('🗑️ Deleted cover from storage');
      } catch (e) {
        debugPrint('⚠️ Storage cover delete failed (ok): $e');
      }

      // Delete from Firestore
      debugPrint('🗑️ Deleting from Firestore...');
      await _firestore.collection('library_books').doc(bookId).delete();
      debugPrint('🗑️ Firestore delete successful');
      
      _books.removeWhere((b) => b.id == bookId);
      debugPrint('🗑️ Removed from local list. Books count: ${_books.length}');
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting book: $e');
      return false;
    }
  }

  /// Delete ALL books from the library
  Future<bool> deleteAllBooks() async {
    debugPrint('🗑️🗑️🗑️ DELETING ALL BOOKS...');
    try {
      // Get all books from Firestore
      final snapshot = await _firestore.collection('library_books').get();
      debugPrint('🗑️ Found ${snapshot.docs.length} books to delete');
      
      // Delete each book
      for (final doc in snapshot.docs) {
        try {
          await doc.reference.delete();
          debugPrint('🗑️ Deleted book: ${doc.id}');
        } catch (e) {
          debugPrint('⚠️ Failed to delete ${doc.id}: $e');
        }
      }
      
      // Clear local list
      _books.clear();
      notifyListeners();
      
      debugPrint('🗑️🗑️🗑️ ALL BOOKS DELETED!');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting all books: $e');
      return false;
    }
  }


  /// Update a category
  Future<bool> updateCategory(String id, String nameAr, String nameKu, String nameEn) async {
    try {
      await _firestore.collection('library_categories').doc(id).update({
        'nameAr': nameAr,
        'nameKu': nameKu,
        'nameEn': nameEn,
      });
      
      // Update local list
      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        _categories[index] = BookCategory(
          id: id,
          nameAr: nameAr,
          nameKu: nameKu,
          nameEn: nameEn,
          createdAt: _categories[index].createdAt,
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating category: $e');
      return false;
    }
  }

  /// Update a book
  Future<bool> updateBook(String id, String title, String author, String categoryId, String pdfUrl, String? coverUrl, String? downloadUrl) async {
    try {
      await _firestore.collection('library_books').doc(id).update({
        'title': title,
        'author': author,
        'categoryId': categoryId,
        'pdfUrl': pdfUrl,
        'coverUrl': coverUrl,
        'downloadUrl': downloadUrl,
      });
      
      // Update local list
      final index = _books.indexWhere((b) => b.id == id);
      if (index != -1) {
        _books[index] = Book(
          id: id,
          title: title,
          author: author,
          categoryId: categoryId,
          pdfUrl: pdfUrl,
          coverUrl: coverUrl,
          downloadUrl: downloadUrl,
          createdAt: _books[index].createdAt,
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating book: $e');
      return false;
    }
  }

  // ============================================
  // Reading Progress - Saves last read page for each book
  // Uses local storage (shared_preferences) - works without login
  // ============================================

  /// Save reading progress for a book (using local storage)
  Future<void> saveReadingProgress(String bookId, int pageNumber, int totalPages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save to local storage
      await prefs.setInt('reading_progress_$bookId', pageNumber);
      await prefs.setInt('reading_total_$bookId', totalPages);
      await prefs.setString('reading_date_$bookId', DateTime.now().toIso8601String());
      
      debugPrint('✅ Saved reading progress locally: Book $bookId, Page $pageNumber');
      
      // Also sync to Firebase if user is logged in
      if (_userId != null) {
        try {
          await _firestore
              .collection('reading_progress')
              .doc('${_userId}_$bookId')
              .set({
            'userId': _userId,
            'bookId': bookId,
            'lastPage': pageNumber,
            'totalPages': totalPages,
            'lastReadAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ Also synced to Firebase');
        } catch (e) {
          debugPrint('Firebase sync failed (not critical): $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving reading progress: $e');
    }
  }

  /// Get reading progress for a book (from local storage first, then Firebase)
  Future<int> getReadingProgress(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try local storage first
      final localPage = prefs.getInt('reading_progress_$bookId');
      if (localPage != null && localPage > 0) {
        debugPrint('✅ Loaded reading progress from local: Book $bookId, Page $localPage');
        return localPage;
      }
      
      // Try Firebase if logged in
      if (_userId != null) {
        try {
          final doc = await _firestore
              .collection('reading_progress')
              .doc('${_userId}_$bookId')
              .get();
          
          if (doc.exists && doc.data() != null) {
            final lastPage = doc.data()!['lastPage'] as int?;
            if (lastPage != null && lastPage > 0) {
              // Save to local for future
              await prefs.setInt('reading_progress_$bookId', lastPage);
              debugPrint('✅ Loaded reading progress from Firebase: Book $bookId, Page $lastPage');
              return lastPage;
            }
          }
        } catch (e) {
          debugPrint('Firebase read failed: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading reading progress: $e');
    }
    
    return 1;
  }

  /// Get reading progress with details for a book
  Future<Map<String, dynamic>?> getReadingProgressDetails(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final localPage = prefs.getInt('reading_progress_$bookId');
      final totalPages = prefs.getInt('reading_total_$bookId');
      final dateStr = prefs.getString('reading_date_$bookId');
      
      if (localPage != null && localPage > 0) {
        return {
          'lastPage': localPage,
          'totalPages': totalPages ?? 0,
          'lastReadAt': dateStr,
        };
      }
    } catch (e) {
      debugPrint('Error loading reading progress details: $e');
    }
    
    return null;
  }

  // ============================================
  // Favorites Support (المفضلة)
  // ============================================

  bool isFavorite(String bookId) {
    return _favoriteIds.contains(bookId);
  }

  Future<void> toggleFavorite(String bookId) async {
    if (_favoriteIds.contains(bookId)) {
      _favoriteIds.remove(bookId);
    } else {
      _favoriteIds.add(bookId);
    }
    
    notifyListeners();

    // Persist Locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_books', _favoriteIds.toList());
    } catch (e) {
      debugPrint('❌ Error saving favorites locally: $e');
    }

    // Sync to Firebase if logged in
    if (_userId != null) {
      try {
        if (_favoriteIds.contains(bookId)) {
          await _firestore.collection('users').doc(_userId).collection('favorites').doc(bookId).set({
            'bookId': bookId,
            'addedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await _firestore.collection('users').doc(_userId).collection('favorites').doc(bookId).delete();
        }
      } catch (e) {
        debugPrint('❌ Error syncing favorites: $e');
      }
    }
  }
}
