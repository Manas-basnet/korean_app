// import 'package:flutter/material.dart';
// import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';
// import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

// class ChapterNavigationSheet extends StatelessWidget {
//   final BookSession session;
//   final LanguagePreferenceCubit languageCubit;
//   final Function(int) onChapterSelected;

//   const ChapterNavigationSheet({
//     super.key,
//     required this.session,
//     required this.languageCubit,
//     required this.onChapterSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//     final screenSize = MediaQuery.sizeOf(context);
//     final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    
//     final maxHeight = screenSize.height * 0.8;
//     final headerHeight = screenSize.height * 0.08;
//     final availableContentHeight = maxHeight - headerHeight - bottomPadding;
    
//     return Container(
//       constraints: BoxConstraints(
//         maxHeight: maxHeight,
//         maxWidth: screenSize.width,
//       ),
//       decoration: BoxDecoration(
//         color: colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             margin: EdgeInsets.only(
//               top: screenSize.height * 0.01,
//               bottom: screenSize.height * 0.005,
//             ),
//             width: screenSize.width * 0.1,
//             height: screenSize.height * 0.005,
//             decoration: BoxDecoration(
//               color: colorScheme.outlineVariant.withValues(alpha: 0.5),
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
          
//           Container(
//             height: headerHeight,
//             padding: EdgeInsets.symmetric(
//               horizontal: screenSize.width * 0.05,
//               vertical: screenSize.height * 0.01,
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         languageCubit.getLocalizedText(
//                           korean: '챕터 목록',
//                           english: 'Chapters',
//                         ),
//                         style: theme.textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.w600,
//                           fontSize: screenSize.width * 0.05,
//                         ),
//                       ),
//                       Text(
//                         session.book.title,
//                         style: theme.textTheme.bodyMedium?.copyWith(
//                           color: colorScheme.onSurfaceVariant,
//                           fontSize: screenSize.width * 0.035,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: () => Navigator.pop(context),
//                   icon: Icon(
//                     Icons.close_rounded,
//                     size: screenSize.width * 0.06,
//                   ),
//                   style: IconButton.styleFrom(
//                     backgroundColor: colorScheme.surfaceContainerHighest,
//                     padding: EdgeInsets.all(screenSize.width * 0.02),
//                   ),
//                 ),
//               ],
//             ),
//           ),
          
//           Container(
//             margin: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
//             padding: EdgeInsets.symmetric(
//               horizontal: screenSize.width * 0.04,
//               vertical: screenSize.height * 0.015,
//             ),
//             decoration: BoxDecoration(
//               color: colorScheme.primaryContainer.withValues(alpha: 0.3),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.auto_stories_rounded,
//                   color: colorScheme.primary,
//                   size: screenSize.width * 0.05,
//                 ),
//                 SizedBox(width: screenSize.width * 0.03),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         languageCubit.getLocalizedText(
//                           korean: '읽기 진행률',
//                           english: 'Reading Progress',
//                         ),
//                         style: theme.textTheme.bodySmall?.copyWith(
//                           color: colorScheme.primary,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       LinearProgressIndicator(
//                         value: session.readingProgress,
//                         backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
//                         valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
//                         minHeight: 4,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(width: screenSize.width * 0.03),
//                 Text(
//                   session.formattedProgress,
//                   style: theme.textTheme.bodyMedium?.copyWith(
//                     color: colorScheme.primary,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ],
//             ),
//           ),
          
//           SizedBox(height: screenSize.height * 0.02),
          
//           Flexible(
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxHeight: availableContentHeight,
//               ),
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.only(
//                   left: screenSize.width * 0.02,
//                   right: screenSize.width * 0.02,
//                   bottom: screenSize.height * 0.02 + bottomPadding,
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: session.book.chapters.asMap().entries.map((entry) {
//                     final index = entry.key;
//                     final chapter = entry.value;
//                     final isCurrent = index == session.currentChapterIndex;
//                     final isCompleted = session.chapterProgress[index] == 1.0;
//                     final chapterProgress = session.chapterProgress[index] ?? 0.0;
                    
//                     return Container(
//                       margin: EdgeInsets.symmetric(
//                         horizontal: screenSize.width * 0.03,
//                         vertical: screenSize.height * 0.008,
//                       ),
//                       child: Material(
//                         color: Colors.transparent,
//                         borderRadius: BorderRadius.circular(16),
//                         child: InkWell(
//                           onTap: () => onChapterSelected(index),
//                           borderRadius: BorderRadius.circular(16),
//                           child: Container(
//                             padding: EdgeInsets.all(screenSize.width * 0.04),
//                             decoration: BoxDecoration(
//                               color: isCurrent 
//                                   ? colorScheme.primaryContainer.withValues(alpha: 0.4)
//                                   : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(
//                                 color: isCurrent 
//                                     ? colorScheme.primary.withValues(alpha: 0.5)
//                                     : colorScheme.outline.withValues(alpha: 0.2),
//                                 width: isCurrent ? 2 : 1,
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: screenSize.width * 0.12,
//                                   height: screenSize.width * 0.12,
//                                   decoration: BoxDecoration(
//                                     color: isCompleted
//                                         ? Colors.green
//                                         : isCurrent
//                                             ? colorScheme.primary
//                                             : colorScheme.outline.withValues(alpha: 0.3),
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                   child: Center(
//                                     child: isCompleted
//                                         ? Icon(
//                                             Icons.check_rounded,
//                                             color: Colors.white,
//                                             size: screenSize.width * 0.06,
//                                           )
//                                         : isCurrent
//                                             ? Icon(
//                                                 Icons.play_arrow_rounded,
//                                                 color: colorScheme.onPrimary,
//                                                 size: screenSize.width * 0.06,
//                                               )
//                                             : Text(
//                                                 '${index + 1}',
//                                                 style: theme.textTheme.titleMedium?.copyWith(
//                                                   color: colorScheme.onSurfaceVariant,
//                                                   fontWeight: FontWeight.w700,
//                                                   fontSize: screenSize.width * 0.04,
//                                                 ),
//                                               ),
//                                   ),
//                                 ),
                                
//                                 SizedBox(width: screenSize.width * 0.04),
                                
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         chapter.title,
//                                         style: theme.textTheme.titleMedium?.copyWith(
//                                           fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
//                                           color: isCurrent 
//                                               ? colorScheme.primary 
//                                               : colorScheme.onSurface,
//                                           fontSize: screenSize.width * 0.04,
//                                         ),
//                                         maxLines: 2,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
                                      
//                                       if (chapter.description.isNotEmpty) ...[
//                                         SizedBox(height: screenSize.height * 0.005),
//                                         Text(
//                                           chapter.description,
//                                           style: theme.textTheme.bodySmall?.copyWith(
//                                             color: colorScheme.onSurfaceVariant,
//                                             fontSize: screenSize.width * 0.032,
//                                           ),
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                       ],
                                      
//                                       if (chapterProgress > 0 && chapterProgress < 1.0) ...[
//                                         SizedBox(height: screenSize.height * 0.008),
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: LinearProgressIndicator(
//                                                 value: chapterProgress,
//                                                 backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
//                                                 valueColor: AlwaysStoppedAnimation<Color>(
//                                                   isCurrent ? colorScheme.primary : colorScheme.secondary,
//                                                 ),
//                                                 minHeight: 3,
//                                                 borderRadius: BorderRadius.circular(1.5),
//                                               ),
//                                             ),
//                                             SizedBox(width: screenSize.width * 0.02),
//                                             Text(
//                                               '${(chapterProgress * 100).toInt()}%',
//                                               style: theme.textTheme.bodySmall?.copyWith(
//                                                 color: colorScheme.onSurfaceVariant,
//                                                 fontWeight: FontWeight.w600,
//                                                 fontSize: screenSize.width * 0.028,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ],
//                                   ),
//                                 ),
                                
//                                 SizedBox(width: screenSize.width * 0.02),
                                
//                                 Column(
//                                   children: [
//                                     if (chapter.duration > 0)
//                                       Container(
//                                         padding: EdgeInsets.symmetric(
//                                           horizontal: screenSize.width * 0.02,
//                                           vertical: screenSize.height * 0.004,
//                                         ),
//                                         decoration: BoxDecoration(
//                                           color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
//                                           borderRadius: BorderRadius.circular(6),
//                                         ),
//                                         child: Text(
//                                           chapter.formattedDuration,
//                                           style: theme.textTheme.labelSmall?.copyWith(
//                                             color: colorScheme.onTertiaryContainer,
//                                             fontWeight: FontWeight.w600,
//                                             fontSize: screenSize.width * 0.025,
//                                           ),
//                                         ),
//                                       ),
                                    
//                                     if (chapter.hasAudioTracks) ...[
//                                       SizedBox(height: screenSize.height * 0.004),
//                                       Icon(
//                                         Icons.headphones_rounded,
//                                         size: screenSize.width * 0.04,
//                                         color: colorScheme.secondary,
//                                       ),
//                                     ],
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   static void show(
//     BuildContext context,
//     BookSession session,
//     LanguagePreferenceCubit languageCubit,
//     Function(int) onChapterSelected,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => ChapterNavigationSheet(
//         session: session,
//         languageCubit: languageCubit,
//         onChapterSelected: onChapterSelected,
//       ),
//     );
//   }
// }