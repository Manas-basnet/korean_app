
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';

class PickPDFResults {
  PickPDFResults({required this.pdfFile});
  File pdfFile;
}

class PickPDFUseCase implements UseCaseNoParams<PickPDFResults> {

  @override
  Future<ApiResult<PickPDFResults>> execute() async {
    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if(pickedFile != null && pickedFile.files.isNotEmpty && pickedFile.files.first.path != null) {

      final pdfFile = File(pickedFile.files.first.path!);
      if (await _isPdfValid(pdfFile)) {
        return ApiResult.success(PickPDFResults(pdfFile: pdfFile));
      } else {
        return ApiResult.failure('The selected PDF file appears to be invalid or corrupted.', FailureType.validation);
      }

    } else {

      return ApiResult.failure('PDF file not selected', FailureType.notFound);

    }
  } 

  Future<bool> _isPdfValid(File pdfFile) async {
    try {
      final fileSize = await pdfFile.length();
      if (fileSize > 50 * 1024 * 1024 || fileSize < 100) {
        return false;
      }
      
      final bytes = await pdfFile.openRead(0, 5).toList();
      final data = bytes.expand((x) => x).toList();
      
      return data.length >= 5 && String.fromCharCodes(data.sublist(0, 5)) == '%PDF-';
    } catch (e) {
      return false;
    }
  }

}