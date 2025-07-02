import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/features/test_results/domain/repositories/test_results_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class LoadUserTestResultsParams {
  final int limit;
  final bool cacheOnly;

  const LoadUserTestResultsParams({
    this.limit = 20,
    this.cacheOnly = false,
  });
}

class LoadUserTestResultsUseCase implements UseCase<List<TestResult>, LoadUserTestResultsParams> {
  final TestResultsRepository repository;
  final AuthService authService;

  LoadUserTestResultsUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<List<TestResult>>> execute(LoadUserTestResultsParams params) async {
    try {
      debugPrint('LoadUserTestResultsUseCase: Loading results with limit ${params.limit}');

      final user = authService.getCurrentUser();
      if (user == null) {
        return ApiResult.failure('User not authenticated', FailureType.auth);
      }

      if (params.limit <= 0 || params.limit > 100) {
        return ApiResult.failure('Limit must be between 1 and 100', FailureType.validation);
      }

      if (params.cacheOnly) {
        return await repository.getCachedUserResults(user.uid);
      }

      return await repository.getUserTestResults(user.uid, limit: params.limit);

    } catch (e) {
      debugPrint('LoadUserTestResultsUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load test results: $e', FailureType.unknown);
    }
  }
}