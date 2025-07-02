import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class UpdateBookParams {
  final String bookId;
  final BookItem updatedBook;
  final File? pdfFile;
  final File? coverImageFile;
  final List<AudioTrackUploadData>? audioTracks;

  const UpdateBookParams({
    required this.bookId,
    required this.updatedBook,
    this.pdfFile,
    this.coverImageFile,
    this.audioTracks,
  });
}

class UpdateBookUseCase extends UseCase<BookItem, UpdateBookParams> {
  final BookUploadRepository repository;
  final AuthService authService;

  UpdateBookUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BookItem>> execute(UpdateBookParams params) async {
    final user = authService.getCurrentUser();
    if (user == null) {
      return ApiResult.failure(
        'User not authenticated',
        FailureType.auth,
      );
    }

    final permissionResult = await repository.hasEditPermission(params.bookId, user.uid);
    if (permissionResult.isFailure || !(permissionResult.data ?? false)) {
      return ApiResult.failure(
        'You do not have permission to edit this book',
        FailureType.permission,
      );
    }

    final updatedBookWithMeta = params.updatedBook.copyWith(
      updatedAt: DateTime.now(),
    );

    return repository.updateBook(
      params.bookId,
      updatedBookWithMeta,
      pdfFile: params.pdfFile,
      coverImageFile: params.coverImageFile,
      audioTracks: params.audioTracks,
    );
  }
}