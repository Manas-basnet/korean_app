import 'dart:io';
import 'package:flutter/material.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_info.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/pdf_page_info.dart';

class PdfPageGridView extends StatelessWidget {
  final List<PdfPageInfo> pages;
  final List<ChapterInfo> chapters;
  final List<int> selectedPageNumbers;
  final bool isSelectionMode;
  final Function(int pageNumber) onPageTap;
  final Function(int pageNumber) onPageLongPress;

  const PdfPageGridView({
    super.key,
    required this.pages,
    required this.chapters,
    required this.selectedPageNumbers,
    required this.isSelectionMode,
    required this.onPageTap,
    required this.onPageLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          return PdfPageThumbnail(
            page: page,
            chapterNumber: _getPageChapterNumber(page.pageNumber),
            isSelected: selectedPageNumbers.contains(page.pageNumber),
            isSelectionMode: isSelectionMode,
            onTap: () => onPageTap(page.pageNumber),
            onLongPress: () => onPageLongPress(page.pageNumber),
          );
        },
      ),
    );
  }

  int? _getPageChapterNumber(int pageNumber) {
    for (final chapter in chapters) {
      if (chapter.pageNumbers.contains(pageNumber)) {
        return chapter.chapterNumber;
      }
    }
    return null;
  }
}

class PdfPageThumbnail extends StatelessWidget {
  final PdfPageInfo page;
  final int? chapterNumber;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PdfPageThumbnail({
    super.key,
    required this.page,
    this.chapterNumber,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getBorderColor(colorScheme),
            width: _getBorderWidth(),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            children: [
              Positioned.fill(
                child: page.thumbnailPath != null
                    ? Image.file(
                        File(page.thumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildErrorPlaceholder(context),
                      )
                    : _buildLoadingPlaceholder(context),
              ),

              if (isSelected && isSelectionMode)
                Positioned.fill(
                  child: Container(
                    color: colorScheme.primary.withOpacity(0.3),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

              if (chapterNumber != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getChapterColor(chapterNumber!),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        chapterNumber.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    page.pageNumber.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(ColorScheme colorScheme) {
    if (isSelected && isSelectionMode) {
      return colorScheme.primary;
    } else if (chapterNumber != null) {
      return _getChapterColor(chapterNumber!);
    } else {
      return colorScheme.outline.withOpacity(0.3);
    }
  }

  double _getBorderWidth() {
    if (isSelected && isSelectionMode) {
      return 3;
    } else if (chapterNumber != null) {
      return 2;
    } else {
      return 1;
    }
  }

  Color _getChapterColor(int chapterNumber) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[(chapterNumber - 1) % colors.length];
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}