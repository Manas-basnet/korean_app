import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class UpdateBookWithChaptersParams {
  final String bookId;
  final BookItem updatedBook;
  final List<ChapterUploadData>? chapters;
  final File? coverImageFile;

  const UpdateBookWithChaptersParams({
    required this.bookId,
    required this.updatedBook,
    this.chapters,
    this.coverImageFile,
  });
}

class UpdateBookWithChaptersUseCase extends UseCase<BookItem, UpdateBookWithChaptersParams> {
  final BookUploadRepository repository;
  final AuthService authService;

  UpdateBookWithChaptersUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BookItem>> execute(UpdateBookWithChaptersParams params) async {
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
      chaptersCount: params.chapters?.length ?? params.updatedBook.chaptersCount,
    );

    return repository.updateBookWithChapters(
      params.bookId,
      updatedBookWithMeta,
      params.chapters,
      coverImageFile: params.coverImageFile,
    );
  }
}