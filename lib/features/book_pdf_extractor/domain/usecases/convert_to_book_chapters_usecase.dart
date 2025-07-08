import 'dart:io';
import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';

class ConvertToBookChaptersUseCase {
  final PdfExtractorRepository _repository;

  ConvertToBookChaptersUseCase(this._repository);

  Future<List<BookChapter>> call(List<ChapterInfo> chapterInfos, List<File> chapterPdfs) async {
    return await _repository.convertChaptersToBookChapters(chapterInfos, chapterPdfs);
  }
}