// import 'dart:io';
// import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';
// import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';
// import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';
// import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/page_selection.dart';
// import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_manipulation_service.dart';
// import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_cache_service.dart';
// import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';

// class PdfExtractorRepositoryImpl implements PdfExtractorRepository {
//   final PdfManipulationService _pdfManipulationService;
//   final PdfCacheService _pdfCacheService;

//   PdfExtractorRepositoryImpl({
//     required PdfManipulationService pdfManipulationService,
//     required PdfCacheService pdfCacheService,
//   }) : _pdfManipulationService = pdfManipulationService,
//        _pdfCacheService = pdfCacheService;

//   @override
//   Future<List<PdfPageInfo>> loadPdfPages(File pdfFile) async {
//     final pdfId = _generatePdfId(pdfFile);
//     final pageCount = await _pdfManipulationService.getPdfPageCount(pdfFile);
    
//     if (pageCount == 0) {
//       throw Exception('Invalid PDF file or failed to read pages');
//     }

//     List<String> cachedPaths = [];
    
//     if (await _pdfCacheService.isCached(pdfId)) {
//       cachedPaths = await _pdfCacheService.getCachedThumbnailPaths(pdfId);
//     }

//     if (cachedPaths.length != pageCount) {
//       await _pdfCacheService.cachePdfThumbnailsStreaming(
//         pdfId,
//         _pdfManipulationService.generatePageThumbnailsStream(
//           pdfFile,
//           maxPages: pageCount,
//         ),
//       );
      
//       cachedPaths = await _pdfCacheService.getCachedThumbnailPaths(pdfId);
//     }
    
//     final pages = <PdfPageInfo>[];
//     for (int i = 0; i < pageCount; i++) {
//       final pageNumber = i + 1;
//       final thumbnailPath = i < cachedPaths.length ? cachedPaths[i] : null;
      
//       pages.add(PdfPageInfo(
//         pageNumber: pageNumber,
//         thumbnailPath: thumbnailPath,
//         width: 150,
//         height: 210,
//         selection: PageSelection(pageNumber: pageNumber),
//       ));
//     }

//     return pages;
//   }

//   @override
//   Future<List<File>> generateChapterPdfs(File sourcePdf, List<ChapterInfo> chapters) async {
//     final chapterFiles = <File>[];
    
//     final sortedChapters = List<ChapterInfo>.from(chapters)
//       ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));

//     for (final chapter in sortedChapters) {
//       final chapterFile = await _pdfManipulationService.extractPagesAsNewPdf(
//         sourcePdf: sourcePdf,
//         pageNumbers: chapter.pageNumbers,
//         outputFileName: 'chapter_${chapter.chapterNumber}_${DateTime.now().millisecondsSinceEpoch}',
//       );
      
//       chapterFiles.add(chapterFile);
//     }

//     return chapterFiles;
//   }

//   @override
//   Future<void> clearCache(String pdfId) async {
//     await _pdfCacheService.clearPdfCache(pdfId);
//   }

//   @override
//   Future<Map<String, dynamic>> getCacheStats() async {
//     return await _pdfCacheService.getCacheStats();
//   }

//   @override
//   Future<List<BookChapter>> convertChaptersToBookChapters(
//     List<ChapterInfo> chapterInfos, 
//     List<File> chapterPdfs
//   ) async {
//     final bookChapters = <BookChapter>[];
    
//     for (int i = 0; i < chapterInfos.length && i < chapterPdfs.length; i++) {
//       final chapterInfo = chapterInfos[i];
//       final pdfFile = chapterPdfs[i];
      
//       final bookChapter = BookChapter(
//         id: '${DateTime.now().millisecondsSinceEpoch}_$i',
//         title: chapterInfo.title,
//         description: chapterInfo.description ?? '',
//         pdfPath: pdfFile.path,
//         order: chapterInfo.chapterNumber - 1,
//         createdAt: DateTime.now(),
//         updatedAt: DateTime.now(),
//         metadata: {
//           'pageNumbers': chapterInfo.pageNumbers,
//           'duration': chapterInfo.duration,
//         },
//       );
      
//       bookChapters.add(bookChapter);
//     }
    
//     return bookChapters;
//   }

//   String _generatePdfId(File pdfFile) {
//     final stat = pdfFile.statSync();
//     return '${pdfFile.path.hashCode}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
//   }
// }