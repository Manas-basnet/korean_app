import 'dart:io';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class KoreanBooksRemoteDataSource {
  Future<List<BookItem>> getKoreanBooks({
    int page = 0, 
    int pageSize = 5,
  });
  Future<bool> hasMoreBooks(int currentCount);
  Future<List<BookItem>> searchKoreanBooks(String query);
  Future<bool> updateBook(String bookId, BookItem updatedBook);
  
  /// Single PDF download methods
  Future<File?> downloadPdfToLocal(String bookId, String localPath);
  Future<String?> getPdfDownloadUrl(String bookId);
  
  /// Chapter PDF download methods
  Future<File?> downloadChapterPdfToLocal(String bookId, String chapterId, String localPath);
  Future<String?> getChapterPdfDownloadUrl(String bookId, String chapterId);
  
  Future<String?> regenerateUrlFromPath(String storagePath);
}