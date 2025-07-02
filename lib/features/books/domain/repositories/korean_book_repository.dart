import 'dart:io';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class KoreanBookRepository {
  Future<ApiResult<List<BookItem>>> getBooks(CourseCategory category, {int page = 0, int pageSize = 5});
  Future<ApiResult<bool>> hasMoreBooks(CourseCategory category, int currentCount);
  Future<ApiResult<List<BookItem>>> hardRefreshBooks(CourseCategory category, {int pageSize = 5});
  Future<ApiResult<List<BookItem>>> searchBooks(CourseCategory category, String query);
  
  /// Get PDF file for single PDF books
  Future<ApiResult<File?>> getBookPdf(String bookId);
  
  /// Get PDF file for a specific chapter in chapter-wise books
  Future<ApiResult<File?>> getChapterPdf(String bookId, String chapterId);
  
  Future<ApiResult<String?>> regenerateImageUrl(BookItem book);
}