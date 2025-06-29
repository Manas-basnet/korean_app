import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';


class PickImageResult {
  PickImageResult({required this.file});
  final File file;
}


class PickImageUseCase extends UseCaseNoParams<PickImageResult>{
  @override
  Future<ApiResult<PickImageResult>> execute() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if(result != null && result.files.isNotEmpty && result.files.first.path != null) {

      final imageFile = File(result.files.first.path!);

      if(await _isImageValid(imageFile)) {
        return ApiResult.success(PickImageResult(file: imageFile));
      } else {
        return ApiResult.failure('The selected image appears to be invalid.', FailureType.validation);
      }

    } else {
      return ApiResult.failure('No image selected', FailureType.notFound);
    }


  }

  Future<bool> _isImageValid(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      return fileSize <= 10 * 1024 * 1024 && fileSize >= 10;
    } catch (e) {
      return false;
    }
  }

}