import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

class GetChapterPdfParams {
  final String bookId;
  final String chapterId;

  const GetChapterPdfParams({
    required this.bookId,
    required this.chapterId,
  });
}

class GetChapterPdfUseCase extends UseCase<File?, GetChapterPdfParams> {
  final KoreanBookRepository repository;

  GetChapterPdfUseCase({required this.repository});

  @override
  Future<ApiResult<File?>> execute(GetChapterPdfParams params) async {
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

    final result = await repository.getChapterPdf(params.bookId, params.chapterId);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to get chapter PDF',
        result.errorType ?? FailureType.unknown,
      );
    }

    final pdfFile = result.data;
    
    if (pdfFile == null) {
      return ApiResult.failure(
        'Chapter PDF file not found or corrupted',
        FailureType.notFound,
      );
    }

    return ApiResult.success(pdfFile);
  }
}