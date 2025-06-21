import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class TestRatingDialog extends StatefulWidget {
  final String testTitle;
  final Function(double rating) onRating;
  final VoidCallback onSkip;

  const TestRatingDialog({
    super.key,
    required this.testTitle,
    required this.onRating,
    required this.onSkip,
  });

  @override
  State<TestRatingDialog> createState() => _TestRatingDialogState();
}

class _TestRatingDialogState extends State<TestRatingDialog>
    with TickerProviderStateMixin {
  double _rating = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    languageCubit.getLocalizedText(
                      korean: '시험은 어떠셨나요?',
                      english: 'How was the test?',
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    widget.testTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    languageCubit.getLocalizedText(
                      korean: '별점을 선택해주세요',
                      english: 'Please rate this test',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildStarRating(colorScheme),
                  
                  const SizedBox(height: 8),
                  
                  if (_rating > 0)
                    Text(
                      _getRatingText(_rating, languageCubit),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onSkip,
                          child: Text(
                            languageCubit.getLocalizedText(
                              korean: '나중에',
                              english: 'Skip',
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageCubit.getLocalizedText(
                              korean: '평가하기',
                              english: 'Submit Rating',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
          onTap: () {
            setState(() {
              _rating = starValue;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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

class TestRatingDialogHelper {
  static Future<double?> showRatingDialog(
    BuildContext context, {
    required String testTitle,
  }) async {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestRatingDialog(
        testTitle: testTitle,
        onRating: (rating) => Navigator.of(context).pop(rating),
        onSkip: () => Navigator.of(context).pop(null),
      ),
    );
  }
}