import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/shared/models/test_item.dart';

class GetTestByIdParams {
  final String testId;
  final bool recordView;

  const GetTestByIdParams({
    required this.testId,
    this.recordView = false,
  });
}

class GetTestByIdUseCase implements UseCase<TestItem, GetTestByIdParams> {
  final TestsRepository repository;
  final AuthService authService;

  GetTestByIdUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<TestItem>> execute(GetTestByIdParams params) async {
    try {
      debugPrint('GetTestByIdUseCase: Loading test ${params.testId}');

      // Business Rule: Validate test ID
      if (params.testId.isEmpty) {
        return ApiResult.failure(
          'Test ID cannot be empty',
          FailureType.validation,
        );
      }

      // Business Rule: Load test
      final result = await repository.getTestById(params.testId);

      return result.fold(
        onSuccess: (test) async {
          if (test == null) {
            debugPrint('GetTestByIdUseCase: Test ${params.testId} not found');
            return ApiResult.failure(
              'Test not found',
              FailureType.notFound,
            );
          }

          // Business Rule: Record view if requested and user is authenticated
          if (params.recordView) {
            final user = authService.getCurrentUser();
            if (user != null) {
              try {
                await repository.recordTestView(params.testId, user.uid);
                debugPrint('GetTestByIdUseCase: Recorded view for test ${params.testId}');
              } catch (e) {
                debugPrint('GetTestByIdUseCase: Failed to record view - $e');
                // Continue anyway - this is not critical
              }
            }
          }

          debugPrint('GetTestByIdUseCase: Successfully loaded test ${test.title}');
          return ApiResult.success(test);
        },
        onFailure: (message, type) {
          debugPrint('GetTestByIdUseCase: Failed to load test - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('GetTestByIdUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load test: $e', FailureType.unknown);
    }
  }
}