import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/favorite_book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class ToggleFavoriteBookParams {
  final BookItem book;
  final List<BookItem> currentFavorites;

  const ToggleFavoriteBookParams({
    required this.book,
    required this.currentFavorites,
  });
}

class ToggleFavoriteBookResult {
  final List<BookItem> updatedFavorites;
  final bool wasAdded;
  final bool hasMore;

  const ToggleFavoriteBookResult({
    required this.updatedFavorites,
    required this.wasAdded,
    required this.hasMore,
  });
}

class ToggleFavoriteBookUseCase extends UseCase<ToggleFavoriteBookResult, ToggleFavoriteBookParams> {
  final FavoriteBookRepository repository;

  ToggleFavoriteBookUseCase({required this.repository});

  @override
  Future<ApiResult<ToggleFavoriteBookResult>> execute(ToggleFavoriteBookParams params) async {
    final isAlreadyFavorite = params.currentFavorites.any((book) => book.id == params.book.id);
    
    final result = isAlreadyFavorite
        ? await repository.removeBookFromFavorite(params.book)
        : await repository.addFavoritedBook(params.book);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to toggle favorite status',
        result.errorType ?? FailureType.unknown,
      );
    }

    final updatedBooks = result.data!;
    final hasMoreResult = await repository.hasMoreBooks(CourseCategory.favorite, updatedBooks.length);

    final hasMore = hasMoreResult.fold(
      onSuccess: (hasMore) => hasMore,
      onFailure: (_, __) => false,
    );

    return ApiResult.success(ToggleFavoriteBookResult(
      updatedFavorites: updatedBooks,
      wasAdded: !isAlreadyFavorite,
      hasMore: hasMore,
    ));
  }
}