import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabularies/domain/repositories/vocabularies_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class RateVocabularyParams {
  final String vocabularyId;
  final double rating;

  const RateVocabularyParams({
    required this.vocabularyId,
    required this.rating,
  });
}

class RateVocabularyUseCase implements UseCase<void, RateVocabularyParams> {
  final VocabulariesRepository repository;
  final AuthService authService;

  RateVocabularyUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<void>> execute(RateVocabularyParams params) async {
    try {
      debugPrint('RateVocabularyUseCase: Rating vocabulary ${params.vocabularyId} with ${params.rating} stars');

      if (params.vocabularyId.isEmpty) {
        return ApiResult.failure(
          'Vocabulary ID cannot be empty',
          FailureType.validation,
        );
      }

      if (params.rating < 1.0 || params.rating > 5.0) {
        return ApiResult.failure(
          'Rating must be between 1.0 and 5.0',
          FailureType.validation,
        );
      }

      final user = authService.getCurrentUser();
      if (user == null) {
        return ApiResult.failure(
          'User must be authenticated to rate vocabulary',
          FailureType.auth,
        );
      }

      final result = await repository.rateVocabulary(
        params.vocabularyId,
        user.uid,
        params.rating,
      );

      return result.fold(
        onSuccess: (_) {
          debugPrint('RateVocabularyUseCase: Successfully rated vocabulary ${params.vocabularyId}');
          return ApiResult.success(null);
        },
        onFailure: (message, type) {
          debugPrint('RateVocabularyUseCase: Failed to rate vocabulary - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('RateVocabularyUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to rate vocabulary: $e', FailureType.unknown);
    }
  }
}