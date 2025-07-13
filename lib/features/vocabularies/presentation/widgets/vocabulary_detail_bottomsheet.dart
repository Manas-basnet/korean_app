import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class VocabularyDetailsBottomSheet extends StatelessWidget {
  final VocabularyItem vocabulary;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onStartStudying;

  const VocabularyDetailsBottomSheet({
    super.key,
    required this.vocabulary,
    required this.languageCubit,
    required this.onStartStudying,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    
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
                        if (vocabulary.imageUrl?.isNotEmpty == true || vocabulary.imagePath?.isNotEmpty == true)
                          _buildVocabularyImage(context, vocabulary, screenSize),
                        
                        Text(
                          vocabulary.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            fontSize: screenSize.width * 0.055,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.015),
                        Text(
                          vocabulary.description,
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
                              label: '${vocabulary.chapterCount} ${languageCubit.getLocalizedText(korean: "챕터", english: "Chapters")}',
                              color: colorScheme.primary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.translate,
                              label: '${vocabulary.totalWords} ${languageCubit.getLocalizedText(korean: "단어", english: "Words")}',
                              color: colorScheme.secondary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.language,
                              label: vocabulary.primaryLanguage.displayName,
                              color: colorScheme.tertiary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.school_rounded,
                              label: vocabulary.level.getName(languageCubit),
                              color: vocabulary.level.getColor(),
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            if (vocabulary.rating > 0)
                              _buildDetailChip(
                                icon: Icons.star_rounded,
                                label: '${vocabulary.formattedRating} (${vocabulary.ratingCount})',
                                color: Colors.amber[600]!,
                                theme: theme,
                                screenSize: screenSize,
                              ),
                            _buildDetailChip(
                              icon: Icons.visibility_rounded,
                              label: '${vocabulary.formattedViewCount} ${languageCubit.getLocalizedText(korean: "조회", english: "views")}',
                              color: Colors.blue[600]!,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                          ],
                        ),
                        
                        if (vocabulary.chapters.isNotEmpty) ...[
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
                        
                        if (vocabulary.hasPdfs) ...[
                          SizedBox(height: screenSize.height * 0.04),
                          Text(
                            languageCubit.getLocalizedText(
                              korean: 'PDF 자료',
                              english: 'PDF Resources',
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: screenSize.height * 0.02),
                          _buildPdfsList(context, screenSize, theme, colorScheme),
                        ],
                        
                        SizedBox(height: screenSize.height * 0.04),
                        
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onStartStudying();
                            },
                            icon: const Icon(Icons.school_rounded),
                            label: Text(
                              languageCubit.getLocalizedText(
                                korean: '학습 시작',
                                english: 'Start Studying',
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

  Widget _buildVocabularyImage(BuildContext context, VocabularyItem vocabulary, Size screenSize) {
    return Container(
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      height: screenSize.height * 0.25,
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          DialogUtils.showFullScreenImage(
            context,
            vocabulary.imageUrl,
            vocabulary.imagePath,
            heroTag: 'vocabulary_detail_${vocabulary.id}',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (vocabulary.imagePath?.isNotEmpty == true)
                Image.file(
                  File(vocabulary.imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    if (vocabulary.imageUrl?.isNotEmpty == true) {
                      return _buildNetworkImage(vocabulary.imageUrl!);
                    }
                    return _buildImagePlaceholder(context, vocabulary);
                  },
                )
              else if (vocabulary.imageUrl?.isNotEmpty == true)
                _buildNetworkImage(vocabulary.imageUrl!)
              else
                _buildImagePlaceholder(context, vocabulary),
              
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
              
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vocabulary.primaryLanguage.flag,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vocabulary.primaryLanguage.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

  Widget _buildImagePlaceholder(BuildContext context, VocabularyItem vocabulary) {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 8),
            Text(
              vocabulary.primaryLanguage.flag,
              style: const TextStyle(fontSize: 32),
            ),
          ],
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
    const maxChaptersToShow = 3;
    final chaptersToShow = vocabulary.chapters.take(maxChaptersToShow).toList();
    final hasMoreChapters = vocabulary.chapters.length > maxChaptersToShow;
    
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
                SizedBox(width: screenSize.width * 0.02),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.02,
                    vertical: screenSize.height * 0.003,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${chapter.wordCount} ${languageCubit.getLocalizedText(korean: "단어", english: "words")}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
                    korean: '${vocabulary.chapters.length - maxChaptersToShow}개 챕터 더',
                    english: '${vocabulary.chapters.length - maxChaptersToShow} more chapters',
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

  Widget _buildPdfsList(BuildContext context, Size screenSize, ThemeData theme, ColorScheme colorScheme) {
    final allPdfs = [...vocabulary.pdfUrls, ...vocabulary.pdfPaths];
    const maxPdfsToShow = 2;
    final pdfsToShow = allPdfs.take(maxPdfsToShow).toList();
    final hasMorePdfs = allPdfs.length > maxPdfsToShow;
    
    return Column(
      children: [
        ...pdfsToShow.asMap().entries.map((entry) {
          final pdfPath = entry.value;
          final fileName = pdfPath.split('/').last;
          
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
                SizedBox(width: screenSize.width * 0.03),
                Expanded(
                  child: Text(
                    fileName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        
        if (hasMorePdfs)
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
                    korean: '${allPdfs.length - maxPdfsToShow}개 PDF 더',
                    english: '${allPdfs.length - maxPdfsToShow} more PDFs',
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
    required VocabularyItem vocabulary,
    required LanguagePreferenceCubit languageCubit,
    required VoidCallback onStartStudying,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VocabularyDetailsBottomSheet(
        vocabulary: vocabulary,
        languageCubit: languageCubit,
        onStartStudying: onStartStudying,
      ),
    );
  }
}