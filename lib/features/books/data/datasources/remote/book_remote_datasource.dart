import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

abstract class BooksRemoteDataSource {
  Future<List<BookItem>> getBooks({
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<List<BookItem>> getBooksByCategory(
    TestCategory category, {
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<bool> hasMoreBooks(int currentCount, [TestSortType? sortType]);
  Future<bool> hasMoreBooksByCategory(TestCategory category, int currentCount, [TestSortType? sortType]);
  Future<List<BookItem>> searchBooks(String query);
  Future<BookItem?> getBookById(String bookId);
  
  Future<void> recordBookView(String bookId, String userId);
  Future<void> rateBook(String bookId, String userId, double rating);

  Future<UserBookInteraction?> completeBookWithViewAndRating(
    String bookId, 
    String userId, 
    double? rating,
    UserBookInteraction? userInteraction
  );

  Future<UserBookInteraction?> getUserBookInteraction(String bookId, String userId);
}