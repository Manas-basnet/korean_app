import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

class GetChapterAudioTrackParams {
  final String bookId;
  final String chapterId;
  final String audioTrackId;

  const GetChapterAudioTrackParams({
    required this.bookId,
    required this.chapterId,
    required this.audioTrackId,
  });
}

class GetChapterAudioTrackUseCase extends UseCase<File?, GetChapterAudioTrackParams> {
  final KoreanBookRepository repository;

  GetChapterAudioTrackUseCase({required this.repository});

  @override
  Future<ApiResult<File?>> execute(GetChapterAudioTrackParams params) async {
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

    if (params.audioTrackId.isEmpty) {
      return ApiResult.failure(
        'Audio track ID cannot be empty',
        FailureType.validation,
      );
    }

    final result = await repository.getChapterAudioTrack(
      params.bookId, 
      params.chapterId, 
      params.audioTrackId
    );
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to get chapter audio track',
        result.errorType ?? FailureType.unknown,
      );
    }

    final audioFile = result.data;
    
    if (audioFile == null) {
      return ApiResult.failure(
        'Chapter audio track file not found or corrupted',
        FailureType.notFound,
      );
    }

    return ApiResult.success(audioFile);
  }
}