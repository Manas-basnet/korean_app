import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';
import 'package:korean_language_app/features/books/data/datasources/local/korean_books_local_datasource.dart';
import 'package:korean_language_app/features/books/data/models/book_item.dart';

class KoreanBooksLocalDataSourceImpl implements KoreanBooksLocalDataSource {
  final StorageService _storageService;
  
  static const String booksKey = 'CACHED_KOREAN_BOOKS';
  static const String lastSyncKey = 'LAST_BOOKS_SYNC_TIME';
  static const String bookHashesKey = 'BOOK_HASHES';
  static const String totalCountKey = 'TOTAL_BOOKS_COUNT';

  Directory? _pdfCacheDir;

  KoreanBooksLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  Future<Directory> get _pdfCacheDirectory async {
    if (_pdfCacheDir != null) return _pdfCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _pdfCacheDir = Directory('${appDir.path}/pdf_cache');
    
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
      return decodedJson.map((item) => BookItem.fromJson(item)).toList();
    } catch (e) {
      dev.log('Error reading books from storage: $e');
      return [];
    }
  }

  @override
  Future<void> saveBooks(List<BookItem> books) async {
    try {
      final jsonList = books.map((book) => book.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _storageService.setString(booksKey, jsonString);
      dev.log('Saved ${books.length} books to cache');
    } catch (e) {
      dev.log('Error saving books to storage: $e');
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
      dev.log('Error adding book to storage: $e');
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
      dev.log('Error updating book in storage: $e');
      throw Exception('Failed to update book: $e');
    }
  }

  @override
  Future<void> removeBook(String bookId) async {
    try {
      final books = await getAllBooks();
      final updatedBooks = books.where((book) => book.id != bookId).toList();
      await saveBooks(updatedBooks);
    } catch (e) {
      dev.log('Error removing book from storage: $e');
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
      
      await _clearAllPdfs();
      
      dev.log('Cleared all books cache and PDFs');
    } catch (e) {
      dev.log('Error clearing all books from storage: $e');
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
  Future<List<BookItem>> getBooksPage(int page, int pageSize) async {
    try {
      final allBooks = await getAllBooks();
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, allBooks.length);
      
      if (startIndex >= allBooks.length) return [];
      
      return allBooks.sublist(startIndex, endIndex);
    } catch (e) {
      dev.log('Error getting books page: $e');
      return [];
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
      dev.log('Error reading book hashes: $e');
      return {};
    }
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
  Future<void> cacheImage(String imageUrl, String bookId) async {
    dev.log('Image caching should be handled by repository layer, not datasource');
  }

  @override
  Future<String?> getCachedImagePath(String imageUrl, String bookId) async {
    dev.log('Image path retrieval should be handled by repository layer, not datasource');
    return null;
  }

  @override
  Future<File?> getPdfFile(String bookId) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final file = File('${cacheDir.path}/$bookId.pdf');
      
      if (await file.exists() && await _isValidPDF(file)) {
        return file;
      }
      return null;
    } catch (e) {
      dev.log('Error getting PDF file: $e');
      return null;
    }
  }

  @override
  Future<void> savePdfFile(String bookId, File pdfFile) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final cacheFile = File('${cacheDir.path}/$bookId.pdf');
      await pdfFile.copy(cacheFile.path);
      
      if (!await cacheFile.exists() || await cacheFile.length() == 0) {
        throw Exception('Failed to save PDF file properly');
      }
      
      dev.log('Cached PDF: ${cacheFile.path}');
    } catch (e) {
      dev.log('Error saving PDF file: $e');
      throw Exception('Failed to save PDF file: $e');
    }
  }

  @override
  Future<bool> hasPdfFile(String bookId) async {
    try {
      final file = await getPdfFile(bookId);
      return file != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> deletePdfFile(String bookId) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final file = File('${cacheDir.path}/$bookId.pdf');
      
      if (await file.exists()) {
        await file.delete();
        dev.log('Deleted PDF cache: ${file.path}');
      }
    } catch (e) {
      dev.log('Error deleting PDF file: $e');
    }
  }

  Future<void> _clearAllPdfs() async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      dev.log('Cleared all cached PDFs');
    } catch (e) {
      dev.log('Error clearing all PDFs: $e');
    }
  }

  Future<bool> _isValidPDF(File pdfFile) async {
    try {
      if (!await pdfFile.exists()) return false;
      
      final fileSize = await pdfFile.length();
      if (fileSize < 1024) return false;
      
      final bytes = await pdfFile.readAsBytes();
      if (bytes.length < 4) return false;
      
      final header = String.fromCharCodes(bytes.take(4));
      return header == '%PDF';
    } catch (e) {
      return false;
    }
  }
}