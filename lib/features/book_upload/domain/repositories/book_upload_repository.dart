import 'dart:io';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class BookUploadRepository {
  /// Create book with optional cover image - atomic operation
  /// Handles upload of cover image, chapter images, PDFs, and audio files
  Future<ApiResult<BookItem>> createBook(BookItem book, {File? imageFile});
  
  /// Update book with optional new cover image - atomic operation
  /// Handles upload of new files and cleanup of old ones
  Future<ApiResult<BookItem>> updateBook(String bookId, BookItem updatedBook, {File? imageFile});
  
  /// Delete book and all associated files (cover, chapter images, PDFs, audio files)
  Future<ApiResult<bool>> deleteBook(String bookId);
  
  /// Regenerate cover image URL from storage path if needed
  Future<ApiResult<String?>> regenerateImageUrl(BookItem book);
  
  /// Regenerate all file URLs (cover, chapter images, PDFs, audio files) for a book
  /// Returns updated book if any URLs were regenerated, null if no updates needed
  Future<ApiResult<BookItem?>> regenerateAllFileUrls(BookItem book);
  
  /// Verify if all file URLs in a book are working
  Future<ApiResult<bool>> verifyFileUrls(BookItem book);
  
  /// Check if user has permission to edit the book
  Future<ApiResult<bool>> hasEditPermission(String bookId, String userId);
}