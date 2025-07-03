import 'dart:io';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';

class BookUploadRepositoryImpl extends BaseRepository implements BookUploadRepository {
  final BookUploadRemoteDataSource remoteDataSource;
  final AdminPermissionService adminService;

  BookUploadRepositoryImpl({
    required this.remoteDataSource,
    required this.adminService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<BookItem>> createBook(BookItem book, {File? imageFile}) async {
    return handleRepositoryCall(() async {
      final createdBook = await remoteDataSource.uploadBook(book, imageFile: imageFile);
      return ApiResult.success(createdBook);
    });
  }

  @override
  Future<ApiResult<BookItem>> updateBook(String bookId, BookItem updatedBook, {File? imageFile}) async {
    return handleRepositoryCall(() async {
      final updatedBookResult = await remoteDataSource.updateBook(bookId, updatedBook, imageFile: imageFile);
      return ApiResult.success(updatedBookResult);
    });
  }

  @override
  Future<ApiResult<bool>> deleteBook(String bookId) async {
    return handleRepositoryCall(() async {
      final success = await remoteDataSource.deleteBook(bookId);
      if (!success) {
        throw Exception('Failed to delete book');
      }
      return ApiResult.success(true);
    });
  }

  @override
  Future<ApiResult<String?>> regenerateImageUrl(BookItem book) async {
    if (book.imagePath == null || book.imagePath!.isEmpty) {
      return ApiResult.success(null);
    }

    return handleRepositoryCall(() async {
      final newUrl = await remoteDataSource.regenerateUrlFromPath(book.imagePath!);
      
      if (newUrl != null && newUrl.isNotEmpty) {
        final updatedBook = book.copyWith(imageUrl: newUrl);
        
        try {
          await remoteDataSource.updateBook(book.id, updatedBook);
        } catch (e) {
          // Log but continue - we still return the regenerated URL
        }
      }
      
      return ApiResult.success(newUrl);
    });
  }

  @override
  Future<ApiResult<BookItem?>> regenerateAllFileUrls(BookItem book) async {
    return handleRepositoryCall(() async {
      var updatedBook = book;
      bool hasUpdates = false;

      // Regenerate cover image URL
      if (book.imagePath != null && book.imagePath!.isNotEmpty) {
        final newCoverUrl = await remoteDataSource.regenerateUrlFromPath(book.imagePath!);
        if (newCoverUrl != null && newCoverUrl != book.imageUrl) {
          updatedBook = updatedBook.copyWith(imageUrl: newCoverUrl);
          hasUpdates = true;
        }
      }

      final updatedChapters = <BookChapter>[];
      for (final chapter in book.chapters) {
        var updatedChapter = chapter;
        bool chapterHasUpdates = false;

        // Regenerate chapter image URL
        if (chapter.imagePath != null && chapter.imagePath!.isNotEmpty) {
          final newChapterImageUrl = await remoteDataSource.regenerateUrlFromPath(chapter.imagePath!);
          if (newChapterImageUrl != null && newChapterImageUrl != chapter.imageUrl) {
            updatedChapter = updatedChapter.copyWith(imageUrl: newChapterImageUrl);
            chapterHasUpdates = true;
            hasUpdates = true;
          }
        }

        // Regenerate PDF URL
        if (chapter.pdfPath != null && chapter.pdfPath!.isNotEmpty) {
          final newPdfUrl = await remoteDataSource.regenerateUrlFromPath(chapter.pdfPath!);
          if (newPdfUrl != null && newPdfUrl != chapter.pdfUrl) {
            updatedChapter = updatedChapter.copyWith(pdfUrl: newPdfUrl);
            chapterHasUpdates = true;
            hasUpdates = true;
          }
        }

        // Regenerate audio track URLs
        final updatedAudioTracks = <AudioTrack>[];
        for (final audioTrack in chapter.audioTracks) {
          var updatedAudioTrack = audioTrack;
          
          if (audioTrack.audioPath != null && audioTrack.audioPath!.isNotEmpty) {
            final newAudioUrl = await remoteDataSource.regenerateUrlFromPath(audioTrack.audioPath!);
            if (newAudioUrl != null && newAudioUrl != audioTrack.audioUrl) {
              updatedAudioTrack = audioTrack.copyWith(audioUrl: newAudioUrl);
              chapterHasUpdates = true;
              hasUpdates = true;
            }
          }
          
          updatedAudioTracks.add(updatedAudioTrack);
        }

        if (chapterHasUpdates) {
          updatedChapter = updatedChapter.copyWith(audioTracks: updatedAudioTracks);
        }

        updatedChapters.add(updatedChapter);
      }

      if (hasUpdates) {
        updatedBook = updatedBook.copyWith(chapters: updatedChapters);
        
        try {
          await remoteDataSource.updateBook(book.id, updatedBook);
        } catch (e) {
          // Log but still return the updated book
        }
        
        return ApiResult.success(updatedBook);
      }

      return ApiResult.success(null);
    });
  }

  @override
  Future<ApiResult<bool>> verifyFileUrls(BookItem book) async {
    return handleRepositoryCall(() async {
      // Verify cover image
      if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
        final isWorking = await remoteDataSource.verifyUrlIsWorking(book.imageUrl!);
        if (!isWorking) {
          return ApiResult.success(false);
        }
      }

      // Verify chapter files
      for (final chapter in book.chapters) {
        // Verify chapter image
        if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
          final isWorking = await remoteDataSource.verifyUrlIsWorking(chapter.imageUrl!);
          if (!isWorking) {
            return ApiResult.success(false);
          }
        }

        // Verify PDF
        if (chapter.pdfUrl != null && chapter.pdfUrl!.isNotEmpty) {
          final isWorking = await remoteDataSource.verifyUrlIsWorking(chapter.pdfUrl!);
          if (!isWorking) {
            return ApiResult.success(false);
          }
        }

        // Verify audio tracks
        for (final audioTrack in chapter.audioTracks) {
          if (audioTrack.audioUrl != null && audioTrack.audioUrl!.isNotEmpty) {
            final isWorking = await remoteDataSource.verifyUrlIsWorking(audioTrack.audioUrl!);
            if (!isWorking) {
              return ApiResult.success(false);
            }
          }
        }
      }

      return ApiResult.success(true);
    });
  }

  @override
  Future<ApiResult<bool>> hasEditPermission(String bookId, String userId) async {
    try {
      if (await adminService.isUserAdmin(userId)) {
        return ApiResult.success(true);
      }
      
      return ApiResult.success(false);
    } catch (e) {
      return ApiResult.failure('Error checking edit permission: $e');
    }
  }
}