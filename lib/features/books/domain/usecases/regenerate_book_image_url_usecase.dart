import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

class RegenerateBookImageUrlParams {
  final BookItem book;

  const RegenerateBookImageUrlParams({required this.book});
}

class RegenerateBookImageUrlResult {
  final BookItem updatedBook;
  final String? newImageUrl;

  const RegenerateBookImageUrlResult({
    required this.updatedBook,
    this.newImageUrl,
  });
}

class RegenerateBookImageUrlUseCase extends UseCase<RegenerateBookImageUrlResult?, RegenerateBookImageUrlParams> {
  final KoreanBookRepository repository;

  RegenerateBookImageUrlUseCase({required this.repository});

  @override
  Future<ApiResult<RegenerateBookImageUrlResult?>> execute(RegenerateBookImageUrlParams params) async {
    if (params.book.bookImagePath == null || params.book.bookImagePath!.isEmpty) {
      return ApiResult.success(null);
    }

    final result = await repository.regenerateImageUrl(params.book);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to regenerate image URL',
        result.errorType ?? FailureType.unknown,
      );
    }

    final newImageUrl = result.data;
    
    if (newImageUrl != null && newImageUrl.isNotEmpty) {
      final updatedBook = params.book.copyWith(bookImage: newImageUrl);
      
      return ApiResult.success(RegenerateBookImageUrlResult(
        updatedBook: updatedBook,
        newImageUrl: newImageUrl,
      ));
    }

    return ApiResult.success(null);
  }
}