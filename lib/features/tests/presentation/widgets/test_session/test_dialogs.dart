import 'package:flutter/material.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

class TestDialogs {
  static void showExitConfirmation(
    BuildContext context,
    LanguagePreferenceCubit languageCubit,
    VoidCallback onExit,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          languageCubit.getLocalizedText(korean: '시험 종료', english: 'Exit Test'),
        ),
        content: Text(
          languageCubit.getLocalizedText(
            korean: '시험을 종료하시겠습니까? 진행 상황이 저장되지 않습니다.',
            english: 'Exit the test? Your progress will not be saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageCubit.getLocalizedText(korean: '계속하기', english: 'Continue')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onExit();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(languageCubit.getLocalizedText(korean: '종료', english: 'Exit')),
          ),
        ],
      ),
    );
  }

  static void showFinishConfirmation(
    BuildContext context,
    LanguagePreferenceCubit languageCubit,
    TestSession session,
    VoidCallback onFinish,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          languageCubit.getLocalizedText(korean: '시험 완료', english: 'Finish Test'),
        ),
        content: Text(
          languageCubit.getLocalizedText(
            korean: '정말로 시험을 완료하시겠습니까?\n답변: ${session.answeredQuestionsCount}/${session.totalQuestions}',
            english: 'Are you sure you want to finish?\nAnswered: ${session.answeredQuestionsCount}/${session.totalQuestions}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageCubit.getLocalizedText(korean: '취소', english: 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onFinish();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: Text(languageCubit.getLocalizedText(korean: '완료', english: 'Finish')),
          ),
        ],
      ),
    );
  }
}