import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

class PreloadBookAudioTracksParams {
  final String bookId;

  const PreloadBookAudioTracksParams({
    required this.bookId,
  });
}

class PreloadBookAudioTracksUseCase extends UseCase<void, PreloadBookAudioTracksParams> {
  final KoreanBookRepository repository;

  PreloadBookAudioTracksUseCase({required this.repository});

  @override
  Future<ApiResult<void>> execute(PreloadBookAudioTracksParams params) async {
    if (params.bookId.isEmpty) {
      return ApiResult.failure(
        'Book ID cannot be empty',
        FailureType.validation,
      );
    }

    final result = await repository.preloadBookAudioTracks(params.bookId);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to preload book audio tracks',
        result.errorType ?? FailureType.unknown,
      );
    }

    return ApiResult.success(null);
  }
}

class PreloadChapterAudioTracksParams {
  final String bookId;
  final String chapterId;

  const PreloadChapterAudioTracksParams({
    required this.bookId,
    required this.chapterId,
  });
}

class PreloadChapterAudioTracksUseCase extends UseCase<void, PreloadChapterAudioTracksParams> {
  final KoreanBookRepository repository;

  PreloadChapterAudioTracksUseCase({required this.repository});

  @override
  Future<ApiResult<void>> execute(PreloadChapterAudioTracksParams params) async {
    if (params.bookId.isEmpty) {
      return ApiResult.failure(
        'Book ID cannot be empty',
        FailureType.validation,
      );
    }

    if (params.chapterId.isEmpty) {
      return ApiResult.failure(
        'Chapter ID cannot be empty',
        FailureType.validation,
      );
    }

    final result = await repository.preloadChapterAudioTracks(params.bookId, params.chapterId);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to preload chapter audio tracks',
        result.errorType ?? FailureType.unknown,
      );
    }

    return ApiResult.success(null);
  }
}