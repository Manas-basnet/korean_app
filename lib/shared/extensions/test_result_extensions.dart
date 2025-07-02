import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

extension TestResultLocalization on TestResult {
  String getFormattedDuration(LanguagePreferenceCubit languageCubit) {
    final duration = totalDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    final minutesText = languageCubit.getLocalizedText(
      korean: '분',
      english: 'min',
    );
    
    final secondsText = languageCubit.getLocalizedText(
      korean: '초',
      english: 'sec',
    );
    
    return '$minutes$minutesText $seconds$secondsText';
  }
  
  String getResultSummary(LanguagePreferenceCubit languageCubit) {
    return '$correctAnswers/$totalQuestions ($formattedScore)';
  }
}