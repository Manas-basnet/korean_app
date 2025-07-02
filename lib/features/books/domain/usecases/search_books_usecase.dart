import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class SearchBooksParams {
  final CourseCategory category;
  final String query;

  const SearchBooksParams({
    required this.category,
    required this.query,
  });
}

class SearchBooksUseCase extends UseCase<List<BookItem>, SearchBooksParams> {
  final KoreanBookRepository repository;

  SearchBooksUseCase({required this.repository});

  @override
  Future<ApiResult<List<BookItem>>> execute(SearchBooksParams params) async {
    final trimmedQuery = params.query.trim();
    
    if (trimmedQuery.length < 2) {
      return ApiResult.success([]);
    }

    final result = await repository.searchBooks(params.category, trimmedQuery);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to search books',
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