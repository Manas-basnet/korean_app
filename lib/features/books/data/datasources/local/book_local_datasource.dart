import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';

abstract class BooksLocalDataSource {
  Future<List<BookItem>> getAllBooks();
  Future<void> saveBooks(List<BookItem> books);
  Future<void> addBook(BookItem book);
  Future<void> updateBook(BookItem book);
  Future<void> removeBook(String bookId);
  Future<void> clearAllBooks();
  Future<bool> hasAnyBooks();
  Future<int> getBooksCount();
  
  Future<void> setLastSyncTime(DateTime dateTime);
  Future<DateTime?> getLastSyncTime();
  Future<void> setBookHashes(Map<String, String> hashes);
  Future<Map<String, String>> getBookHashes();
  
  Future<List<BookItem>> getBooksPage(int page, int pageSize, {TestSortType sortType = TestSortType.recent});
  Future<List<BookItem>> getBooksByCategoryPage(String category, int page, int pageSize, {TestSortType sortType = TestSortType.recent});
  
  Future<void> setTotalBooksCount(int count);
  Future<int?> getTotalBooksCount();
  Future<void> setCategoryBooksCount(String category, int count);
  Future<int?> getCategoryBooksCount(String category);

  Future<void> cacheImage(String imageUrl, String bookId, String imageType);
  Future<void> cacheAudio(String audioUrl, String bookId, String audioType);
  Future<void> cachePdf(String pdfUrl, String bookId, String pdfType);
  
  Future<String?> getCachedImagePath(String imageUrl, String bookId, String imageType);
  Future<String?> getCachedAudioPath(String audioUrl, String bookId, String audioType);
  Future<String?> getCachedPdfPath(String pdfUrl, String bookId, String pdfType);

  Future<bool> saveUserBookInteraction(UserBookInteraction userInteraction);
  Future<UserBookInteraction?> getUserBookInteraction(String bookId, String userId);
}