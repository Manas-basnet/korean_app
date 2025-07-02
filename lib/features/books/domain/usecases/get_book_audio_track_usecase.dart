import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

class GetBookAudioTrackParams {
  final String bookId;
  final String audioTrackId;

  const GetBookAudioTrackParams({
    required this.bookId,
    required this.audioTrackId,
  });
}

class GetBookAudioTrackUseCase extends UseCase<File?, GetBookAudioTrackParams> {
  final KoreanBookRepository repository;

  GetBookAudioTrackUseCase({required this.repository});

  @override
  Future<ApiResult<File?>> execute(GetBookAudioTrackParams params) async {
    if (params.bookId.isEmpty) {
      return ApiResult.failure(
        'Book ID cannot be empty',
        FailureType.validation,
      );
    }

    if (params.audioTrackId.isEmpty) {
      return ApiResult.failure(
        'Audio track ID cannot be empty',
        FailureType.validation,
      );
    }

    final result = await repository.getBookAudioTrack(params.bookId, params.audioTrackId);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to get book audio track',
        result.errorType ?? FailureType.unknown,
      );
    }

    final audioFile = result.data;
    
    if (audioFile == null) {
      return ApiResult.failure(
        'Audio track file not found or corrupted',
        FailureType.notFound,
      );
    }

    return ApiResult.success(audioFile);
  }
}