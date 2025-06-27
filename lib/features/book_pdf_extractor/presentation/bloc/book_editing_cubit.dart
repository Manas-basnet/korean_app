import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_cache_service.dart';
import 'package:korean_language_app/features/book_pdf_extractor/data/services/pdf_manipulation_service.dart';
import 'package:korean_language_app/shared/models/chapter_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/page_selection.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';

part 'book_editing_state.dart';

class BookEditingCubit extends Cubit<BookEditingState> {
  final PdfManipulationService _pdfManipulationService;
  final PdfCacheService _pdfCacheService;

  BookEditingCubit({
    required PdfManipulationService pdfManipulationService,
    required PdfCacheService pdfCacheService,
  }) : _pdfManipulationService = pdfManipulationService,
       _pdfCacheService = pdfCacheService,
       super(BookEditingInitial());

  Future<void> loadPdfForEditing(File pdfFile) async {
    try {
      emit(BookEditingLoading(message: 'Loading PDF...', progress: 0.1));

      final pdfId = DateTime.now().millisecondsSinceEpoch.toString();
      
      emit(BookEditingLoading(message: 'Getting page count...', progress: 0.2));
      final pageCount = await _pdfManipulationService.getPdfPageCount(pdfFile);
      
      if (pageCount == 0) {
        emit(BookEditingError('Invalid PDF file or failed to read pages'));
        return;
      }

      emit(BookEditingLoading(message: 'Generating thumbnails...', progress: 0.3));
      final thumbnails = await _pdfManipulationService.generatePageThumbnails(pdfFile);
      
      emit(BookEditingLoading(message: 'Caching thumbnails...', progress: 0.7));
      await _pdfCacheService.cachePdfThumbnails(pdfId, thumbnails);
      
      emit(BookEditingLoading(message: 'Preparing pages...', progress: 0.9));
      final cachedPaths = await _pdfCacheService.getCachedThumbnailPaths(pdfId);
      
      final pages = <PdfPageInfo>[];
      for (int i = 0; i < pageCount; i++) {
        final pageNumber = i + 1;
        final thumbnailPath = i < cachedPaths.length ? cachedPaths[i] : null;
        
        pages.add(PdfPageInfo(
          pageNumber: pageNumber,
          thumbnailPath: thumbnailPath,
          width: 200,
          height: 280,
          selection: PageSelection(pageNumber: pageNumber),
        ));
      }

      emit(BookEditingLoaded(
        sourcePdf: pdfFile,
        pdfId: pdfId,
        pages: pages,
        chapters: const [],
        selectedPageNumbers: const [],
      ));

    } catch (e) {
      emit(BookEditingError('Failed to load PDF: $e'));
    }
  }

  void startPageSelectionWithDetails({
    required int chapterNumber,
    required String title,
    String? description,
    String? duration,
  }) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final existingChapter = currentState.chapters.firstWhere(
        (c) => c.chapterNumber == chapterNumber,
        orElse: () => ChapterInfo(
          chapterNumber: chapterNumber,
          title: title,
          description: description,
          pageNumbers: const [],
          duration: duration,
        ),
      );

      emit(currentState.copyWith(
        isSelectionMode: true,
        currentChapterForSelection: chapterNumber,
        selectedPageNumbers: List<int>.from(existingChapter.pageNumbers),
        pendingChapterTitle: title,
        pendingChapterDescription: description,
        pendingChapterDuration: duration,
      ));
    }
  }

  void startPageSelection(int chapterNumber) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final existingChapter = currentState.chapters.firstWhere(
        (c) => c.chapterNumber == chapterNumber,
        orElse: () => ChapterInfo(
          chapterNumber: chapterNumber,
          title: 'Chapter $chapterNumber',
          pageNumbers: const [],
        ),
      );

      emit(currentState.copyWith(
        isSelectionMode: true,
        currentChapterForSelection: chapterNumber,
        selectedPageNumbers: List<int>.from(existingChapter.pageNumbers),
        pendingChapterTitle: existingChapter.title,
        pendingChapterDescription: existingChapter.description,
        pendingChapterDuration: existingChapter.duration,
      ));
    }
  }

  void togglePageSelection(int pageNumber) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final updatedSelection = List<int>.from(currentState.selectedPageNumbers);
      
      if (updatedSelection.contains(pageNumber)) {
        updatedSelection.remove(pageNumber);
      } else {
        if (currentState.getPageChapterNumber(pageNumber) == null || 
            currentState.getPageChapterNumber(pageNumber) == currentState.currentChapterForSelection) {
          updatedSelection.add(pageNumber);
        }
      }
      
      emit(currentState.copyWith(selectedPageNumbers: updatedSelection));
    }
  }

  void selectPageRange(int startPage, int endPage) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final updatedSelection = List<int>.from(currentState.selectedPageNumbers);
      
      final start = startPage < endPage ? startPage : endPage;
      final end = startPage < endPage ? endPage : startPage;
      
      for (int i = start; i <= end; i++) {
        final pageChapter = currentState.getPageChapterNumber(i);
        if ((pageChapter == null || pageChapter == currentState.currentChapterForSelection) && 
            !updatedSelection.contains(i)) {
          updatedSelection.add(i);
        }
      }
      
      emit(currentState.copyWith(selectedPageNumbers: updatedSelection));
    }
  }

  void clearSelection() {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      emit(currentState.copyWith(
        selectedPageNumbers: [],
        isSelectionMode: false,
        currentChapterForSelection: null,
        pendingChapterTitle: null,
        pendingChapterDescription: null,
        pendingChapterDuration: null,
      ));
    }
  }

  Future<void> saveSelectedPagesAsChapter({
    required String title,
    String? description,
    String? duration,
  }) async {
    final currentState = state;
    if (currentState is! BookEditingLoaded || 
        currentState.selectedPageNumbers.isEmpty ||
        currentState.currentChapterForSelection == null) {
      return;
    }

    try {
      final chapterNumber = currentState.currentChapterForSelection!;
      final selectedPages = List<int>.from(currentState.selectedPageNumbers);
      
      final newChapter = ChapterInfo(
        chapterNumber: chapterNumber,
        title: title,
        description: description,
        pageNumbers: selectedPages,
        duration: duration,
      );

      final updatedChapters = List<ChapterInfo>.from(currentState.chapters);
      final existingIndex = updatedChapters.indexWhere((c) => c.chapterNumber == chapterNumber);
      
      if (existingIndex >= 0) {
        updatedChapters[existingIndex] = newChapter;
      } else {
        updatedChapters.add(newChapter);
        updatedChapters.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
      }

      emit(currentState.copyWith(
        chapters: updatedChapters,
        selectedPageNumbers: [],
        isSelectionMode: false,
        currentChapterForSelection: null,
        pendingChapterTitle: null,
        pendingChapterDescription: null,
        pendingChapterDuration: null,
      ));

    } catch (e) {
      emit(BookEditingError('Failed to save chapter: $e'));
    }
  }

  void updateChapterDetails(
    int chapterNumber, {
    required String title,
    String? description,
    String? duration,
  }) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final updatedChapters = currentState.chapters.map((chapter) {
        if (chapter.chapterNumber == chapterNumber) {
          return chapter.copyWith(
            title: title,
            description: description,
            duration: duration,
          );
        }
        return chapter;
      }).toList();

      emit(currentState.copyWith(chapters: updatedChapters));
    }
  }

  void editChapter(int chapterNumber) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final chapter = currentState.chapters.firstWhere(
        (c) => c.chapterNumber == chapterNumber,
        orElse: () => ChapterInfo(
          chapterNumber: chapterNumber,
          title: 'Chapter $chapterNumber',
          pageNumbers: const [],
        ),
      );

      emit(currentState.copyWith(
        isSelectionMode: true,
        currentChapterForSelection: chapterNumber,
        selectedPageNumbers: List<int>.from(chapter.pageNumbers),
        pendingChapterTitle: chapter.title,
        pendingChapterDescription: chapter.description,
        pendingChapterDuration: chapter.duration,
      ));
    }
  }

  void deleteChapter(int chapterNumber) {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      final updatedChapters = currentState.chapters
          .where((c) => c.chapterNumber != chapterNumber)
          .toList();

      emit(currentState.copyWith(chapters: updatedChapters));
    }
  }

  Future<List<File>> generateChapterPdfs() async {
    final currentState = state;
    if (currentState is! BookEditingLoaded) {
      throw Exception('No PDF loaded for editing');
    }

    final chapterFiles = <File>[];

    try {
      final sortedChapters = List<ChapterInfo>.from(currentState.chapters)
        ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));

      for (int i = 0; i < sortedChapters.length; i++) {
        final chapter = sortedChapters[i];
        
        emit(BookEditingLoading(
          message: 'Generating ${chapter.title}...',
          progress: (i + 1) / sortedChapters.length,
        ));

        final pagesInSelectionOrder = chapter.pageNumbers;

        final chapterFile = await _pdfManipulationService.extractPagesAsNewPdf(
          sourcePdf: currentState.sourcePdf,
          pageNumbers: pagesInSelectionOrder,
          outputFileName: 'chapter_${chapter.chapterNumber}_${DateTime.now().millisecondsSinceEpoch}',
        );

        chapterFiles.add(chapterFile);
      }

      emit(currentState);
      return chapterFiles;

    } catch (e) {
      emit(BookEditingError('Failed to generate chapter PDFs: $e'));
      rethrow;
    }
  }

  void reset() {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      _pdfCacheService.clearPdfCache(currentState.pdfId);
    }
    emit(BookEditingInitial());
  }

  @override
  Future<void> close() {
    final currentState = state;
    if (currentState is BookEditingLoaded) {
      _pdfCacheService.clearPdfCache(currentState.pdfId);
    }
    return super.close();
  }
}