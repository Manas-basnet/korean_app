import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class EmptyTestsView extends StatelessWidget {
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onCreateTest;

  const EmptyTestsView({
    super.key,
    required this.languageCubit,
    required this.onCreateTest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    
    return Container(
      width: double.infinity,
      height: screenSize.height * 0.6,
      padding: EdgeInsets.all(screenSize.width * 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: screenSize.width * 0.2,
            height: screenSize.width * 0.2,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_outlined,
              size: screenSize.width * 0.1,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: screenSize.height * 0.03),
          Text(
            languageCubit.getLocalizedText(
              korean: '시험이 없습니다',
              english: 'No tests available',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: screenSize.width * 0.05,
            ),
          ),
          SizedBox(height: screenSize.height * 0.015),
          Text(
            languageCubit.getLocalizedText(
              korean: '새 시험을 만들려면 + 버튼을 누르세요',
              english: 'Tap the + button to create a new test',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: screenSize.width * 0.035,
            ),
          ),
          SizedBox(height: screenSize.height * 0.04),
          FilledButton.icon(
            onPressed: onCreateTest,
            icon: const Icon(Icons.add),
            label: Text(
              languageCubit.getLocalizedText(
                korean: '시험 만들기',
                english: 'Create Test',
              ),
            ),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.06,
                vertical: screenSize.height * 0.015,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}