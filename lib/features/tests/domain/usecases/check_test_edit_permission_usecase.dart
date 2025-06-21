import 'dart:developer' as dev;
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_results.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';

class CheckTestEditPermissionUseCase implements UseCase<TestPermissionResult, CheckTestPermissionParams> {
  final AuthService authService;
  final AdminPermissionService adminPermissionService;

  CheckTestEditPermissionUseCase({
    required this.authService,
    required this.adminPermissionService,
  });

  @override
  Future<ApiResult<TestPermissionResult>> execute(CheckTestPermissionParams params) async {
    try {
      dev.log('CheckTestEditPermissionUseCase: Checking permissions for test ${params.testId}');

      // Business Rule: Must be authenticated to have any permissions
      final user = authService.getCurrentUser();
      if (user == null) {
        dev.log('CheckTestEditPermissionUseCase: User not authenticated');
        return ApiResult.success(const TestPermissionResult(
          canEdit: false,
          canDelete: false,
          canView: true, // Anonymous users can view public tests
          reason: 'User not authenticated',
        ));
      }

      // Business Rule: Validate test ID
      if (params.testId.isEmpty) {
        return ApiResult.failure('Test ID cannot be empty', FailureType.validation);
      }

      // Business Rule: Check admin permissions first
      bool isAdmin = false;
      try {
        isAdmin = await adminPermissionService.isUserAdmin(user.uid);
        if (isAdmin) {
          dev.log('CheckTestEditPermissionUseCase: User is admin, granting full permissions');
          return ApiResult.success(const TestPermissionResult(
            canEdit: true,
            canDelete: true,
            canView: true,
            reason: 'User is admin',
          ));
        }
      } catch (e) {
        dev.log('CheckTestEditPermissionUseCase: Error checking admin status - $e');
        // Continue with regular permission check
      }

      // Business Rule: Check ownership
      bool isOwner = false;
      if (params.testCreatorUid != null && params.testCreatorUid!.isNotEmpty) {
        isOwner = params.testCreatorUid == user.uid;
      }

      if (isOwner) {
        dev.log('CheckTestEditPermissionUseCase: User is test owner, granting edit permissions');
        return ApiResult.success(const TestPermissionResult(
          canEdit: true,
          canDelete: true,
          canView: true,
          reason: 'User is test owner',
        ));
      }

      // Business Rule: Regular user - can only view
      dev.log('CheckTestEditPermissionUseCase: Regular user, view-only permissions');
      return ApiResult.success(const TestPermissionResult(
        canEdit: false,
        canDelete: false,
        canView: true,
        reason: 'Regular user - view only',
      ));

    } catch (e) {
      dev.log('CheckTestEditPermissionUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to check permissions: $e', FailureType.unknown);
    }
  }
}

// // Alternative simplified version for backward compatibility
class CheckTestEditPermissionSimpleUseCase {
  final AuthService authService;
  final AdminPermissionService adminPermissionService;

  CheckTestEditPermissionSimpleUseCase({
    required this.authService,
    required this.adminPermissionService
  });

  Future<bool> execute(String testId, String? testCreatorUid) async {
    final params = CheckTestPermissionParams(
      testId: testId,
      testCreatorUid: testCreatorUid,
    );

    final useCase = CheckTestEditPermissionUseCase(
      authService: authService,
      adminPermissionService: adminPermissionService,
    );

    final result = await useCase.execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canEdit,
      onFailure: (_, __) => false,
    );
  }
}