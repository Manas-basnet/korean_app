import 'dart:io';
import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';

class GenerateChapterPdfsUseCase {
  final PdfExtractorRepository _repository;

  GenerateChapterPdfsUseCase(this._repository);

  Future<List<File>> call(File sourcePdf, List<ChapterInfo> chapters) async {
    return await _repository.generateChapterPdfs(sourcePdf, chapters);
  }
}