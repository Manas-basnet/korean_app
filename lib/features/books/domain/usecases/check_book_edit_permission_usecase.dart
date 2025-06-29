import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/shared/models/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class CheckBookEditPermissionParams {
  final String bookId;
  final BookItem? book;

  const CheckBookEditPermissionParams({
    required this.bookId,
    this.book,
  });
}

class CheckBookEditPermissionUseCase extends UseCase<bool, CheckBookEditPermissionParams> {
  final AuthService authService;
  final AdminPermissionService adminService;

  CheckBookEditPermissionUseCase({
    required this.authService,
    required this.adminService,
  });

  @override
  Future<ApiResult<bool>> execute(CheckBookEditPermissionParams params) async {
    try {
      final user = authService.getCurrentUser();
      if (user == null) {
        return ApiResult.success(false);
      }

      final isAdmin = await adminService.isUserAdmin(user.uid);
      if (isAdmin) {
        return ApiResult.success(true);
      }

      if (params.book != null) {
        final canEdit = params.book!.creatorUid == user.uid;
        return ApiResult.success(canEdit);
      }

      return ApiResult.success(false);
    } catch (e) {
      return ApiResult.failure(
        'Failed to check edit permission: $e',
        FailureType.unknown,
      );
    }
  }
}