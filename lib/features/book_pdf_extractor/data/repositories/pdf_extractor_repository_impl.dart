import 'dart:io';
import 'dart:typed_data';
import 'package:korean_language_app/features/book_pdf_extractor/domain/repositories/pdf_extractor_repository.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/page_selection.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_manipulation_service.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_cache_service.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';

class PdfExtractorRepositoryImpl implements PdfExtractorRepository {
  final PdfManipulationService _pdfManipulationService;
  final PdfCacheService _pdfCacheService;

  PdfExtractorRepositoryImpl({
    required PdfManipulationService pdfManipulationService,
    required PdfCacheService pdfCacheService,
  }) : _pdfManipulationService = pdfManipulationService,
       _pdfCacheService = pdfCacheService;

  @override
  Stream<double> loadPdfPagesWithProgress(File pdfFile) async* {
    final pdfId = _generatePdfId(pdfFile);
    yield 0.1;
    
    final pageCount = await _pdfManipulationService.getPdfPageCount(pdfFile);
    
    if (pageCount == 0) {
      throw Exception('Invalid PDF file or failed to read pages');
    }

    yield 0.2;

    List<String> cachedPaths = [];
    
    if (await _pdfCacheService.isCached(pdfId)) {
      cachedPaths = await _pdfCacheService.getCachedThumbnailPaths(pdfId);
      yield 0.3;
    }

    if (cachedPaths.length != pageCount) {
      yield 0.4;
      
      int processedPages = 0;
      final List<Uint8List> thumbnails = [];
      
      await for (final thumbnailBytes in _pdfManipulationService.generatePageThumbnailsStream(
        pdfFile,
        maxPages: pageCount,
      )) {
        processedPages++;
        thumbnails.add(thumbnailBytes);
        
        final thumbnailProgress = processedPages / pageCount;
        final overallProgress = 0.4 + (thumbnailProgress * 0.5);
        yield overallProgress;
        
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      await _pdfCacheService.cachePdfThumbnails(pdfId, thumbnails);
      
      yield 0.95;
    } else {
      yield 0.8;
    }
    
    yield 1.0;
  }

  @override
  Future<List<PdfPageInfo>> loadPdfPages(File pdfFile) async {
    final pdfId = _generatePdfId(pdfFile);
    final pageCount = await _pdfManipulationService.getPdfPageCount(pdfFile);
    
    if (pageCount == 0) {
      throw Exception('Invalid PDF file or failed to read pages');
    }

    List<String> cachedPaths = [];
    
    if (await _pdfCacheService.isCached(pdfId)) {
      cachedPaths = await _pdfCacheService.getCachedThumbnailPaths(pdfId);
    }

    if (cachedPaths.length != pageCount) {
      await _pdfCacheService.cachePdfThumbnailsStreaming(
        pdfId,
        _pdfManipulationService.generatePageThumbnailsStream(
          pdfFile,
          maxPages: pageCount,
        ),
      );
      
      cachedPaths = await _pdfCacheService.getCachedThumbnailPaths(pdfId);
    }
    
    final pages = <PdfPageInfo>[];
    for (int i = 0; i < pageCount; i++) {
      final pageNumber = i + 1;
      final thumbnailPath = i < cachedPaths.length ? cachedPaths[i] : null;
      
      pages.add(PdfPageInfo(
        pageNumber: pageNumber,
        thumbnailPath: thumbnailPath,
        width: 150,
        height: 210,
        selection: PageSelection(pageNumber: pageNumber),
      ));
    }

    return pages;
  }

  @override
  Future<List<File>> generateChapterPdfs(File sourcePdf, List<ChapterInfo> chapters) async {
    final chapterFiles = <File>[];
    
    final sortedChapters = List<ChapterInfo>.from(chapters)
      ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));

    for (final chapter in sortedChapters) {
      final chapterFile = await _pdfManipulationService.extractPagesAsNewPdf(
        sourcePdf: sourcePdf,
        pageNumbers: chapter.pageNumbers,
        outputFileName: 'chapter_${chapter.chapterNumber}_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      chapterFiles.add(chapterFile);
    }

    return chapterFiles;
  }

  @override
  Future<void> clearCache(String pdfId) async {
    await _pdfCacheService.clearPdfCache(pdfId);
  }

  @override
  Future<void> clearAllCache() async {
    await _pdfCacheService.clearAllCache();
  }

  @override
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _pdfCacheService.getCacheStats();
  }

  @override
  Future<List<BookChapter>> convertChaptersToBookChapters(
    List<ChapterInfo> chapterInfos, 
    List<File> chapterPdfs
  ) async {
    final bookChapters = <BookChapter>[];
    
    for (int i = 0; i < chapterInfos.length && i < chapterPdfs.length; i++) {
      final chapterInfo = chapterInfos[i];
      final pdfFile = chapterPdfs[i];
      
      final bookChapter = BookChapter(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        title: chapterInfo.title,
        description: chapterInfo.description ?? '',
        pdfPath: pdfFile.path,
        order: chapterInfo.chapterNumber - 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          'pageNumbers': chapterInfo.pageNumbers,
          'duration': chapterInfo.duration,
          'originalPdfPath': pdfFile.path,
        },
      );
      
      bookChapters.add(bookChapter);
    }
    
    return bookChapters;
  }

  String _generatePdfId(File pdfFile) {
    final stat = pdfFile.statSync();
    return '${pdfFile.path.hashCode}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
  }
}