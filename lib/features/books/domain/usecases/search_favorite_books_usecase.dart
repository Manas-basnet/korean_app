import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/favorite_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

class SearchFavoriteBooksParams {
  final CourseCategory category;
  final String query;

  const SearchFavoriteBooksParams({
    required this.category,
    required this.query,
  });
}

class SearchFavoriteBooksUseCase extends UseCase<List<BookItem>, SearchFavoriteBooksParams> {
  final FavoriteBookRepository repository;

  SearchFavoriteBooksUseCase({required this.repository});

  @override
  Future<ApiResult<List<BookItem>>> execute(SearchFavoriteBooksParams params) async {
    final trimmedQuery = params.query.trim();
    
    if (trimmedQuery.isEmpty) {
      final allBooksResult = await repository.getBooksFromCache();
      
      if (allBooksResult.isFailure) {
        return ApiResult.failure(
          allBooksResult.error ?? 'Failed to get favorite books',
          allBooksResult.errorType ?? FailureType.unknown,
        );
      }
      
      return ApiResult.success(_removeDuplicates(allBooksResult.data!));
    }

    final result = await repository.searchBooks(params.category, trimmedQuery);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to search favorite books',
        result.errorType ?? FailureType.unknown,
      );
    }

    final books = result.data!;
    final uniqueBooks = _removeDuplicates(books);
    
    return ApiResult.success(uniqueBooks);
  }

  List<BookItem> _removeDuplicates(List<BookItem> books) {
    final uniqueIds = <String>{};
    final uniqueBooks = <BookItem>[];
    
    for (final book in books) {
      if (uniqueIds.add(book.id)) {
        uniqueBooks.add(book);
      }
    }
    
    return uniqueBooks;
  }
}