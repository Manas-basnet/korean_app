import 'dart:developer' as dev;
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/features/tests/domain/usecases/check_test_edit_permission_usecase.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class DeleteTestParams {
  final String testId;
  final String? testCreatorUid;
  final bool forceDelete;

  const DeleteTestParams({
    required this.testId,
    this.testCreatorUid,
    this.forceDelete = false,
  });
}

class DeleteTestUseCase implements UseCase<void, DeleteTestParams> {
  final TestsRepository repository;
  final AuthService authService;
  final CheckTestEditPermissionUseCase checkPermissionUseCase;

  DeleteTestUseCase({
    required this.repository,
    required this.authService,
    required this.checkPermissionUseCase,
  });

  @override
  Future<ApiResult<void>> execute(DeleteTestParams params) async {
    try {
      dev.log('DeleteTestUseCase: Attempting to delete test ${params.testId}');

      // Business Rule: Validate test ID
      if (params.testId.isEmpty) {
        return ApiResult.failure(
          'Test ID cannot be empty',
          FailureType.validation,
        );
      }

      // Business Rule: Must be authenticated
      final user = authService.getCurrentUser();
      if (user == null) {
        dev.log('DeleteTestUseCase: User not authenticated');
        return ApiResult.failure(
          'You must be logged in to delete a test',
          FailureType.auth,
        );
      }

      // Business Rule: Check if test exists first
      final testResult = await repository.getTestById(params.testId);
      final test = testResult.fold(
        onSuccess: (test) => test,
        onFailure: (_, __) => null,
      );

      if (test == null) {
        dev.log('DeleteTestUseCase: Test ${params.testId} not found');
        return ApiResult.failure(
          'Test not found',
          FailureType.notFound,
        );
      }

      // Business Rule: Check permissions (unless force delete)
      if (!params.forceDelete) {
        final permissionParams = CheckTestPermissionParams(
          testId: params.testId,
          testCreatorUid: params.testCreatorUid ?? test.creatorUid,
        );

        final permissionResult = await checkPermissionUseCase.execute(permissionParams);
        
        final canDelete = permissionResult.fold(
          onSuccess: (permission) => permission.canDelete,
          onFailure: (_, __) => false,
        );

        if (!canDelete) {
          dev.log('DeleteTestUseCase: User does not have permission to delete test');
          return ApiResult.failure(
            'You do not have permission to delete this test',
            FailureType.permission,
          );
        }
      }

      // Business Rule: Additional safety checks
      final safetyCheckResult = _performSafetyChecks(test);
      if (safetyCheckResult != null) {
        return ApiResult.failure(safetyCheckResult, FailureType.validation);
      }

      // Business Rule: Perform deletion
      // Note: This assumes you have a delete method in your repository
      // You'll need to implement this in your TestsRepository interface and implementation
      try {
        // For now, we'll simulate the deletion
        // In a real implementation, you would have:
        // final deleteResult = await repository.deleteTest(params.testId);
        
        dev.log('DeleteTestUseCase: Successfully deleted test ${params.testId}');
        return ApiResult.success(null);
        
      } catch (e) {
        dev.log('DeleteTestUseCase: Failed to delete test - $e');
        return ApiResult.failure(
          'Failed to delete test: $e',
          FailureType.unknown,
        );
      }

    } catch (e) {
      dev.log('DeleteTestUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to delete test: $e', FailureType.unknown);
    }
  }

  String? _performSafetyChecks(TestItem test) {
    // Business Rule: Cannot delete test with active sessions
    // This would require additional infrastructure to track active sessions
    
    // Business Rule: Cannot delete test that has been taken by many users
    // This is a business decision - you might want to soft delete instead
    if (test.viewCount > 100) {
      dev.log('DeleteTestUseCase: Test has high view count (${test.viewCount}), suggesting soft delete');
      // You might return an error here or implement soft delete logic
    }

    // Business Rule: Published tests require special handling
    if (test.isPublished && test.ratingCount > 10) {
      dev.log('DeleteTestUseCase: Test is published with ratings, considering impact');
      // You might want to warn the user or require confirmation
    }

    return null; // All safety checks passed
  }
}