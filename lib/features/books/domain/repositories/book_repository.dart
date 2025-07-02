import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class BookRepository {
  Future<List<BookItem>> getBooks(CourseCategory category, {int page = 0, int pageSize = 5});
  Future<bool> hasMoreBooks(CourseCategory category, int currentCount);
  Future<List<BookItem>> hardRefreshBooks(CourseCategory category, {int pageSize = 5});
  Future<List<BookItem>> getBooksFromCache();
  Future<List<BookItem>> searchBooks(CourseCategory category, String query);
  Future clearCachedBooks();
}