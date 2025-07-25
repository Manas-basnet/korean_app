import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class VocabularyRatingDialog extends StatefulWidget {
  final String vocabularyTitle;
  final Function(double rating) onRating;
  final VoidCallback onSkip;
  final double? existingRating;

  const VocabularyRatingDialog({
    super.key,
    required this.vocabularyTitle,
    required this.onRating,
    required this.onSkip,
    this.existingRating,
  });

  @override
  State<VocabularyRatingDialog> createState() => _VocabularyRatingDialogState();
}

class _VocabularyRatingDialogState extends State<VocabularyRatingDialog>
    with TickerProviderStateMixin {
  late double _rating;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _starAnimationController;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating ?? 0;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _starAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _starAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _starAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _starAnimationController.dispose();
    super.dispose();
  }

  void _onStarTap(double newRating) {
    setState(() {
      _rating = newRating;
    });
    _starAnimationController.forward().then((_) {
      _starAnimationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();
    final isUpdating = widget.existingRating != null;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
                
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: maxHeight,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isUpdating 
                                      ? colorScheme.tertiaryContainer.withValues(alpha: 0.3)
                                      : colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUpdating ? Icons.edit_rounded : Icons.school_rounded,
                                  size: 40,
                                  color: isUpdating ? colorScheme.tertiary : colorScheme.primary,
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              Text(
                                languageCubit.getLocalizedText(
                                  korean: isUpdating ? '평점을 수정하시겠어요?' : '단어장은 어떠셨나요?',
                                  english: isUpdating ? 'Update your rating?' : 'How was the vocabulary?',
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Text(
                                widget.vocabularyTitle,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              if (isUpdating) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.history_rounded,
                                        size: 16,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        languageCubit.getLocalizedText(
                                          korean: '현재 평점: ${widget.existingRating!.toStringAsFixed(1)}',
                                          english: 'Current rating: ${widget.existingRating!.toStringAsFixed(1)}',
                                        ),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 24),
                              
                              Text(
                                languageCubit.getLocalizedText(
                                  korean: isUpdating ? '새로운 별점을 선택해주세요' : '별점을 선택해주세요',
                                  english: isUpdating ? 'Select your new rating' : 'Please rate this vocabulary',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              AnimatedBuilder(
                                animation: _starAnimation,
                                builder: (context, child) => _buildStarRating(colorScheme),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              if (_rating > 0)
                                Text(
                                  _getRatingText(_rating, languageCubit),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isUpdating ? colorScheme.tertiary : colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: widget.onSkip,
                                child: Text(
                                  languageCubit.getLocalizedText(
                                    korean: isUpdating ? '취소' : '나중에',
                                    english: isUpdating ? 'Cancel' : 'Skip',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _rating > 0 ? () => widget.onRating(_rating) : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: isUpdating ? colorScheme.tertiary : colorScheme.primary,
                                  foregroundColor: isUpdating ? colorScheme.onTertiary : colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isUpdating ? Icons.update_rounded : Icons.send_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      languageCubit.getLocalizedText(
                                        korean: isUpdating ? '수정하기' : '평가하기',
                                        english: isUpdating ? 'Update Rating' : 'Submit Rating',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarRating(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1.0;
        final isFilled = _rating >= starValue;
        final isHalfFilled = _rating >= starValue - 0.5 && _rating < starValue;
        
        return GestureDetector(
          onTap: () => _onStarTap(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: _rating == starValue ? _starAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isFilled
                      ? Icons.star_rounded
                      : isHalfFilled
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                  size: 40,
                  color: isFilled || isHalfFilled
                      ? Colors.amber[600]
                      : colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  String _getRatingText(double rating, LanguagePreferenceCubit languageCubit) {
    if (rating <= 1) {
      return languageCubit.getLocalizedText(
        korean: '많이 아쉬워요',
        english: 'Very Poor',
      );
    } else if (rating <= 2) {
      return languageCubit.getLocalizedText(
        korean: '아쉬워요',
        english: 'Poor',
      );
    } else if (rating <= 3) {
      return languageCubit.getLocalizedText(
        korean: '보통이에요',
        english: 'Average',
      );
    } else if (rating <= 4) {
      return languageCubit.getLocalizedText(
        korean: '좋아요',
        english: 'Good',
      );
    } else {
      return languageCubit.getLocalizedText(
        korean: '아주 좋아요!',
        english: 'Excellent!',
      );
    }
  }
}

class VocabularyRatingDialogHelper {
  static Future<double?> showRatingDialog(
    BuildContext context, {
    required String vocabularyTitle,
    double? existingRating,
  }) async {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VocabularyRatingDialog(
        vocabularyTitle: vocabularyTitle,
        existingRating: existingRating,
        onRating: (rating) => Navigator.of(context).pop(rating),
        onSkip: () => Navigator.of(context).pop(null),
      ),
    );
  }
}