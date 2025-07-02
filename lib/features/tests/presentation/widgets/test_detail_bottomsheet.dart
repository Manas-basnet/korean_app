import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class TestDetailsBottomSheet extends StatelessWidget {
  final TestItem test;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onStartTest;

  const TestDetailsBottomSheet({
    super.key,
    required this.test,
    required this.languageCubit,
    required this.onStartTest,
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
                        if (test.imageUrl?.isNotEmpty == true || test.imagePath?.isNotEmpty == true)
                          _buildTestImage(context, test, screenSize),
                        
                        Text(
                          test.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            fontSize: screenSize.width * 0.055,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.015),
                        Text(
                          test.description,
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
                              icon: Icons.quiz_rounded,
                              label: '${test.questionCount} Questions',
                              color: colorScheme.primary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.timer_rounded,
                              label: test.formattedTimeLimit,
                              color: colorScheme.tertiary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.school_rounded,
                              label: '${test.formattedPassingScore} to pass',
                              color: colorScheme.secondary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            if (test.rating > 0)
                              _buildDetailChip(
                                icon: Icons.star_rounded,
                                label: '${test.formattedRating} (${test.ratingCount})',
                                color: Colors.amber[600]!,
                                theme: theme,
                                screenSize: screenSize,
                              ),
                            _buildDetailChip(
                              icon: Icons.visibility_rounded,
                              label: '${test.formattedViewCount} views',
                              color: Colors.blue[600]!,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                          ],
                        ),
                        
                        SizedBox(height: screenSize.height * 0.04),
                        
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onStartTest();
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              languageCubit.getLocalizedText(
                                korean: '시험 시작',
                                english: 'Start Test',
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

  Widget _buildTestImage(BuildContext context, TestItem test, Size screenSize) {
    return Container(
      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
      height: screenSize.height * 0.25,
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          DialogUtils.showFullScreenImage(
            context,
            test.imageUrl,
            test.imagePath,
            heroTag: 'test_detail_${test.id}',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (test.imagePath?.isNotEmpty == true)
                Image.file(
                  File(test.imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    if (test.imageUrl?.isNotEmpty == true) {
                      return _buildNetworkImage(test.imageUrl!);
                    }
                    return _buildImagePlaceholder(context, test);
                  },
                )
              else if (test.imageUrl?.isNotEmpty == true)
                _buildNetworkImage(test.imageUrl!)
              else
                _buildImagePlaceholder(context, test),
              
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

  Widget _buildImagePlaceholder(BuildContext context, TestItem test) {
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
          test.icon,
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

  static void show(
    BuildContext context, {
    required TestItem test,
    required LanguagePreferenceCubit languageCubit,
    required VoidCallback onStartTest,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TestDetailsBottomSheet(
        test: test,
        languageCubit: languageCubit,
        onStartTest: onStartTest,
      ),
    );
  }
}