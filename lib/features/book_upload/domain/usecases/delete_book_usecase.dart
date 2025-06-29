import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class DeleteBookParams {
  final String bookId;

  const DeleteBookParams({
    required this.bookId,
  });
}

class DeleteBookUseCase extends UseCase<bool, DeleteBookParams> {
  final BookUploadRepository repository;
  final AuthService authService;

  DeleteBookUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<bool>> execute(DeleteBookParams params) async {
    final user = authService.getCurrentUser();
    if (user == null) {
      return ApiResult.failure(
        'User not authenticated',
        FailureType.auth,
      );
    }

    final permissionResult = await repository.hasDeletePermission(params.bookId, user.uid);
    if (permissionResult.isFailure || !(permissionResult.data ?? false)) {
      return ApiResult.failure(
        'You do not have permission to delete this book',
        FailureType.permission,
      );
    }

    return repository.deleteBook(params.bookId);
  }
}