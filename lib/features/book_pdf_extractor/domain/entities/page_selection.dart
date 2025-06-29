import 'package:equatable/equatable.dart';

class PageSelection extends Equatable {
  final int pageNumber;
  final int? chapterNumber;
  final String? chapterTitle;
  final bool isSelected;

  const PageSelection({
    required this.pageNumber,
    this.chapterNumber,
    this.chapterTitle,
    this.isSelected = false,
  });

  PageSelection copyWith({
    int? pageNumber,
    int? chapterNumber,
    String? chapterTitle,
    bool? isSelected,
  }) {
    return PageSelection(
      pageNumber: pageNumber ?? this.pageNumber,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [pageNumber, chapterNumber, chapterTitle, isSelected];
}
