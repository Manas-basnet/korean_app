import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class RefreshBooksParams {
  final CourseCategory category;
  final int pageSize;

  const RefreshBooksParams({
    required this.category,
    this.pageSize = 5,
  });
}

class RefreshBooksResult {
  final List<BookItem> books;
  final bool hasMore;

  const RefreshBooksResult({
    required this.books,
    required this.hasMore,
  });
}

class RefreshBooksUseCase extends UseCase<RefreshBooksResult, RefreshBooksParams> {
  final KoreanBookRepository repository;

  RefreshBooksUseCase({required this.repository});

  @override
  Future<ApiResult<RefreshBooksResult>> execute(RefreshBooksParams params) async {
    final booksResult = await repository.hardRefreshBooks(
      params.category,
      pageSize: params.pageSize,
    );

    if (booksResult.isFailure) {
      return ApiResult.failure(
        booksResult.error ?? 'Failed to refresh books',
        booksResult.errorType ?? FailureType.unknown,
      );
    }

    final books = booksResult.data!;
    final hasMoreResult = await repository.hasMoreBooks(params.category, books.length);

    final hasMore = hasMoreResult.fold(
      onSuccess: (hasMore) => hasMore,
      onFailure: (_, __) => false,
    );

    return ApiResult.success(RefreshBooksResult(
      books: books,
      hasMore: hasMore,
    ));
  }
}