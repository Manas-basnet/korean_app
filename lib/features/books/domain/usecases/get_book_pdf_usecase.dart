import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

class GetBookPdfParams {
  final String bookId;

  const GetBookPdfParams({required this.bookId});
}

class GetBookPdfUseCase extends UseCase<File?, GetBookPdfParams> {
  final KoreanBookRepository repository;

  GetBookPdfUseCase({required this.repository});

  @override
  Future<ApiResult<File?>> execute(GetBookPdfParams params) async {
    if (params.bookId.isEmpty) {
      return ApiResult.failure(
        'Book ID cannot be empty',
        FailureType.validation,
      );
    }

    final result = await repository.getBookPdf(params.bookId);
    
    if (result.isFailure) {
      return ApiResult.failure(
        result.error ?? 'Failed to get book PDF',
        result.errorType ?? FailureType.unknown,
      );
    }

    final pdfFile = result.data;
    
    if (pdfFile == null) {
      return ApiResult.failure(
        'PDF file not found or corrupted',
        FailureType.notFound,
      );
    }

    return ApiResult.success(pdfFile);
  }
}