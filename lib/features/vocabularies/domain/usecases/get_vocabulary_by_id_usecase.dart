import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabularies/domain/repositories/vocabularies_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

class GetVocabularyByIdParams {
  final String vocabularyId;
  final bool recordView;

  const GetVocabularyByIdParams({
    required this.vocabularyId,
    this.recordView = false,
  });
}

class GetVocabularyByIdUseCase implements UseCase<VocabularyItem, GetVocabularyByIdParams> {
  final VocabulariesRepository repository;
  final AuthService authService;

  GetVocabularyByIdUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<VocabularyItem>> execute(GetVocabularyByIdParams params) async {
    try {
      debugPrint('GetVocabularyByIdUseCase: Loading vocabulary ${params.vocabularyId}');

      if (params.vocabularyId.isEmpty) {
        return ApiResult.failure(
          'Vocabulary ID cannot be empty',
          FailureType.validation,
        );
      }

      final result = await repository.getVocabularyById(params.vocabularyId);

      return result.fold(
        onSuccess: (vocabulary) async {
          if (vocabulary == null) {
            debugPrint('GetVocabularyByIdUseCase: Vocabulary ${params.vocabularyId} not found');
            return ApiResult.failure(
              'Vocabulary not found',
              FailureType.notFound,
            );
          }

          if (params.recordView) {
            final user = authService.getCurrentUser();
            if (user != null) {
              try {
                await repository.recordVocabularyView(params.vocabularyId, user.uid);
                debugPrint('GetVocabularyByIdUseCase: Recorded view for vocabulary ${params.vocabularyId}');
              } catch (e) {
                debugPrint('GetVocabularyByIdUseCase: Failed to record view - $e');
              }
            }
          }

          debugPrint('GetVocabularyByIdUseCase: Successfully loaded vocabulary ${vocabulary.title}');
          return ApiResult.success(vocabulary);
        },
        onFailure: (message, type) {
          debugPrint('GetVocabularyByIdUseCase: Failed to load vocabulary - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('GetVocabularyByIdUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load vocabulary: $e', FailureType.unknown);
    }
  }
}