import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class LoadBooksParams {
  final CourseCategory category;
  final int page;
  final int pageSize;

  const LoadBooksParams({
    required this.category,
    this.page = 0,
    this.pageSize = 5,
  });
}

class LoadBooksResult {
  final List<BookItem> books;
  final bool hasMore;

  const LoadBooksResult({
    required this.books,
    required this.hasMore,
  });
}

class LoadBooksUseCase extends UseCase<LoadBooksResult, LoadBooksParams> {
  final KoreanBookRepository repository;

  LoadBooksUseCase({required this.repository});

  @override
  Future<ApiResult<LoadBooksResult>> execute(LoadBooksParams params) async {
    final booksResult = await repository.getBooks(
      params.category,
      page: params.page,
      pageSize: params.pageSize,
    );

    if (booksResult.isFailure) {
      return ApiResult.failure(
        booksResult.error ?? 'Failed to load books',
        booksResult.errorType ?? FailureType.unknown,
      );
    }

    final books = booksResult.data!;
    final hasMoreResult = await repository.hasMoreBooks(params.category, books.length);

    final hasMore = hasMoreResult.fold(
      onSuccess: (hasMore) => hasMore,
      onFailure: (_, __) => false,
    );

    return ApiResult.success(LoadBooksResult(
      books: books,
      hasMore: hasMore,
    ));
  }
}