import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/features/test_results/domain/repositories/test_results_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class SaveTestResultUseCase implements UseCase<bool, TestResult> {
  final TestResultsRepository repository;
  final AuthService authService;

  SaveTestResultUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<bool>> execute(TestResult result) async {
    try {
      debugPrint('SaveTestResultUseCase: Saving test result for ${result.testTitle}');

      final user = authService.getCurrentUser();
      if (user == null) {
        return ApiResult.failure('User not authenticated', FailureType.auth);
      }

      if (result.userId != user.uid) {
        return ApiResult.failure('User ID mismatch', FailureType.auth);
      }

      if (result.testId.isEmpty) {
        return ApiResult.failure('Test ID cannot be empty', FailureType.validation);
      }

      if (result.totalQuestions <= 0) {
        return ApiResult.failure('Invalid test data', FailureType.validation);
      }

      final validatedResult = result.copyWith(
        userId: user.uid,
        completedAt: result.completedAt.isAfter(DateTime.now()) 
            ? DateTime.now() 
            : result.completedAt,
      );

      return await repository.saveTestResult(validatedResult);

    } catch (e) {
      debugPrint('SaveTestResultUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to save test result: $e', FailureType.unknown);
    }
  }
}
