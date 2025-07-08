import 'dart:io';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';

abstract class PdfExtractorRepository {
  Future<List<PdfPageInfo>> loadPdfPages(File pdfFile);
  Stream<double> loadPdfPagesWithProgress(File pdfFile);
  Future<List<File>> generateChapterPdfs(File sourcePdf, List<ChapterInfo> chapters);
  Future<void> clearCache(String pdfId);
  Future<void> clearAllCache();
  Future<Map<String, dynamic>> getCacheStats();
  Future<List<BookChapter>> convertChaptersToBookChapters(
    List<ChapterInfo> chapterInfos, 
    List<File> chapterPdfs
  );
}