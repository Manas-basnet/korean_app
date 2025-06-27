part of 'book_editing_cubit.dart';

abstract class BookEditingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class BookEditingInitial extends BookEditingState {}

class BookEditingLoading extends BookEditingState {
  final String message;
  final double progress;

  BookEditingLoading({required this.message, this.progress = 0.0});

  @override
  List<Object?> get props => [message, progress];
}

class BookEditingLoaded extends BookEditingState {
  final File sourcePdf;
  final String pdfId;
  final List<PdfPageInfo> pages;
  final List<ChapterInfo> chapters;
  final List<int> selectedPageNumbers;
  final bool isSelectionMode;
  final int? currentChapterForSelection;

  BookEditingLoaded({
    required this.sourcePdf,
    required this.pdfId,
    required this.pages,
    required this.chapters,
    required this.selectedPageNumbers,
    this.isSelectionMode = false,
    this.currentChapterForSelection,
  });

  BookEditingLoaded copyWith({
    File? sourcePdf,
    String? pdfId,
    List<PdfPageInfo>? pages,
    List<ChapterInfo>? chapters,
    List<int>? selectedPageNumbers,
    bool? isSelectionMode,
    int? currentChapterForSelection,
  }) {
    return BookEditingLoaded(
      sourcePdf: sourcePdf ?? this.sourcePdf,
      pdfId: pdfId ?? this.pdfId,
      pages: pages ?? this.pages,
      chapters: chapters ?? this.chapters,
      selectedPageNumbers: selectedPageNumbers ?? this.selectedPageNumbers,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      currentChapterForSelection: currentChapterForSelection ?? this.currentChapterForSelection,
    );
  }

  List<PdfPageInfo> get unassignedPages => pages.where((page) => 
    !chapters.any((chapter) => chapter.pageNumbers.contains(page.pageNumber))
  ).toList();

  List<PdfPageInfo> get availablePages => pages.where((page) => 
    !chapters.any((chapter) => chapter.pageNumbers.contains(page.pageNumber)) ||
    selectedPageNumbers.contains(page.pageNumber)
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

  @override
  List<Object?> get props => [
    sourcePdf.path,
    pdfId,
    pages,
    chapters,
    selectedPageNumbers,
    isSelectionMode,
    currentChapterForSelection,
  ];
}

class BookEditingError extends BookEditingState {
  final String message;

  BookEditingError(this.message);

  @override
  List<Object?> get props => [message];
}

class BookEditingChapterSaved extends BookEditingState {
  final ChapterInfo chapter;

  BookEditingChapterSaved(this.chapter);

  @override
  List<Object?> get props => [chapter];
}