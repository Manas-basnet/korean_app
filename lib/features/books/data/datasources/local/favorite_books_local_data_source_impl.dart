import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';
import 'package:korean_language_app/features/books/data/datasources/local/favorite_books_local_data_source.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

class FavoriteBooksLocalDataSourceImpl implements FavoriteBooksLocalDataSource {
  final StorageService _storageService;
  static const String cacheKey = 'CACHED_FAVORITE_BOOKS';

  FavoriteBooksLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  @override
  Future<List<BookItem>> getAllBooks() async {
    try {
      final jsonString = _storageService.getString(cacheKey);
      if (jsonString == null) return [];
      
      final List<dynamic> decodedJson = json.decode(jsonString);
      return decodedJson.map((item) => BookItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error reading favorite books from storage: $e');
      return [];
    }
  }

  @override
  Future<void> saveBooks(List<BookItem> books) async {
    try {
      final jsonList = books.map((book) => book.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _storageService.setString(cacheKey, jsonString);
    } catch (e) {
      debugPrint('Error saving favorite books: $e');
      throw Exception('Failed to save favorite books: $e');
    }
  }

  @override
  Future<void> addBook(BookItem book) async {
    try {
      final books = await getAllBooks();
      
      if (!books.any((b) => b.id == book.id)) {
        books.add(book);
        books.sort((a, b) => a.title.compareTo(b.title));
        await saveBooks(books);
      }
    } catch (e) {
      debugPrint('Error adding book to favorites: $e');
      throw Exception('Failed to add book to favorites: $e');
    }
  }

  @override
  Future<void> removeBook(String bookId) async {
    try {
      final books = await getAllBooks();
      final updatedBooks = books.where((book) => book.id != bookId).toList();
      await saveBooks(updatedBooks);
    } catch (e) {
      debugPrint('Error removing book from favorites: $e');
      throw Exception('Failed to remove book from favorites: $e');
    }
  }

  @override
  Future<void> clearAllBooks() async {
    try {
      await _storageService.remove(cacheKey);
    } catch (e) {
      debugPrint('Error clearing favorite books: $e');
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
}