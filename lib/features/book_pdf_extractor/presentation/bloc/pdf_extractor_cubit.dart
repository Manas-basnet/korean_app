import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/load_pdf_pages_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/load_pdf_pages_with_progress_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/generate_chapter_pdfs_usecase.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/usecases/convert_to_book_chapters_usecase.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';

part 'pdf_extractor_state.dart';

class PdfExtractorCubit extends Cubit<PdfExtractorState> {
  final LoadPdfPagesUseCase _loadPdfPagesUseCase;
  final LoadPdfPagesWithProgressUseCase _loadPdfPagesWithProgressUseCase;
  final GenerateChapterPdfsUseCase _generateChapterPdfsUseCase;
  final ConvertToBookChaptersUseCase _convertToBookChaptersUseCase;

  StreamSubscription<double>? _progressSubscription;

  PdfExtractorCubit({
    required LoadPdfPagesUseCase loadPdfPagesUseCase,
    required LoadPdfPagesWithProgressUseCase loadPdfPagesWithProgressUseCase,
    required GenerateChapterPdfsUseCase generateChapterPdfsUseCase,
    required ConvertToBookChaptersUseCase convertToBookChaptersUseCase,
  }) : _loadPdfPagesUseCase = loadPdfPagesUseCase,
       _loadPdfPagesWithProgressUseCase = loadPdfPagesWithProgressUseCase,
       _generateChapterPdfsUseCase = generateChapterPdfsUseCase,
       _convertToBookChaptersUseCase = convertToBookChaptersUseCase,
       super(PdfExtractorInitial());

  @override
  Future<void> close() {
    _progressSubscription?.cancel();
    return super.close();
  }

  Future<void> loadPdfForEditing(File pdfFile) async {
    try {
      emit(PdfExtractorLoading(message: 'Initializing PDF...', progress: 0.0));

      final pdfId = _generatePdfId(pdfFile);
      
      _progressSubscription?.cancel();
      _progressSubscription = _loadPdfPagesWithProgressUseCase(pdfFile).listen(
        (progress) {
          String message;
          if (progress < 0.2) {
            message = 'Reading PDF file...';
          } else if (progress < 0.4) {
            message = 'Analyzing PDF structure...';
          } else if (progress < 0.9) {
            message = 'Generating page thumbnails...';
          } else {
            message = 'Finalizing...';
          }
          
          emit(PdfExtractorLoading(message: message, progress: progress));
        },
        onDone: () async {
          try {
            emit(PdfExtractorLoading(message: 'Loading page data...', progress: 0.95));
            
            final pages = await _loadPdfPagesUseCase(pdfFile);

            emit(PdfExtractorLoaded(
              sourcePdf: pdfFile,
              pdfId: pdfId,
              pages: pages,
              chapters: const [],
              selectedPageNumbers: const [],
            ));
          } catch (e) {
            emit(PdfExtractorError('Failed to load page data: $e'));
          }
        },
        onError: (error) {
          emit(PdfExtractorError('Failed to process PDF: $error'));
        },
      );

    } catch (e) {
      emit(PdfExtractorError('Failed to load PDF: $e'));
    }
  }

  String _generatePdfId(File pdfFile) {
    final stat = pdfFile.statSync();
    return '${pdfFile.path.hashCode}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
  }

  void startPageSelectionWithDetails({
    required int chapterNumber,
    required String title,
    String? description,
    String? duration,
  }) {
    final currentState = state;
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is! PdfExtractorLoaded || 
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
      emit(PdfExtractorError('Failed to save chapter: $e'));
    }
  }

  void updateChapterDetails(
    int chapterNumber, {
    required String title,
    String? description,
    String? duration,
  }) {
    final currentState = state;
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is PdfExtractorLoaded) {
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
    if (currentState is PdfExtractorLoaded) {
      final updatedChapters = currentState.chapters
          .where((c) => c.chapterNumber != chapterNumber)
          .toList();

      emit(currentState.copyWith(chapters: updatedChapters));
    }
  }

  Future<List<BookChapter>> generateBookChapters() async {
    final currentState = state;
    if (currentState is! PdfExtractorLoaded) {
      throw Exception('No PDF loaded for editing');
    }

    try {
      final sortedChapters = List<ChapterInfo>.from(currentState.chapters)
        ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));

      emit(PdfExtractorLoading(message: 'Generating chapter PDFs...', progress: 0.5));

      final chapterFiles = await _generateChapterPdfsUseCase(currentState.sourcePdf, sortedChapters);
      
      emit(PdfExtractorLoading(message: 'Converting to book chapters...', progress: 0.8));
      
      final bookChapters = await _convertToBookChaptersUseCase(sortedChapters, chapterFiles);

      emit(currentState);
      return bookChapters;

    } catch (e) {
      emit(PdfExtractorError('Failed to generate book chapters: $e'));
      rethrow;
    }
  }

  void reset() {
    _progressSubscription?.cancel();
    emit(PdfExtractorInitial());
  }
}