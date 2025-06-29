import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/favorite_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

class LoadFavoriteBooksParams {
  final CourseCategory category;
  final int page;
  final int pageSize;

  const LoadFavoriteBooksParams({
    required this.category,
    this.page = 0,
    this.pageSize = 5,
  });
}

class LoadFavoriteBooksResult {
  final List<BookItem> books;
  final bool hasMore;

  const LoadFavoriteBooksResult({
    required this.books,
    required this.hasMore,
  });
}

class LoadFavoriteBooksUseCase extends UseCase<LoadFavoriteBooksResult, LoadFavoriteBooksParams> {
  final FavoriteBookRepository repository;

  LoadFavoriteBooksUseCase({required this.repository});

  @override
  Future<ApiResult<LoadFavoriteBooksResult>> execute(LoadFavoriteBooksParams params) async {
    final booksResult = await repository.getBooksFromCache();

    if (booksResult.isFailure) {
      return ApiResult.failure(
        booksResult.error ?? 'Failed to load favorite books',
        booksResult.errorType ?? FailureType.unknown,
      );
    }

    final books = booksResult.data!;
    final uniqueBooks = _removeDuplicates(books);
    
    final hasMoreResult = await repository.hasMoreBooks(params.category, uniqueBooks.length);

    final hasMore = hasMoreResult.fold(
      onSuccess: (hasMore) => hasMore,
      onFailure: (_, __) => false,
    );

    return ApiResult.success(LoadFavoriteBooksResult(
      books: uniqueBooks,
      hasMore: hasMore,
    ));
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