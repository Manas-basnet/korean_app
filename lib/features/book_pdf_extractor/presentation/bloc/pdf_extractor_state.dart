part of 'pdf_extractor_cubit.dart';

abstract class PdfExtractorState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PdfExtractorInitial extends PdfExtractorState {}

class PdfExtractorLoading extends PdfExtractorState {
  final String message;
  final double progress;

  PdfExtractorLoading({required this.message, this.progress = 0.0});

  @override
  List<Object?> get props => [message, progress];
}

class PdfExtractorLoaded extends PdfExtractorState {
  final File sourcePdf;
  final String pdfId;
  final List<PdfPageInfo> pages;
  final List<ChapterInfo> chapters;
  final List<int> selectedPageNumbers;
  final bool isSelectionMode;
  final int? currentChapterForSelection;
  final String? pendingChapterTitle;
  final String? pendingChapterDescription;
  final String? pendingChapterDuration;

  PdfExtractorLoaded({
    required this.sourcePdf,
    required this.pdfId,
    required this.pages,
    required this.chapters,
    required this.selectedPageNumbers,
    this.isSelectionMode = false,
    this.currentChapterForSelection,
    this.pendingChapterTitle,
    this.pendingChapterDescription,
    this.pendingChapterDuration,
  });

  PdfExtractorLoaded copyWith({
    File? sourcePdf,
    String? pdfId,
    List<PdfPageInfo>? pages,
    List<ChapterInfo>? chapters,
    List<int>? selectedPageNumbers,
    bool? isSelectionMode,
    int? currentChapterForSelection,
    String? pendingChapterTitle,
    String? pendingChapterDescription,
    String? pendingChapterDuration,
  }) {
    return PdfExtractorLoaded(
      sourcePdf: sourcePdf ?? this.sourcePdf,
      pdfId: pdfId ?? this.pdfId,
      pages: pages ?? this.pages,
      chapters: chapters ?? this.chapters,
      selectedPageNumbers: selectedPageNumbers ?? this.selectedPageNumbers,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      currentChapterForSelection: currentChapterForSelection ?? this.currentChapterForSelection,
      pendingChapterTitle: pendingChapterTitle ?? this.pendingChapterTitle,
      pendingChapterDescription: pendingChapterDescription ?? this.pendingChapterDescription,
      pendingChapterDuration: pendingChapterDuration ?? this.pendingChapterDuration,
    );
  }

  List<PdfPageInfo> get unassignedPages => pages.where((page) => 
    !chapters.any((chapter) => chapter.pageNumbers.contains(page.pageNumber))
  ).toList();

  List<PdfPageInfo> get availablePages => pages.where((page) => 
    !chapters.any((chapter) => 
      chapter.pageNumbers.contains(page.pageNumber) &&
      chapter.chapterNumber != currentChapterForSelection
    )
  ).toList();

  bool isPageSelected(int pageNumber) => selectedPageNumbers.contains(pageNumber);

  int? getPageChapterNumber(int pageNumber) {
    for (final chapter in chapters) {
      if (chapter.pageNumbers.contains(pageNumber)) {
        return chapter.chapterNumber;
      }
    }
    return null;
  }

  ChapterInfo? getChapterByNumber(int chapterNumber) {
    try {
      return chapters.firstWhere((c) => c.chapterNumber == chapterNumber);
    } catch (e) {
      return null;
    }
  }

  List<ChapterInfo> get sortedChapters {
    final sorted = List<ChapterInfo>.from(chapters);
    sorted.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    return sorted;
  }

  bool get hasUnsavedSelection => 
    isSelectionMode && 
    selectedPageNumbers.isNotEmpty && 
    pendingChapterTitle != null;

  @override
  List<Object?> get props => [
    sourcePdf.path,
    pdfId,
    pages,
    chapters,
    selectedPageNumbers,
    isSelectionMode,
    currentChapterForSelection,
    pendingChapterTitle,
    pendingChapterDescription,
    pendingChapterDuration,
  ];
}

class PdfExtractorError extends PdfExtractorState {
  final String message;

  PdfExtractorError(this.message);

  @override
  List<Object?> get props => [message];
}