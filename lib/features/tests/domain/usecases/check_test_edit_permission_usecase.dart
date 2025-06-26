import 'package:flutter/foundation.dart';
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
      debugPrint('CheckTestEditPermissionUseCase: Checking permissions for test ${params.testId}');

      final user = authService.getCurrentUser();
      if (user == null) {
        debugPrint('CheckTestEditPermissionUseCase: User not authenticated');
        return ApiResult.success(const TestPermissionResult(
          canEdit: false,
          canDelete: false,
          canView: true,
          reason: 'User not authenticated',
        ));
      }

      if (params.testId.isEmpty) {
        return ApiResult.failure('Test ID cannot be empty', FailureType.validation);
      }

      bool isAdmin = false;
      try {
        isAdmin = await adminPermissionService.isUserAdmin(user.uid);
        if (isAdmin) {
          debugPrint('CheckTestEditPermissionUseCase: User is admin, granting full permissions');
          return ApiResult.success(const TestPermissionResult(
            canEdit: true,
            canDelete: true,
            canView: true,
            reason: 'User is admin',
          ));
        }
      } catch (e) {
        debugPrint('CheckTestEditPermissionUseCase: Error checking admin status - $e');
      }

      bool isOwner = false;
      if (params.testCreatorUid != null && params.testCreatorUid!.isNotEmpty) {
        isOwner = params.testCreatorUid == user.uid;
      }

      if (isOwner) {
        debugPrint('CheckTestEditPermissionUseCase: User is test owner, granting edit permissions');
        return ApiResult.success(const TestPermissionResult(
          canEdit: true,
          canDelete: true,
          canView: true,
          reason: 'User is test owner',
        ));
      }

      debugPrint('CheckTestEditPermissionUseCase: Regular user, view-only permissions');
      return ApiResult.success(const TestPermissionResult(
        canEdit: false,
        canDelete: false,
        canView: true,
        reason: 'Regular user - view only',
      ));

    } catch (e) {
      debugPrint('CheckTestEditPermissionUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to check permissions: $e', FailureType.unknown);
    }
  }

  Future<bool> canEdit(String testId, String? testCreatorUid) async {
    final params = CheckTestPermissionParams(
      testId: testId,
      testCreatorUid: testCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canEdit,
      onFailure: (_, __) => false,
    );
  }

  Future<bool> canDelete(String testId, String? testCreatorUid) async {
    final params = CheckTestPermissionParams(
      testId: testId,
      testCreatorUid: testCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canDelete,
      onFailure: (_, __) => false,
    );
  }

  Future<bool> canView(String testId, String? testCreatorUid) async {
    final params = CheckTestPermissionParams(
      testId: testId,
      testCreatorUid: testCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canView,
      onFailure: (_, __) => true,
    );
  }
}