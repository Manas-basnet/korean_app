import 'dart:io';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_question.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/test_upload/data/datasources/test_upload_remote_datasource.dart';
import 'package:korean_language_app/features/test_upload/domain/test_upload_repository.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

class TestUploadRepositoryImpl extends BaseRepository implements TestUploadRepository {
  final TestUploadRemoteDataSource remoteDataSource;
  final AdminPermissionService adminService;

  TestUploadRepositoryImpl({
    required this.remoteDataSource,
    required this.adminService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<TestItem>> createTest(TestItem test, {File? imageFile}) async {
    return handleRepositoryCall(() async {
      final createdTest = await remoteDataSource.uploadTest(test, imageFile: imageFile);
      return ApiResult.success(createdTest);
    });
  }

  @override
  Future<ApiResult<TestItem>> updateTest(String testId, TestItem updatedTest, {File? imageFile}) async {
    return handleRepositoryCall(() async {
      final updatedTestResult = await remoteDataSource.updateTest(testId, updatedTest, imageFile: imageFile);
      return ApiResult.success(updatedTestResult);
    });
  }

  @override
  Future<ApiResult<bool>> deleteTest(String testId) async {
    return handleRepositoryCall(() async {
      final success = await remoteDataSource.deleteTest(testId);
      if (!success) {
        throw Exception('Failed to delete test');
      }
      return ApiResult.success(true);
    });
  }

  @override
  Future<ApiResult<String?>> regenerateImageUrl(TestItem test) async {
    if (test.imagePath == null || test.imagePath!.isEmpty) {
      return ApiResult.success(null);
    }

    return handleRepositoryCall(() async {
      final newUrl = await remoteDataSource.regenerateUrlFromPath(test.imagePath!);
      
      if (newUrl != null && newUrl.isNotEmpty) {
        final updatedTest = test.copyWith(imageUrl: newUrl);
        
        try {
          await remoteDataSource.updateTest(test.id, updatedTest);
        } catch (e) {
          // Log but continue - we still return the regenerated URL
        }
      }
      
      return ApiResult.success(newUrl);
    });
  }

  @override
  Future<ApiResult<TestItem?>> regenerateAllImageUrls(TestItem test) async {
    return handleRepositoryCall(() async {
      var updatedTest = test;
      bool hasUpdates = false;

      if (test.imagePath != null && test.imagePath!.isNotEmpty) {
        final newCoverUrl = await remoteDataSource.regenerateUrlFromPath(test.imagePath!);
        if (newCoverUrl != null && newCoverUrl != test.imageUrl) {
          updatedTest = updatedTest.copyWith(imageUrl: newCoverUrl);
          hasUpdates = true;
        }
      }

      final updatedQuestions = <TestQuestion>[];
      for (final question in test.questions) {
        var updatedQuestion = question;
        bool questionHasUpdates = false;

        if (question.questionImagePath != null && question.questionImagePath!.isNotEmpty) {
          final newQuestionUrl = await remoteDataSource.regenerateUrlFromPath(question.questionImagePath!);
          if (newQuestionUrl != null && newQuestionUrl != question.questionImageUrl) {
            updatedQuestion = updatedQuestion.copyWith(questionImageUrl: newQuestionUrl);
            questionHasUpdates = true;
            hasUpdates = true;
          }
        }

        if (question.questionAudioPath != null && question.questionAudioPath!.isNotEmpty) {
          final newQuestionAudioUrl = await remoteDataSource.regenerateUrlFromPath(question.questionAudioPath!);
          if (newQuestionAudioUrl != null && newQuestionAudioUrl != question.questionAudioUrl) {
            updatedQuestion = updatedQuestion.copyWith(questionAudioUrl: newQuestionAudioUrl);
            questionHasUpdates = true;
            hasUpdates = true;
          }
        }

        final updatedOptions = <AnswerOption>[];
        for (final option in question.options) {
          var updatedOption = option;
          
          if (option.isImage && option.imagePath != null && option.imagePath!.isNotEmpty) {
            final newAnswerUrl = await remoteDataSource.regenerateUrlFromPath(option.imagePath!);
            if (newAnswerUrl != null && newAnswerUrl != option.imageUrl) {
              updatedOption = option.copyWith(imageUrl: newAnswerUrl);
              questionHasUpdates = true;
              hasUpdates = true;
            }
          }
          
          if (option.isAudio && option.audioPath != null && option.audioPath!.isNotEmpty) {
            final newAnswerAudioUrl = await remoteDataSource.regenerateUrlFromPath(option.audioPath!);
            if (newAnswerAudioUrl != null && newAnswerAudioUrl != option.audioUrl) {
              updatedOption = updatedOption.copyWith(audioUrl: newAnswerAudioUrl);
              questionHasUpdates = true;
              hasUpdates = true;
            }
          }
          
          updatedOptions.add(updatedOption);
        }

        if (questionHasUpdates) {
          updatedQuestion = updatedQuestion.copyWith(options: updatedOptions);
        }

        updatedQuestions.add(updatedQuestion);
      }

      if (hasUpdates) {
        updatedTest = updatedTest.copyWith(questions: updatedQuestions);
        
        try {
          await remoteDataSource.updateTest(test.id, updatedTest);
        } catch (e) {
          // Log but still return the updated test
        }
        
        return ApiResult.success(updatedTest);
      }

      return ApiResult.success(null);
    });
  }

  @override
  Future<ApiResult<bool>> verifyImageUrls(TestItem test) async {
    return handleRepositoryCall(() async {
      if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
        final isWorking = await remoteDataSource.verifyUrlIsWorking(test.imageUrl!);
        if (!isWorking) {
          return ApiResult.success(false);
        }
      }

      for (final question in test.questions) {
        if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
          final isWorking = await remoteDataSource.verifyUrlIsWorking(question.questionImageUrl!);
          if (!isWorking) {
            return ApiResult.success(false);
          }
        }

        if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
          final isWorking = await remoteDataSource.verifyUrlIsWorking(question.questionAudioUrl!);
          if (!isWorking) {
            return ApiResult.success(false);
          }
        }

        for (final option in question.options) {
          if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
            final isWorking = await remoteDataSource.verifyUrlIsWorking(option.imageUrl!);
            if (!isWorking) {
              return ApiResult.success(false);
            }
          }
          
          if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
            final isWorking = await remoteDataSource.verifyUrlIsWorking(option.audioUrl!);
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
  Future<ApiResult<bool>> hasEditPermission(String testId, String userId) async {
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