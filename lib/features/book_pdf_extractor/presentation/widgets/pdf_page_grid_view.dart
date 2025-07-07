// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:korean_language_app/shared/models/book_related/chapter_info.dart';
// import 'package:korean_language_app/features/book_pdf_extractor/domain/entities/pdf_page_info.dart';

// class PdfPageGridView extends StatelessWidget {
//   final List<PdfPageInfo> pages;
//   final List<ChapterInfo> chapters;
//   final List<int> selectedPageNumbers;
//   final bool isSelectionMode;
//   final Function(int pageNumber) onPageTap;
//   final Function(int pageNumber) onPageLongPress;

//   const PdfPageGridView({
//     super.key,
//     required this.pages,
//     required this.chapters,
//     required this.selectedPageNumbers,
//     required this.isSelectionMode,
//     required this.onPageTap,
//     required this.onPageLongPress,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.sizeOf(context).width;
//     final crossAxisCount = _calculateCrossAxisCount(screenWidth);
    
//     return GridView.builder(
//       padding: const EdgeInsets.all(8),
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: crossAxisCount,
//         childAspectRatio: 0.75,
//         crossAxisSpacing: 8,
//         mainAxisSpacing: 8,
//       ),
//       itemCount: pages.length,
//       itemBuilder: (context, index) {
//         final page = pages[index];
//         final chapterInfo = _getPageChapterInfo(page.pageNumber);
//         final pageOrderInChapter = _getPageOrderInChapter(page.pageNumber, chapterInfo);
//         final selectionOrder = _getSelectionOrder(page.pageNumber);
        
//         return PdfPageThumbnail(
//           page: page,
//           chapterInfo: chapterInfo,
//           pageOrderInChapter: pageOrderInChapter,
//           selectionOrder: selectionOrder,
//           isSelected: selectedPageNumbers.contains(page.pageNumber),
//           isSelectionMode: isSelectionMode,
//           onTap: () => onPageTap(page.pageNumber),
//           onLongPress: () => onPageLongPress(page.pageNumber),
//         );
//       },
//     );
//   }

//   int _calculateCrossAxisCount(double screenWidth) {
//     if (screenWidth > 600) return 4;
//     if (screenWidth > 400) return 3;
//     return 2;
//   }

//   ChapterInfo? _getPageChapterInfo(int pageNumber) {
//     for (final chapter in chapters) {
//       if (chapter.pageNumbers.contains(pageNumber)) {
//         return chapter;
//       }
//     }
//     return null;
//   }

//   int? _getPageOrderInChapter(int pageNumber, ChapterInfo? chapterInfo) {
//     if (chapterInfo == null) return null;
//     final index = chapterInfo.pageNumbers.indexOf(pageNumber);
//     return index >= 0 ? index + 1 : null;
//   }

//   int? _getSelectionOrder(int pageNumber) {
//     final index = selectedPageNumbers.indexOf(pageNumber);
//     return index >= 0 ? index + 1 : null;
//   }
// }

// class PdfPageThumbnail extends StatelessWidget {
//   final PdfPageInfo page;
//   final ChapterInfo? chapterInfo;
//   final int? pageOrderInChapter;
//   final int? selectionOrder;
//   final bool isSelected;
//   final bool isSelectionMode;
//   final VoidCallback onTap;
//   final VoidCallback onLongPress;

//   const PdfPageThumbnail({
//     super.key,
//     required this.page,
//     this.chapterInfo,
//     this.pageOrderInChapter,
//     this.selectionOrder,
//     required this.isSelected,
//     required this.isSelectionMode,
//     required this.onTap,
//     required this.onLongPress,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;

//     return GestureDetector(
//       onTap: onTap,
//       onLongPress: onLongPress,
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color: _getBorderColor(colorScheme),
//             width: _getBorderWidth(),
//           ),
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(7),
//           child: Stack(
//             children: [
//               Positioned.fill(
//                 child: Container(
//                   color: colorScheme.surfaceContainerHighest,
//                   child: page.thumbnailPath != null
//                       ? Image.file(
//                           File(page.thumbnailPath!),
//                           fit: BoxFit.cover,
//                           errorBuilder: (context, error, stackTrace) =>
//                               _buildErrorPlaceholder(context),
//                         )
//                       : _buildLoadingPlaceholder(context),
//                 ),
//               ),

//               if (isSelected && isSelectionMode && selectionOrder != null)
//                 Positioned.fill(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: colorScheme.primary.withValues(alpha:0.3),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Center(
//                       child: Container(
//                         width: 32,
//                         height: 32,
//                         decoration: BoxDecoration(
//                           color: colorScheme.primary,
//                           shape: BoxShape.circle,
//                         ),
//                         child: Center(
//                           child: Text(
//                             '$selectionOrder',
//                             style: TextStyle(
//                               color: colorScheme.onPrimary,
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//               if (chapterInfo != null && !isSelected)
//                 Positioned(
//                   top: 4,
//                   left: 4,
//                   right: 4,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: _getChapterColor(chapterInfo!.chapterNumber),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Text(
//                       _truncateChapterTitle(chapterInfo!.title),
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w600,
//                       ),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),

//               if (chapterInfo != null && !isSelected && pageOrderInChapter != null)
//                 Positioned.fill(
//                   child: Center(
//                     child: Container(
//                       width: 32,
//                       height: 32,
//                       decoration: BoxDecoration(
//                         color: _getChapterColor(chapterInfo!.chapterNumber),
//                         shape: BoxShape.circle,
//                         border: Border.all(color: Colors.white, width: 2),
//                       ),
//                       child: Center(
//                         child: Text(
//                           '$pageOrderInChapter',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//               Positioned(
//                 bottom: 4,
//                 right: 4,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withValues(alpha:0.7),
//                     borderRadius: BorderRadius.circular(3),
//                   ),
//                   child: Text(
//                     '${page.pageNumber}',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 10,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ),

//               if (isSelectionMode && chapterInfo != null && !isSelected)
//                 Positioned.fill(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.black.withValues(alpha:0.4),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Center(
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withValues(alpha:0.8),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: const Text(
//                           'Assigned',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 9,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   String _truncateChapterTitle(String title) {
//     if (title.length <= 8) return title;
//     return '${title.substring(0, 8)}...';
//   }

//   Color _getBorderColor(ColorScheme colorScheme) {
//     if (isSelected && isSelectionMode) {
//       return colorScheme.primary;
//     } else if (chapterInfo != null) {
//       return _getChapterColor(chapterInfo!.chapterNumber);
//     } else {
//       return colorScheme.outline.withValues(alpha:0.2);
//     }
//   }

//   double _getBorderWidth() {
//     if (isSelected && isSelectionMode) {
//       return 2;
//     } else if (chapterInfo != null) {
//       return 2;
//     } else {
//       return 1;
//     }
//   }

//   Color _getChapterColor(int chapterNumber) {
//     final colors = [
//       Colors.blue,
//       Colors.green,
//       Colors.orange,
//       Colors.purple,
//       Colors.red,
//       Colors.teal,
//       Colors.indigo,
//       Colors.pink,
//     ];
//     return colors[(chapterNumber - 1) % colors.length];
//   }

//   Widget _buildLoadingPlaceholder(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
    
//     return Container(
//       color: colorScheme.surfaceContainerHighest,
//       child: Center(
//         child: SizedBox(
//           width: 20,
//           height: 20,
//           child: CircularProgressIndicator(
//             strokeWidth: 2,
//             valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorPlaceholder(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
    
//     return Container(
//       color: colorScheme.errorContainer,
//       child: Center(
//         child: Icon(
//           Icons.broken_image,
//           color: colorScheme.onErrorContainer,
//           size: 24,
//         ),
//       ),
//     );
//   }
// }