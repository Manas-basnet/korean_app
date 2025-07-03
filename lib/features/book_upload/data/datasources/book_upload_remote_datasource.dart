import 'dart:io';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class BookUploadRemoteDataSource {
  /// Upload book with optional cover image and chapter files atomically
  /// Book is only created if all uploads succeed
  Future<BookItem> uploadBook(BookItem book, {File? imageFile});
  
  /// Update existing book with optional new cover image and chapter files
  /// Returns updated book - operation is atomic
  Future<BookItem> updateBook(String bookId, BookItem updatedBook, {File? imageFile});
  
  /// Delete book and all associated files (cover image, chapter images, PDFs, audio files)
  Future<bool> deleteBook(String bookId);
  
  /// Get when the book was last updated
  Future<DateTime?> getBookLastUpdated(String bookId);
  
  /// Regenerate download URL from storage path (useful for expired URLs)
  Future<String?> regenerateUrlFromPath(String storagePath);
  
  /// Verify if a URL is still working
  Future<bool> verifyUrlIsWorking(String url);
}