import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class GetBookByIdParams {
  final String bookId;
  final bool recordView;

  const GetBookByIdParams({
    required this.bookId,
    this.recordView = false,
  });
}

class GetBookByIdUseCase implements UseCase<BookItem, GetBookByIdParams> {
  final BooksRepository repository;
  final AuthService authService;

  GetBookByIdUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BookItem>> execute(GetBookByIdParams params) async {
    try {
      debugPrint('GetBookByIdUseCase: Loading book ${params.bookId}');

      if (params.bookId.isEmpty) {
        return ApiResult.failure(
          'Book ID cannot be empty',
          FailureType.validation,
        );
      }

      final result = await repository.getBookById(params.bookId);

      return result.fold(
        onSuccess: (book) async {
          if (book == null) {
            debugPrint('GetBookByIdUseCase: Book ${params.bookId} not found');
            return ApiResult.failure(
              'Book not found',
              FailureType.notFound,
            );
          }

          if (params.recordView) {
            final user = authService.getCurrentUser();
            if (user != null) {
              try {
                await repository.recordBookView(params.bookId, user.uid);
                debugPrint('GetBookByIdUseCase: Recorded view for book ${params.bookId}');
              } catch (e) {
                debugPrint('GetBookByIdUseCase: Failed to record view - $e');
              }
            }
          }

          debugPrint('GetBookByIdUseCase: Successfully loaded book ${book.title}');
          return ApiResult.success(book);
        },
        onFailure: (message, type) {
          debugPrint('GetBookByIdUseCase: Failed to load book - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('GetBookByIdUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load book: $e', FailureType.unknown);
    }
  }
}