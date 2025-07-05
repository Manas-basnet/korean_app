import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';

import 'book_local_datasource.dart';

class BooksLocalDataSourceImpl implements BooksLocalDataSource {
  final StorageService _storageService;
  
  static const String booksKey = 'CACHED_BOOKS';
  static const String userInteractionKey = 'USER_BOOK_INTERACTION';
  static const String lastSyncKey = 'LAST_BOOKS_SYNC_TIME';
  static const String bookHashesKey = 'BOOK_HASHES';
  static const String totalCountKey = 'TOTAL_BOOKS_COUNT';
  static const String categoryCountPrefix = 'BOOK_CATEGORY_COUNT_';
  static const String imageMetadataKey = 'BOOK_IMAGE_METADATA';
  static const String audioMetadataKey = 'BOOK_AUDIO_METADATA';
  static const String pdfMetadataKey = 'BOOK_PDF_METADATA';
  
  // Reading Session Keys
  static const String currentSessionKey = 'CURRENT_READING_SESSION';
  static const String bookProgressPrefix = 'BOOK_PROGRESS_';
  static const String recentlyReadBooksKey = 'RECENTLY_READ_BOOKS';
  
  Directory? _imagesCacheDir;
  Directory? _audioCacheDir;
  Directory? _pdfCacheDir;

  BooksLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  Future<Directory> get _imagesCacheDirectory async {
    if (_imagesCacheDir != null) return _imagesCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _imagesCacheDir = Directory('${appDir.path}/books_images_cache');
    
    if (!await _imagesCacheDir!.exists()) {
      await _imagesCacheDir!.create(recursive: true);
    }
    
    return _imagesCacheDir!;
  }

  Future<Directory> get _audioCacheDirectory async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _audioCacheDir = Directory('${appDir.path}/books_audio_cache');
    
    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
    }
    
    return _audioCacheDir!;
  }

  Future<Directory> get _pdfCacheDirectory async {
    if (_pdfCacheDir != null) return _pdfCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _pdfCacheDir = Directory('${appDir.path}/books_pdf_cache');
    
    if (!await _pdfCacheDir!.exists()) {
      await _pdfCacheDir!.create(recursive: true);
    }
    
    return _pdfCacheDir!;
  }

  @override
  Future<List<BookItem>> getAllBooks() async {
    try {
      final jsonString = _storageService.getString(booksKey);
      if (jsonString == null) return [];
      
      final List<dynamic> decodedJson = json.decode(jsonString);
      final books = decodedJson.map((item) => BookItem.fromJson(item)).toList();
      
      return books;
    } catch (e) {
      debugPrint('Error reading books from storage: $e');
      return [];
    }
  }

  @override
  Future<void> saveBooks(List<BookItem> books) async {
    try {
      final jsonList = books.map((book) => book.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _storageService.setString(booksKey, jsonString);
      
      debugPrint('Saved ${books.length} books to cache');
    } catch (e) {
      debugPrint('Error saving books to storage: $e');
      throw Exception('Failed to save books: $e');
    }
  }

  @override
  Future<void> addBook(BookItem book) async {
    try {
      final books = await getAllBooks();
      final existingIndex = books.indexWhere((b) => b.id == book.id);
      
      if (existingIndex != -1) {
        books[existingIndex] = book;
      } else {
        books.add(book);
      }
      
      await saveBooks(books);
    } catch (e) {
      debugPrint('Error adding book to storage: $e');
      throw Exception('Failed to add book: $e');
    }
  }

  @override
  Future<void> updateBook(BookItem book) async {
    try {
      final books = await getAllBooks();
      final bookIndex = books.indexWhere((b) => b.id == book.id);
      
      if (bookIndex != -1) {
        books[bookIndex] = book;
        await saveBooks(books);
      } else {
        throw Exception('Book not found for update: ${book.id}');
      }
    } catch (e) {
      debugPrint('Error updating book in storage: $e');
      throw Exception('Failed to update book: $e');
    }
  }

  @override
  Future<void> removeBook(String bookId) async {
    try {
      final books = await getAllBooks();
      final bookToRemove = books.firstWhere((book) => book.id == bookId, orElse: () => const BookItem(
        id: '', title: '', description: '', chapters: [],
        level: BookLevel.beginner, category: CourseCategory.korean,
      ));
      
      if (bookToRemove.id.isNotEmpty) {
        await _removeBookImages(bookToRemove);
        await _removeBookAudio(bookToRemove);
        await _removeBookPdfs(bookToRemove);
      }
      
      final updatedBooks = books.where((book) => book.id != bookId).toList();
      await saveBooks(updatedBooks);
      
      // Also remove book progress
      await deleteBookProgress(bookId);
    } catch (e) {
      debugPrint('Error removing book from storage: $e');
      throw Exception('Failed to remove book: $e');
    }
  }

  @override
  Future<void> clearAllBooks() async {
    try {
      await _storageService.remove(booksKey);
      await _storageService.remove(lastSyncKey);
      await _storageService.remove(bookHashesKey);
      await _storageService.remove(totalCountKey);
      await _storageService.remove(imageMetadataKey);
      await _storageService.remove(audioMetadataKey);
      await _storageService.remove(pdfMetadataKey);
      await _storageService.remove(userInteractionKey);
      await _storageService.remove(currentSessionKey);
      await _storageService.remove(recentlyReadBooksKey);
      
      final allKeys = _storageService.getAllKeys();
      for (final key in allKeys) {
        if (key.startsWith(categoryCountPrefix) || key.startsWith(bookProgressPrefix)) {
          await _storageService.remove(key);
        }
      }
      
      await _clearAllImages();
      await _clearAllAudio();
      await _clearAllPdfs();
      
      debugPrint('Cleared all books cache, images, audio, PDFs, reading sessions and interactions');
    } catch (e) {
      debugPrint('Error clearing all books from storage: $e');
    }
  }

  @override
  Future<bool> hasAnyBooks() async {
    try {
      final books = await getAllBooks();
      return books.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getBooksCount() async {
    try {
      final books = await getAllBooks();
      return books.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> setLastSyncTime(DateTime dateTime) async {
    await _storageService.setInt(lastSyncKey, dateTime.millisecondsSinceEpoch);
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _storageService.getInt(lastSyncKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  @override
  Future<void> setBookHashes(Map<String, String> hashes) async {
    await _storageService.setString(bookHashesKey, json.encode(hashes));
  }

  @override
  Future<Map<String, String>> getBookHashes() async {
    try {
      final hashesJson = _storageService.getString(bookHashesKey);
      if (hashesJson == null) return {};
      
      final Map<String, dynamic> decoded = json.decode(hashesJson);
      return decoded.cast<String, String>();
    } catch (e) {
      debugPrint('Error reading book hashes: $e');
      return {};
    }
  }

  @override
  Future<List<BookItem>> getBooksPage(int page, int pageSize, {TestSortType sortType = TestSortType.recent}) async {
    try {
      final allBooks = await getAllBooks();
      final sortedBooks = _applySorting(allBooks, sortType);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedBooks.length);
      
      if (startIndex >= sortedBooks.length) return [];
      
      final result = sortedBooks.sublist(startIndex, endIndex);
      debugPrint('Retrieved ${result.length} books (page $page, sortType: ${sortType.name})');
      
      return result;
    } catch (e) {
      debugPrint('Error getting books page: $e');
      return [];
    }
  }

  @override
  Future<List<BookItem>> getBooksByCategoryPage(String category, int page, int pageSize, {TestSortType sortType = TestSortType.recent}) async {
    try {
      final allBooks = await getAllBooks();
      final categoryBooks = allBooks.where((book) => 
        book.category.toString().split('.').last == category
      ).toList();
      
      final sortedBooks = _applySorting(categoryBooks, sortType);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedBooks.length);
      
      if (startIndex >= sortedBooks.length) return [];
      
      final result = sortedBooks.sublist(startIndex, endIndex);
      debugPrint('Retrieved ${result.length} category books (page $page, category: $category, sortType: ${sortType.name})');
      
      return result;
    } catch (e) {
      debugPrint('Error getting category books page: $e');
      return [];
    }
  }

  List<BookItem> _applySorting(List<BookItem> books, TestSortType sortType) {
    final sortedBooks = List<BookItem>.from(books);
    
    switch (sortType) {
      case TestSortType.recent:
        sortedBooks.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        break;
        
      case TestSortType.popular:
        sortedBooks.sort((a, b) {
          return b.popularity.compareTo(a.popularity);
        });
        break;
        
      case TestSortType.rating:
        sortedBooks.sort((a, b) {
          return b.rating.compareTo(a.rating);
        });
        break;
        
      case TestSortType.viewCount:
        sortedBooks.sort((a, b) {
          return b.viewCount.compareTo(a.viewCount);
        });
        break;
    }
    
    return sortedBooks;
  }

  @override
  Future<void> setTotalBooksCount(int count) async {
    await _storageService.setInt(totalCountKey, count);
  }

  @override
  Future<int?> getTotalBooksCount() async {
    return _storageService.getInt(totalCountKey);
  }

  @override
  Future<void> setCategoryBooksCount(String category, int count) async {
    await _storageService.setInt('$categoryCountPrefix$category', count);
  }

  @override
  Future<int?> getCategoryBooksCount(String category) async {
    return _storageService.getInt('$categoryCountPrefix$category');
  }

  @override
  Future<void> cacheImage(String imageUrl, String bookId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, bookId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('Image already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        debugPrint('Cached image: $fileName (${response.data.length} bytes)');
        
        await _updateImageMetadata(bookId, imageType, imageUrl);
      } else {
        debugPrint('Failed to download image: $imageUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching image $imageUrl: $e');
    }
  }

  @override
  Future<void> cacheAudio(String audioUrl, String bookId, String audioType) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, bookId, audioType);
      final cacheDir = await _audioCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('Audio already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        debugPrint('Cached audio: $fileName (${response.data.length} bytes)');
        
        await _updateAudioMetadata(bookId, audioType, audioUrl);
      } else {
        debugPrint('Failed to download audio: $audioUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching audio $audioUrl: $e');
    }
  }

  @override
  Future<void> cachePdf(String pdfUrl, String bookId, String pdfType) async {
    try {
      final fileName = _generatePdfFileName(pdfUrl, bookId, pdfType);
      final cacheDir = await _pdfCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('PDF already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        pdfUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        debugPrint('Cached PDF: $fileName (${response.data.length} bytes)');
        
        await _updatePdfMetadata(bookId, pdfType, pdfUrl);
      } else {
        debugPrint('Failed to download PDF: $pdfUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching PDF $pdfUrl: $e');
    }
  }

  @override
  Future<String?> getCachedImagePath(String imageUrl, String bookId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, bookId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        debugPrint('Found cached image: $absolutePath');
        return absolutePath;
      } else {
        debugPrint('Cached image not found: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error getting cached image path: $e');
    }
    return null;
  }

  @override
  Future<String?> getCachedAudioPath(String audioUrl, String bookId, String audioType) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, bookId, audioType);
      final cacheDir = await _audioCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        debugPrint('Found cached audio: $absolutePath');
        return absolutePath;
      } else {
        debugPrint('Cached audio not found: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error getting cached audio path: $e');
    }
    return null;
  }

  @override
  Future<String?> getCachedPdfPath(String pdfUrl, String bookId, String pdfType) async {
    try {
      final fileName = _generatePdfFileName(pdfUrl, bookId, pdfType);
      final cacheDir = await _pdfCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        debugPrint('Found cached PDF: $absolutePath');
        return absolutePath;
      } else {
        debugPrint('Cached PDF not found: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error getting cached PDF path: $e');
    }
    return null;
  }

  @override
  Future<UserBookInteraction?> getUserBookInteraction(String bookId, String userId) async {
    try {
      final data = _storageService.getString(userInteractionKey);

      if(data == null) {
        return null;
      }
      if(data.isEmpty) {
        return null;
      }

      final jsonData = json.decode(data);
      final userInteraction = UserBookInteraction.fromJson(jsonData);

      return userInteraction;

    } catch (e) {
      debugPrint('Error getting user book interaction: $e');
      return null;
    }
  }

  @override
  Future<bool> saveUserBookInteraction(UserBookInteraction userInteraction) async{
    try {
      await _storageService.setString(userInteractionKey, json.encode(userInteraction.toJson()));
      return true;
    } catch (e) {
      debugPrint('Error saving user book interaction: $e');
      return false;
    }
  }

  // Reading Session Methods Implementation

  @override
  Future<void> saveCurrentReadingSession(ReadingSession session) async {
    try {
      await _storageService.setString(currentSessionKey, json.encode(session.toJson()));
      debugPrint('Saved current reading session: ${session.bookTitle} - Chapter ${session.chapterIndex + 1}');
    } catch (e) {
      debugPrint('Error saving current reading session: $e');
      throw Exception('Failed to save reading session: $e');
    }
  }

  @override
  Future<ReadingSession?> getCurrentReadingSession() async {
    try {
      final sessionJson = _storageService.getString(currentSessionKey);
      if (sessionJson == null) return null;
      
      final sessionData = json.decode(sessionJson);
      return ReadingSession.fromJson(sessionData);
    } catch (e) {
      debugPrint('Error getting current reading session: $e');
      return null;
    }
  }

  @override
  Future<void> clearCurrentReadingSession() async {
    try {
      await _storageService.remove(currentSessionKey);
      debugPrint('Cleared current reading session');
    } catch (e) {
      debugPrint('Error clearing current reading session: $e');
    }
  }

  // Book Progress Methods Implementation

  @override
  Future<void> saveBookProgress(BookProgress bookProgress) async {
    try {
      final key = '$bookProgressPrefix${bookProgress.bookId}';
      await _storageService.setString(key, json.encode(bookProgress.toJson()));
      debugPrint('Saved book progress: ${bookProgress.bookTitle} - ${bookProgress.formattedProgress}');
    } catch (e) {
      debugPrint('Error saving book progress: $e');
      throw Exception('Failed to save book progress: $e');
    }
  }

  @override
  Future<BookProgress?> getBookProgress(String bookId) async {
    try {
      final key = '$bookProgressPrefix$bookId';
      final progressJson = _storageService.getString(key);
      if (progressJson == null) return null;
      
      final progressData = json.decode(progressJson);
      return BookProgress.fromJson(progressData);
    } catch (e) {
      debugPrint('Error getting book progress for $bookId: $e');
      return null;
    }
  }

  @override
  Future<List<BookProgress>> getAllBookProgress() async {
    try {
      final allKeys = _storageService.getAllKeys();
      final progressKeys = allKeys.where((key) => key.startsWith(bookProgressPrefix));
      
      final progressList = <BookProgress>[];
      for (final key in progressKeys) {
        final progressJson = _storageService.getString(key);
        if (progressJson != null) {
          try {
            final progressData = json.decode(progressJson);
            final bookProgress = BookProgress.fromJson(progressData);
            progressList.add(bookProgress);
          } catch (e) {
            debugPrint('Error parsing book progress for key $key: $e');
          }
        }
      }
      
      return progressList;
    } catch (e) {
      debugPrint('Error getting all book progress: $e');
      return [];
    }
  }

  @override
  Future<void> deleteBookProgress(String bookId) async {
    try {
      final key = '$bookProgressPrefix$bookId';
      await _storageService.remove(key);
      debugPrint('Deleted book progress for: $bookId');
    } catch (e) {
      debugPrint('Error deleting book progress for $bookId: $e');
    }
  }

  // Recently Read Books Methods Implementation

  @override
  Future<void> addToRecentlyRead(BookProgress bookProgress) async {
    try {
      final recentBooks = await getRecentlyReadBooks();
      
      // Remove existing entry for this book if present
      recentBooks.removeWhere((book) => book.bookId == bookProgress.bookId);
      
      // Add to beginning of list
      recentBooks.insert(0, bookProgress);
      
      // Limit to 10 recent books
      if (recentBooks.length > 10) {
        recentBooks.removeRange(10, recentBooks.length);
      }
      
      final recentBooksJson = recentBooks.map((book) => book.toJson()).toList();
      await _storageService.setString(recentlyReadBooksKey, json.encode(recentBooksJson));
      
      debugPrint('Added ${bookProgress.bookTitle} to recently read books');
    } catch (e) {
      debugPrint('Error adding to recently read books: $e');
    }
  }

  @override
  Future<List<BookProgress>> getRecentlyReadBooks({int limit = 10}) async {
    try {
      final recentBooksJson = _storageService.getString(recentlyReadBooksKey);
      if (recentBooksJson == null) return [];
      
      final List<dynamic> recentBooksData = json.decode(recentBooksJson);
      final recentBooks = recentBooksData
          .map((bookData) => BookProgress.fromJson(bookData))
          .take(limit)
          .toList();
      
      return recentBooks;
    } catch (e) {
      debugPrint('Error getting recently read books: $e');
      return [];
    }
  }

  @override
  Future<void> clearRecentlyReadBooks() async {
    try {
      await _storageService.remove(recentlyReadBooksKey);
      debugPrint('Cleared recently read books');
    } catch (e) {
      debugPrint('Error clearing recently read books: $e');
    }
  }

  // Private helper methods (existing methods remain the same)

  String _generateImageFileName(String imageUrl, String bookId, String imageType) {
    final urlHash = md5.convert(utf8.encode(imageUrl)).toString().substring(0, 8);
    return '${bookId}_${imageType}_$urlHash.jpg';
  }

  String _generateAudioFileName(String audioUrl, String bookId, String audioType) {
    final urlHash = md5.convert(utf8.encode(audioUrl)).toString().substring(0, 8);
    final extension = _getAudioExtensionFromUrl(audioUrl);
    return '${bookId}_${audioType}_$urlHash$extension';
  }

  String _generatePdfFileName(String pdfUrl, String bookId, String pdfType) {
    final urlHash = md5.convert(utf8.encode(pdfUrl)).toString().substring(0, 8);
    return '${bookId}_${pdfType}_$urlHash.pdf';
  }

  String _getAudioExtensionFromUrl(String audioUrl) {
    final uri = Uri.parse(audioUrl);
    final path = uri.path.toLowerCase();
    
    if (path.endsWith('.mp3')) return '.mp3';
    if (path.endsWith('.m4a')) return '.m4a';
    if (path.endsWith('.wav')) return '.wav';
    if (path.endsWith('.aac')) return '.aac';
    
    return '.m4a';
  }

  Future<void> _updateImageMetadata(String bookId, String imageType, String imageUrl) async {
    try {
      final imageMetadata = await _getImageMetadata();
      imageMetadata['${bookId}_$imageType'] = {
        'url': imageUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      debugPrint('Error updating image metadata: $e');
    }
  }

  Future<void> _updateAudioMetadata(String bookId, String audioType, String audioUrl) async {
    try {
      final audioMetadata = await _getAudioMetadata();
      audioMetadata['${bookId}_$audioType'] = {
        'url': audioUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error updating audio metadata: $e');
    }
  }

  Future<void> _updatePdfMetadata(String bookId, String pdfType, String pdfUrl) async {
    try {
      final pdfMetadata = await _getPdfMetadata();
      pdfMetadata['${bookId}_$pdfType'] = {
        'url': pdfUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _savePdfMetadata(pdfMetadata);
    } catch (e) {
      debugPrint('Error updating PDF metadata: $e');
    }
  }

  Future<void> _removeBookImages(BookItem book) async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      final imageMetadata = await _getImageMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(book.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = imageMetadata.keys.where((key) => key.startsWith(book.id)).toList();
      for (final key in keysToRemove) {
        imageMetadata.remove(key);
      }
      
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      debugPrint('Error removing book images: $e');
    }
  }

  Future<void> _removeBookAudio(BookItem book) async {
    try {
      final cacheDir = await _audioCacheDirectory;
      final audioMetadata = await _getAudioMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(book.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = audioMetadata.keys.where((key) => key.startsWith(book.id)).toList();
      for (final key in keysToRemove) {
        audioMetadata.remove(key);
      }
      
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error removing book audio: $e');
    }
  }

  Future<void> _removeBookPdfs(BookItem book) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final pdfMetadata = await _getPdfMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(book.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = pdfMetadata.keys.where((key) => key.startsWith(book.id)).toList();
      for (final key in keysToRemove) {
        pdfMetadata.remove(key);
      }
      
      await _savePdfMetadata(pdfMetadata);
    } catch (e) {
      debugPrint('Error removing book PDFs: $e');
    }
  }

  Future<void> _clearAllImages() async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      debugPrint('Cleared all cached book images');
    } catch (e) {
      debugPrint('Error clearing all book images: $e');
    }
  }

  Future<void> _clearAllAudio() async {
    try {
      final cacheDir = await _audioCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      debugPrint('Cleared all cached book audio');
    } catch (e) {
      debugPrint('Error clearing all book audio: $e');
    }
  }

  Future<void> _clearAllPdfs() async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      debugPrint('Cleared all cached book PDFs');
    } catch (e) {
      debugPrint('Error clearing all book PDFs: $e');
    }
  }

  Future<Map<String, dynamic>> _getImageMetadata() async {
    try {
      final metadataJson = _storageService.getString(imageMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading book image metadata: $e');
      return {};
    }
  }

  Future<void> _saveImageMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(imageMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving book image metadata: $e');
    }
  }

  Future<Map<String, dynamic>> _getAudioMetadata() async {
    try {
      final metadataJson = _storageService.getString(audioMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading book audio metadata: $e');
      return {};
    }
  }

  Future<void> _saveAudioMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(audioMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving book audio metadata: $e');
    }
  }

  Future<Map<String, dynamic>> _getPdfMetadata() async {
    try {
      final metadataJson = _storageService.getString(pdfMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading book PDF metadata: $e');
      return {};
    }
  }

  Future<void> _savePdfMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(pdfMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving book PDF metadata: $e');
    }
  }
}