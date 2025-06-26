import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/test_result.dart';
import 'package:korean_language_app/features/test_results/domain/repositories/test_results_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class GetUserLatestResultParams {
  final String testId;

  const GetUserLatestResultParams({required this.testId});
}

class GetUserLatestResultUseCase implements UseCase<TestResult?, GetUserLatestResultParams> {
  final TestResultsRepository repository;
  final AuthService authService;

  GetUserLatestResultUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<TestResult?>> execute(GetUserLatestResultParams params) async {
    try {
      debugPrint('GetUserLatestResultUseCase: Getting latest result for test ${params.testId}');

      final user = authService.getCurrentUser();
      if (user == null) {
        return ApiResult.failure('User not authenticated', FailureType.auth);
      }

      if (params.testId.isEmpty) {
        return ApiResult.failure('Test ID cannot be empty', FailureType.validation);
      }

      return await repository.getUserLatestResult(user.uid, params.testId);

    } catch (e) {
      debugPrint('GetUserLatestResultUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to get latest result: $e', FailureType.unknown);
    }
  }
}