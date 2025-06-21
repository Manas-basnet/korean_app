import 'dart:developer' as dev;
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/save_test_result_usecase.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_results.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/shared/models/test_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class CompleteTestSessionUseCase implements UseCase<CompleteTestSessionResult, CompleteTestSessionParams> {
  final SaveTestResultUseCase saveTestResultUseCase;
  final AuthService authService;

  CompleteTestSessionUseCase({
    required this.saveTestResultUseCase,
    required this.authService,
  });

  @override
  Future<ApiResult<CompleteTestSessionResult>> execute(CompleteTestSessionParams params) async {
    try {
      dev.log('CompleteTestSessionUseCase: Completing test session for ${params.session.test.title}');

      final user = authService.getCurrentUser();
      if (user == null) {
        return ApiResult.failure('User not authenticated', FailureType.auth);
      }

      if (params.session.userId != user.uid) {
        return ApiResult.failure('Session user mismatch', FailureType.auth);
      }

      final session = params.session;
      final completedAt = DateTime.now();
      final totalTimeSpent = completedAt.difference(session.startTime).inSeconds;
      
      final correctAnswers = session.answers.values.where((a) => a.isCorrect).length;
      final totalQuestions = session.test.questions.length;
      final score = totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100).round() : 0;
      final isPassed = score >= session.test.passingScore;
      
      final testResult = TestResult(
        id: '',
        testId: session.test.id,
        userId: session.userId,
        testTitle: session.test.title,
        testDescription: session.test.description,
        testQuestions: session.test.questions,
        answers: session.answers.values.toList(),
        score: score,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        totalTimeSpent: totalTimeSpent,
        isPassed: isPassed,
        startedAt: session.startTime,
        completedAt: completedAt,
        metadata: {
          'testVersion': session.test.updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          'sessionDuration': totalTimeSpent,
          'averageTimePerQuestion': totalQuestions > 0 ? totalTimeSpent / totalQuestions : 0,
        },
      );
      
      dev.log('CompleteTestSessionUseCase: Test completed - Score: $score%, Passed: $isPassed');

      final saveResult = await saveTestResultUseCase.execute(testResult);
      
      final shouldShowRating = _shouldShowRatingDialog(session);
      
      final result = CompleteTestSessionResult(
        testResult: testResult,
        shouldShowRating: shouldShowRating,
      );

      return saveResult.fold(
        onSuccess: (_) {
          dev.log('CompleteTestSessionUseCase: Test result saved successfully');
          return ApiResult.success(result);
        },
        onFailure: (message, type) {
          dev.log('CompleteTestSessionUseCase: Failed to save result but test completed: $message');
          return ApiResult.success(result);
        },
      );

    } catch (e) {
      dev.log('CompleteTestSessionUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to complete test session: $e', FailureType.unknown);
    }
  }

  bool _shouldShowRatingDialog(TestSession session) {
    final completionCount = session.answers.length;
    final totalQuestions = session.test.questions.length;
    
    if (completionCount < totalQuestions * 0.5) {
      return false;
    }
    
    return true;
  }
}