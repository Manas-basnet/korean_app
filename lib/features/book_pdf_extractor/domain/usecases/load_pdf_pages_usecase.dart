import 'dart:io';
import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';

class LoadPdfPagesUseCase {
  final PdfExtractorRepository _repository;

  LoadPdfPagesUseCase(this._repository);

  Future<List<PdfPageInfo>> call(File pdfFile) async {
    return await _repository.loadPdfPages(pdfFile);
  }
}