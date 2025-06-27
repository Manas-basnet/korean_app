import 'package:equatable/equatable.dart';
import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/page_selection.dart';

class PdfPageInfo extends Equatable {
  final int pageNumber;
  final String? thumbnailPath;
  final double width;
  final double height;
  final PageSelection selection;

  const PdfPageInfo({
    required this.pageNumber,
    this.thumbnailPath,
    required this.width,
    required this.height,
    required this.selection,
  });

  PdfPageInfo copyWith({
    int? pageNumber,
    String? thumbnailPath,
    double? width,
    double? height,
    PageSelection? selection,
  }) {
    return PdfPageInfo(
      pageNumber: pageNumber ?? this.pageNumber,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      width: width ?? this.width,
      height: height ?? this.height,
      selection: selection ?? this.selection,
    );
  }

  @override
  List<Object?> get props => [pageNumber, thumbnailPath, width, height, selection];
}