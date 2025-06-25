import 'package:flutter/material.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class QuestionNavigationSheet extends StatelessWidget {
  final TestSession session;
  final LanguagePreferenceCubit languageCubit;
  final Function(int) onQuestionSelected;

  const QuestionNavigationSheet({
    super.key,
    required this.session,
    required this.languageCubit,
    required this.onQuestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Account for header height and padding when calculating max height
    const headerHeight = 80.0; // Approximate header height including padding
    final availableHeight = isLandscape 
        ? (screenHeight * 0.8) - headerHeight  // 80% minus header in landscape
        : (screenHeight * 0.6) - headerHeight; // 60% minus header in portrait
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Text(
                  languageCubit.getLocalizedText(korean: '문제 목록', english: 'Question Navigation'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Flexible Grid Container
          Flexible(
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: availableHeight,
                minHeight: isLandscape ? 120 : 200,
              ),
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLandscape ? 8 : 5, // More columns in landscape for better fit
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: session.totalQuestions,
                itemBuilder: (context, index) {
                  final isCurrentQuestion = index == session.currentQuestionIndex;
                  final isAnswered = session.isQuestionAnswered(index);
                  
                  Color backgroundColor;
                  Color textColor;
                  Color borderColor;
                  
                  if (isCurrentQuestion) {
                    backgroundColor = colorScheme.primary;
                    textColor = colorScheme.onPrimary;
                    borderColor = colorScheme.primary;
                  } else if (isAnswered) {
                    backgroundColor = colorScheme.primaryContainer;
                    textColor = colorScheme.onPrimaryContainer;
                    borderColor = colorScheme.primary.withValues(alpha: 0.5);
                  } else {
                    backgroundColor = colorScheme.surfaceContainerHighest;
                    textColor = colorScheme.onSurfaceVariant;
                    borderColor = colorScheme.outlineVariant;
                  }
                  
                  return Material(
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onQuestionSelected(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (isAnswered && !isCurrentQuestion)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context,
    TestSession session,
    LanguagePreferenceCubit languageCubit,
    Function(int) onQuestionSelected,
  ) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * (isLandscape ? 0.9 : 0.8),
      ),
      builder: (context) => QuestionNavigationSheet(
        session: session,
        languageCubit: languageCubit,
        onQuestionSelected: onQuestionSelected,
      ),
    );
  }
}