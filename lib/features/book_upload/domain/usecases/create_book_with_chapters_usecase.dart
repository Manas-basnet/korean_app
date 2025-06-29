import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/shared/models/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';

class CreateBookWithChaptersParams {
  final BookItem book;
  final List<ChapterUploadData> chapters;
  final File? coverImageFile;

  const CreateBookWithChaptersParams({
    required this.book,
    required this.chapters,
    this.coverImageFile,
  });
}

class CreateBookWithChaptersUseCase extends UseCase<BookItem, CreateBookWithChaptersParams> {
  final BookUploadRepository repository;
  final AuthService authService;

  CreateBookWithChaptersUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BookItem>> execute(CreateBookWithChaptersParams params) async {
    final user = authService.getCurrentUser();
    if (user == null) {
      return ApiResult.failure(
        'User not authenticated',
        FailureType.auth,
      );
    }

    if (params.chapters.isEmpty) {
      return ApiResult.failure(
        'No chapters provided',
        FailureType.validation,
      );
    }

    final String newBookId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final bookWithId = params.book.copyWith(
      id: newBookId,
      creatorUid: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      chaptersCount: params.chapters.length,
      uploadType: BookUploadType.chapterWise,
    );

    return repository.createBookWithChapters(
      bookWithId,
      params.chapters,
      coverImageFile: params.coverImageFile,
    );
  }
}