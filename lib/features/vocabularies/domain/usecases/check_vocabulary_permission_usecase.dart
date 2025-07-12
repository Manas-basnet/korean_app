import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';

class CheckVocabularyPermissionParams extends Equatable {
  final String vocabularyId;
  final String? vocabularyCreatorUid;

  const CheckVocabularyPermissionParams({
    required this.vocabularyId,
    this.vocabularyCreatorUid,
  });

  @override
  List<Object?> get props => [vocabularyId, vocabularyCreatorUid];
}

class VocabularyPermissionResult extends Equatable {
  final bool canEdit;
  final bool canDelete;
  final bool canView;
  final String reason;

  const VocabularyPermissionResult({
    required this.canEdit,
    required this.canDelete,
    required this.canView,
    this.reason = '',
  });

  @override
  List<Object?> get props => [canEdit, canDelete, canView, reason];
}

class CheckVocabularyEditPermissionUseCase implements UseCase<VocabularyPermissionResult, CheckVocabularyPermissionParams> {
  final AuthService authService;
  final AdminPermissionService adminPermissionService;

  CheckVocabularyEditPermissionUseCase({
    required this.authService,
    required this.adminPermissionService,
  });

  @override
  Future<ApiResult<VocabularyPermissionResult>> execute(CheckVocabularyPermissionParams params) async {
    try {
      debugPrint('CheckVocabularyEditPermissionUseCase: Checking permissions for vocabulary ${params.vocabularyId}');

      final user = authService.getCurrentUser();
      if (user == null) {
        debugPrint('CheckVocabularyEditPermissionUseCase: User not authenticated');
        return ApiResult.success(const VocabularyPermissionResult(
          canEdit: false,
          canDelete: false,
          canView: true,
          reason: 'User not authenticated',
        ));
      }

      if (params.vocabularyId.isEmpty) {
        return ApiResult.failure('Vocabulary ID cannot be empty', FailureType.validation);
      }

      bool isAdmin = false;
      try {
        isAdmin = await adminPermissionService.isUserAdmin(user.uid);
        if (isAdmin) {
          debugPrint('CheckVocabularyEditPermissionUseCase: User is admin, granting full permissions');
          return ApiResult.success(const VocabularyPermissionResult(
            canEdit: true,
            canDelete: true,
            canView: true,
            reason: 'User is admin',
          ));
        }
      } catch (e) {
        debugPrint('CheckVocabularyEditPermissionUseCase: Error checking admin status - $e');
      }

      bool isOwner = false;
      if (params.vocabularyCreatorUid != null && params.vocabularyCreatorUid!.isNotEmpty) {
        isOwner = params.vocabularyCreatorUid == user.uid;
      }

      if (isOwner) {
        debugPrint('CheckVocabularyEditPermissionUseCase: User is vocabulary owner, granting edit permissions');
        return ApiResult.success(const VocabularyPermissionResult(
          canEdit: true,
          canDelete: true,
          canView: true,
          reason: 'User is vocabulary owner',
        ));
      }

      debugPrint('CheckVocabularyEditPermissionUseCase: Regular user, view-only permissions');
      return ApiResult.success(const VocabularyPermissionResult(
        canEdit: false,
        canDelete: false,
        canView: true,
        reason: 'Regular user - view only',
      ));

    } catch (e) {
      debugPrint('CheckVocabularyEditPermissionUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to check permissions: $e', FailureType.unknown);
    }
  }

  Future<bool> canEdit(String vocabularyId, String? vocabularyCreatorUid) async {
    final params = CheckVocabularyPermissionParams(
      vocabularyId: vocabularyId,
      vocabularyCreatorUid: vocabularyCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canEdit,
      onFailure: (_, __) => false,
    );
  }

  Future<bool> canDelete(String vocabularyId, String? vocabularyCreatorUid) async {
    final params = CheckVocabularyPermissionParams(
      vocabularyId: vocabularyId,
      vocabularyCreatorUid: vocabularyCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canDelete,
      onFailure: (_, __) => false,
    );
  }

  Future<bool> canView(String vocabularyId, String? vocabularyCreatorUid) async {
    final params = CheckVocabularyPermissionParams(
      vocabularyId: vocabularyId,
      vocabularyCreatorUid: vocabularyCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canView,
      onFailure: (_, __) => true,
    );
  }
}