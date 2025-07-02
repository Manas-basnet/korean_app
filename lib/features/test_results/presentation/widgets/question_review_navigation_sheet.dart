import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_answer.dart';

class TestReviewQuestionNavigationSheet extends StatelessWidget {
  final TestResult testResult;
  final int currentQuestionIndex;
  final LanguagePreferenceCubit languageCubit;
  final Function(int) onQuestionSelected;

  const TestReviewQuestionNavigationSheet({
    super.key,
    required this.testResult,
    required this.currentQuestionIndex,
    required this.languageCubit,
    required this.onQuestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    const headerHeight = 80.0;
    final availableHeight = isLandscape 
        ? (screenHeight * 0.8) - headerHeight
        : (screenHeight * 0.6) - headerHeight;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  crossAxisCount: isLandscape ? 8 : 5,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: testResult.testQuestions.length,
                itemBuilder: (context, index) {
                  final isCurrentQuestion = index == currentQuestionIndex;
                  final userAnswer = _getUserAnswerForQuestion(testResult.testQuestions[index].id);
                  final isAnswered = userAnswer != null;
                  final isCorrect = userAnswer?.isCorrect ?? false;
                  
                  Color backgroundColor;
                  Color textColor;
                  Color borderColor;
                  Widget? statusIcon;
                  
                  if (isCurrentQuestion) {
                    backgroundColor = colorScheme.primary;
                    textColor = colorScheme.onPrimary;
                    borderColor = colorScheme.primary;
                  } else if (isAnswered) {
                    if (isCorrect) {
                      backgroundColor = Colors.green.withValues(alpha: 0.1);
                      textColor = Colors.green;
                      borderColor = Colors.green.withValues(alpha: 0.5);
                      statusIcon = const Icon(Icons.check_circle, color: Colors.green, size: 12);
                    } else {
                      backgroundColor = Colors.red.withValues(alpha: 0.1);
                      textColor = Colors.red;
                      borderColor = Colors.red.withValues(alpha: 0.5);
                      statusIcon = const Icon(Icons.cancel, color: Colors.red, size: 12);
                    }
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
                            if (statusIcon != null && !isCurrentQuestion)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: statusIcon,
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

  TestAnswer? _getUserAnswerForQuestion(String questionId) {
    try {
      return testResult.answers.firstWhere(
        (answer) => answer.questionId == questionId,
      );
    } catch (e) {
      return null;
    }
  }

  static void show(
    BuildContext context,
    TestResult testResult,
    int currentQuestionIndex,
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
      builder: (context) => TestReviewQuestionNavigationSheet(
        testResult: testResult,
        currentQuestionIndex: currentQuestionIndex,
        languageCubit: languageCubit,
        onQuestionSelected: onQuestionSelected,
      ),
    );
  }
}