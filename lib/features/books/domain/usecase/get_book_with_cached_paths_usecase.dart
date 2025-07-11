import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class GetBookWithCachedPathsUseCase implements UseCase<BookItem, BookItem> {
  final BooksRepository repository;

  GetBookWithCachedPathsUseCase({
    required this.repository,
  });

  @override
  Future<ApiResult<BookItem>> execute(BookItem book) async {
    try {
      debugPrint('GetBookWithCachedPathsUseCase: Processing book ${book.id} for cached paths');
      
      final result = await repository.getBookWithCachedPaths(book);
      
      return result.fold(
        onSuccess: (processedBook) {
          debugPrint('GetBookWithCachedPathsUseCase: Successfully processed book with cached paths');
          return ApiResult.success(processedBook);
        },
        onFailure: (message, type) {
          debugPrint('GetBookWithCachedPathsUseCase: Failed to process book - $message');
          return ApiResult.success(book);
        },
      );
    } catch (e) {
      debugPrint('GetBookWithCachedPathsUseCase: Unexpected error - $e');
      return ApiResult.success(book);
    }
  }
}