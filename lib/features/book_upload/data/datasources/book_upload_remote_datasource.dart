import 'dart:io';

import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

abstract class BookUploadRemoteDataSource {
  /// Upload book with PDF and optional cover image atomically - returns created book
  Future<BookItem> uploadBook(BookItem book, File pdfFile, {File? coverImageFile});
  
  /// Upload book with chapters and optional cover image atomically - returns created book
  Future<BookItem> uploadBookWithChapters(
    BookItem book, 
    List<ChapterUploadData> chapters, 
    {File? coverImageFile}
  );
  
  /// Update existing book with optional new PDF and/or cover image - returns updated book
  Future<BookItem> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? coverImageFile});
  
  /// Update existing book with chapters and optional cover image - returns updated book
  Future<BookItem> updateBookWithChapters(
    String bookId, 
    BookItem updatedBook, 
    List<ChapterUploadData>? chapters, 
    {File? coverImageFile}
  );
  
  /// Delete book and all associated files
  Future<bool> deleteBook(String bookId);
  
  Future<List<BookItem>> searchBookById(String bookId);
  Future<BookItem?> getBookById(String bookId);
}