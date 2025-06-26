import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

abstract class BookUploadRepository {
  /// Create book with PDF and optional cover image - atomic operation
  Future<ApiResult<BookItem>> createBook(BookItem book, File pdfFile, {File? coverImageFile});
  
  /// Create book with chapters and optional cover image - atomic operation
  Future<ApiResult<BookItem>> createBookWithChapters(
    BookItem book, 
    List<ChapterUploadData> chapters, 
    {File? coverImageFile}
  );
  
  /// Update book with optional new PDF and/or cover image - atomic operation
  Future<ApiResult<BookItem>> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? coverImageFile});
  
  /// Update book with chapters and optional cover image - atomic operation
  Future<ApiResult<BookItem>> updateBookWithChapters(
    String bookId, 
    BookItem updatedBook, 
    List<ChapterUploadData>? chapters, 
    {File? coverImageFile}
  );
  
  /// Delete book and all associated files
  Future<ApiResult<bool>> deleteBook(String bookId);
  
  Future<ApiResult<bool>> hasEditPermission(String bookId, String userId);
  Future<ApiResult<bool>> hasDeletePermission(String bookId, String userId);
}