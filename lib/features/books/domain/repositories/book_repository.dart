import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class BooksRepository {
  Future<ApiResult<List<BookItem>>> getBooks({
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<List<BookItem>>> getBooksByCategory(
    TestCategory category, {
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<bool>> hasMoreBooks(int currentCount, [TestSortType? sortType]);
  Future<ApiResult<bool>> hasMoreBooksByCategory(TestCategory category, int currentCount, [TestSortType? sortType]);
  
  Future<ApiResult<List<BookItem>>> hardRefreshBooks({
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<List<BookItem>>> hardRefreshBooksByCategory(
    TestCategory category, {
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<List<BookItem>>> searchBooks(String query);
  Future<ApiResult<BookItem?>> getBookById(String bookId);
  
  Future<ApiResult<void>> recordBookView(String bookId, String userId);
  Future<ApiResult<void>> rateBook(String bookId, String userId, double rating);
  Future<ApiResult<UserBookInteraction?>> completeBookWithViewAndRating(String bookId, String userId, double? rating, UserBookInteraction? userInteraction);
  Future<ApiResult<UserBookInteraction?>> getUserBookInteraction(String bookId, String userId);
}