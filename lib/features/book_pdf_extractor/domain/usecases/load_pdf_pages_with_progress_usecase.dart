import 'dart:io';
import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';

class LoadPdfPagesWithProgressUseCase {
  final PdfExtractorRepository _repository;

  LoadPdfPagesWithProgressUseCase(this._repository);

  Stream<double> call(File pdfFile) {
    return _repository.loadPdfPagesWithProgress(pdfFile);
  }
}