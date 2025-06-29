import 'dart:io';

import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/shared/models/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class CreateBookParams {
  final BookItem book;
  final File pdfFile;
  final File? coverImageFile;
  final List<AudioTrackUploadData>? audioTracks;

  const CreateBookParams({
    required this.book,
    required this.pdfFile,
    this.coverImageFile,
    this.audioTracks,
  });
}

class CreateBookUseCase extends UseCase<BookItem, CreateBookParams> {
  final BookUploadRepository repository;
  final AuthService authService;

  CreateBookUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BookItem>> execute(CreateBookParams params) async {
    final user = authService.getCurrentUser();
    if (user == null) {
      return ApiResult.failure(
        'User not authenticated',
        FailureType.auth,
      );
    }

    final String newBookId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final bookWithId = params.book.copyWith(
      id: newBookId,
      creatorUid: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return repository.createBook(
      bookWithId,
      params.pdfFile,
      coverImageFile: params.coverImageFile,
      audioTracks: params.audioTracks,
    );
  }
}