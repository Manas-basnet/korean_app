import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';

class CheckBookPermissionParams extends Equatable {
  final String bookId;
  final String? bookCreatorUid;

  const CheckBookPermissionParams({
    required this.bookId,
    this.bookCreatorUid,
  });

  @override
  List<Object?> get props => [bookId, bookCreatorUid];
}

class BookPermissionResult extends Equatable {
  final bool canEdit;
  final bool canDelete;
  final bool canView;
  final String reason;

  const BookPermissionResult({
    required this.canEdit,
    required this.canDelete,
    required this.canView,
    this.reason = '',
  });

  @override
  List<Object?> get props => [canEdit, canDelete, canView, reason];
}

class CheckBookEditPermissionUseCase implements UseCase<BookPermissionResult, CheckBookPermissionParams> {
  final AuthService authService;
  final AdminPermissionService adminPermissionService;

  CheckBookEditPermissionUseCase({
    required this.authService,
    required this.adminPermissionService,
  });

  @override
  Future<ApiResult<BookPermissionResult>> execute(CheckBookPermissionParams params) async {
    try {
      debugPrint('CheckBookEditPermissionUseCase: Checking permissions for book ${params.bookId}');

      final user = authService.getCurrentUser();
      if (user == null) {
        debugPrint('CheckBookEditPermissionUseCase: User not authenticated');
        return ApiResult.success(const BookPermissionResult(
          canEdit: false,
          canDelete: false,
          canView: true,
          reason: 'User not authenticated',
        ));
      }

      if (params.bookId.isEmpty) {
        return ApiResult.failure('Book ID cannot be empty', FailureType.validation);
      }

      bool isAdmin = false;
      try {
        isAdmin = await adminPermissionService.isUserAdmin(user.uid);
        if (isAdmin) {
          debugPrint('CheckBookEditPermissionUseCase: User is admin, granting full permissions');
          return ApiResult.success(const BookPermissionResult(
            canEdit: true,
            canDelete: true,
            canView: true,
            reason: 'User is admin',
          ));
        }
      } catch (e) {
        debugPrint('CheckBookEditPermissionUseCase: Error checking admin status - $e');
      }

      bool isOwner = false;
      if (params.bookCreatorUid != null && params.bookCreatorUid!.isNotEmpty) {
        isOwner = params.bookCreatorUid == user.uid;
      }

      if (isOwner) {
        debugPrint('CheckBookEditPermissionUseCase: User is book owner, granting edit permissions');
        return ApiResult.success(const BookPermissionResult(
          canEdit: true,
          canDelete: true,
          canView: true,
          reason: 'User is book owner',
        ));
      }

      debugPrint('CheckBookEditPermissionUseCase: Regular user, view-only permissions');
      return ApiResult.success(const BookPermissionResult(
        canEdit: false,
        canDelete: false,
        canView: true,
        reason: 'Regular user - view only',
      ));

    } catch (e) {
      debugPrint('CheckBookEditPermissionUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to check permissions: $e', FailureType.unknown);
    }
  }

  Future<bool> canEdit(String bookId, String? bookCreatorUid) async {
    final params = CheckBookPermissionParams(
      bookId: bookId,
      bookCreatorUid: bookCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canEdit,
      onFailure: (_, __) => false,
    );
  }

  Future<bool> canDelete(String bookId, String? bookCreatorUid) async {
    final params = CheckBookPermissionParams(
      bookId: bookId,
      bookCreatorUid: bookCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canDelete,
      onFailure: (_, __) => false,
    );
  }

  Future<bool> canView(String bookId, String? bookCreatorUid) async {
    final params = CheckBookPermissionParams(
      bookId: bookId,
      bookCreatorUid: bookCreatorUid,
    );

    final result = await execute(params);
    
    return result.fold(
      onSuccess: (permissionResult) => permissionResult.canView,
      onFailure: (_, __) => true,
    );
  }
}