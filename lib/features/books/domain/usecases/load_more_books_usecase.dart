import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class LoadMoreBooksParams {
  final CourseCategory category;
  final List<BookItem> existingBooks;
  final int pageSize;

  const LoadMoreBooksParams({
    required this.category,
    required this.existingBooks,
    this.pageSize = 5,
  });
}

class LoadMoreBooksResult {
  final List<BookItem> newBooks;
  final List<BookItem> allBooks;
  final bool hasMore;

  const LoadMoreBooksResult({
    required this.newBooks,
    required this.allBooks,
    required this.hasMore,
  });
}

class LoadMoreBooksUseCase extends UseCase<LoadMoreBooksResult, LoadMoreBooksParams> {
  final KoreanBookRepository repository;

  LoadMoreBooksUseCase({required this.repository});

  @override
  Future<ApiResult<LoadMoreBooksResult>> execute(LoadMoreBooksParams params) async {
    final currentPage = (params.existingBooks.length / params.pageSize).ceil();
    
    final booksResult = await repository.getBooks(
      params.category,
      page: currentPage,
      pageSize: params.pageSize,
    );

    if (booksResult.isFailure) {
      return ApiResult.failure(
        booksResult.error ?? 'Failed to load more books',
        booksResult.errorType ?? FailureType.unknown,
      );
    }

    final moreBooks = booksResult.data!;
    final existingIds = params.existingBooks.map((book) => book.id).toSet();
    final uniqueNewBooks = moreBooks
        .where((book) => !existingIds.contains(book.id))
        .toList();

    final allBooks = [...params.existingBooks, ...uniqueNewBooks];
    final hasMoreResult = await repository.hasMoreBooks(params.category, allBooks.length);

    final hasMore = hasMoreResult.fold(
      onSuccess: (hasMore) => hasMore,
      onFailure: (_, __) => false,
    );

    return ApiResult.success(LoadMoreBooksResult(
      newBooks: uniqueNewBooks,
      allBooks: allBooks,
      hasMore: hasMore,
    ));
  }
}