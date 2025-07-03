import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class BookDetailsBottomSheet extends StatelessWidget {
  final BookItem book;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onStartReading;

  const BookDetailsBottomSheet({
    super.key,
    required this.book,
    required this.languageCubit,
    required this.onStartReading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    
    return Container(
      margin: EdgeInsets.all(screenSize.width * 0.04),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(
                    top: screenSize.height * 0.015,
                    bottom: screenSize.height * 0.01,
                  ),
                  width: screenSize.width * 0.1,
                  height: screenSize.height * 0.005,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.all(screenSize.width * 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (book.imageUrl?.isNotEmpty == true || book.imagePath?.isNotEmpty == true)
                          _buildBookImage(context, book, screenSize),
                        
                        Text(
                          book.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            fontSize: screenSize.width * 0.055,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.015),
                        Text(
                          book.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                            fontSize: screenSize.width * 0.04,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.03),
                        
                        Wrap(
                          spacing: screenSize.width * 0.03,
                          runSpacing: screenSize.height * 0.015,
                          children: [
                            _buildDetailChip(
                              icon: Icons.book_outlined,
                              label: '${book.chapterCount} Chapters',
                              color: colorScheme.primary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            if (book.totalDuration > 0)
                              _buildDetailChip(
                                icon: Icons.access_time_rounded,
                                label: book.formattedDuration,
                                color: colorScheme.tertiary,
                                theme: theme,
                                screenSize: screenSize,
                              ),
                            _buildDetailChip(
                              icon: Icons.school_rounded,
                              label: book.level.getName(languageCubit),
                              color: colorScheme.secondary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            if (book.rating > 0)
                              _buildDetailChip(
                                icon: Icons.star_rounded,
                                label: '${book.formattedRating} (${book.ratingCount})',
                                color: Colors.amber[600]!,
                                theme: theme,
                                screenSize: screenSize,
                              ),
                            _buildDetailChip(
                              icon: Icons.visibility_rounded,
                              label: '${book.formattedViewCount} views',
                              color: Colors.blue[600]!,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                          ],
                        ),
                        
                        if (book.chapters.isNotEmpty) ...[
                          SizedBox(height: screenSize.height * 0.04),
                          Text(
                            languageCubit.getLocalizedText(
                              korean: '챕터',
                              english: 'Chapters',
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: screenSize.height * 0.02),
                          _buildChaptersList(context, screenSize, theme, colorScheme),
                        ],
                        
                        SizedBox(height: screenSize.height * 0.04),
                        
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onStartReading();
                            },
                            icon: const Icon(Icons.menu_book_rounded),
                            label: Text(
                              languageCubit.getLocalizedText(
                                korean: '읽기 시작',
                                english: 'Start Reading',
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: screenSize.height * 0.02,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookImage(BuildContext context, BookItem book, Size screenSize) {
    return Container(
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      height: screenSize.height * 0.25,
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          DialogUtils.showFullScreenImage(
            context,
            book.imageUrl,
            book.imagePath,
            heroTag: 'book_detail_${book.id}',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (book.imagePath?.isNotEmpty == true)
                Image.file(
                  File(book.imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    if (book.imageUrl?.isNotEmpty == true) {
                      return _buildNetworkImage(book.imageUrl!);
                    }
                    return _buildImagePlaceholder(context, book);
                  },
                )
              else if (book.imageUrl?.isNotEmpty == true)
                _buildNetworkImage(book.imageUrl!)
              else
                _buildImagePlaceholder(context, book),
              
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, size: 48),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context, BookItem book) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.8),
            colorScheme.primary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          book.icon,
          size: 48,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeData theme,
    required Size screenSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.03,
        vertical: screenSize.height * 0.01,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: screenSize.width * 0.04, color: color),
          SizedBox(width: screenSize.width * 0.015),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: screenSize.width * 0.03,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList(BuildContext context, Size screenSize, ThemeData theme, ColorScheme colorScheme) {
    final maxChaptersToShow = 3;
    final chaptersToShow = book.chapters.take(maxChaptersToShow).toList();
    final hasMoreChapters = book.chapters.length > maxChaptersToShow;
    
    return Column(
      children: [
        ...chaptersToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final chapter = entry.value;
          
          return Container(
            margin: EdgeInsets.only(bottom: screenSize.height * 0.01),
            padding: EdgeInsets.all(screenSize.width * 0.03),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: screenSize.width * 0.08,
                  height: screenSize.width * 0.08,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: screenSize.width * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chapter.description.isNotEmpty) ...[
                        SizedBox(height: screenSize.height * 0.002),
                        Text(
                          chapter.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (chapter.duration > 0) ...[
                  SizedBox(width: screenSize.width * 0.02),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.02,
                      vertical: screenSize.height * 0.003,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      chapter.formattedDuration,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        
        if (hasMoreChapters)
          Container(
            margin: EdgeInsets.only(top: screenSize.height * 0.01),
            padding: EdgeInsets.all(screenSize.width * 0.03),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.more_horiz_rounded,
                  color: colorScheme.primary,
                  size: screenSize.width * 0.05,
                ),
                SizedBox(width: screenSize.width * 0.02),
                Text(
                  languageCubit.getLocalizedText(
                    korean: '${book.chapters.length - maxChaptersToShow}개 챕터 더',
                    english: '${book.chapters.length - maxChaptersToShow} more chapters',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static void show(
    BuildContext context, {
    required BookItem book,
    required LanguagePreferenceCubit languageCubit,
    required VoidCallback onStartReading,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookDetailsBottomSheet(
        book: book,
        languageCubit: languageCubit,
        onStartReading: onStartReading,
      ),
    );
  }
}