import 'dart:io';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class KoreanBookRepository {
  Future<ApiResult<List<BookItem>>> getBooks(CourseCategory category, {int page = 0, int pageSize = 5});
  Future<ApiResult<bool>> hasMoreBooks(CourseCategory category, int currentCount);
  Future<ApiResult<List<BookItem>>> hardRefreshBooks(CourseCategory category, {int pageSize = 5});
  Future<ApiResult<List<BookItem>>> searchBooks(CourseCategory category, String query);
  
  // PDF file methods
  Future<ApiResult<File?>> getBookPdf(String bookId);
  Future<ApiResult<File?>> getChapterPdf(String bookId, String chapterId);
  
  // Audio file methods
  Future<ApiResult<File?>> getBookAudioTrack(String bookId, String audioTrackId);
  Future<ApiResult<File?>> getChapterAudioTrack(String bookId, String chapterId, String audioTrackId);
  Future<ApiResult<void>> preloadBookAudioTracks(String bookId);
  Future<ApiResult<void>> preloadChapterAudioTracks(String bookId, String chapterId);
  
  Future<ApiResult<String?>> regenerateImageUrl(BookItem book);
}