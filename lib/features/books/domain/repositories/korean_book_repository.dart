import 'dart:io';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/data/models/book_item.dart';

abstract class KoreanBookRepository {
  Future<ApiResult<List<BookItem>>> getBooks(CourseCategory category, {int page = 0, int pageSize = 5});
  Future<ApiResult<bool>> hasMoreBooks(CourseCategory category, int currentCount);
  Future<ApiResult<List<BookItem>>> hardRefreshBooks(CourseCategory category, {int pageSize = 5});
  Future<ApiResult<List<BookItem>>> searchBooks(CourseCategory category, String query);
  
  Future<ApiResult<File?>> getBookPdf(String bookId);
  Future<ApiResult<String?>> regenerateImageUrl(BookItem book);
}