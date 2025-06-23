import 'dart:developer' as dev;
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';


class StartTestSessionParams extends Equatable {
  final String testId;

  const StartTestSessionParams({
    required this.testId,
  });

  @override
  List<Object?> get props => [testId];
}

class TestSessionStartResult extends Equatable {
  final TestSession session;
  final TestItem test;
  final bool wasViewed;

  const TestSessionStartResult({
    required this.session,
    required this.test,
    required this.wasViewed,
  });

  @override
  List<Object?> get props => [session, test, wasViewed];
}

class StartTestSessionUseCase implements UseCase<TestSessionStartResult, StartTestSessionParams> {
  final TestsRepository repository;
  final AuthService authService;

  StartTestSessionUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<TestSessionStartResult>> execute(StartTestSessionParams params) async {
    try {
      dev.log('StartTestSessionUseCase: Starting test session for test ${params.testId}');

      // Business Rule: Must be authenticated to start a test
      final user = authService.getCurrentUser();
      if (user == null) {
        dev.log('StartTestSessionUseCase: User not authenticated');
        return ApiResult.failure(
          'You must be logged in to take a test',
          FailureType.auth,
        );
      }

      // Business Rule: Validate test ID
      if (params.testId.isEmpty) {
        return ApiResult.failure(
          'Test ID cannot be empty',
          FailureType.validation,
        );
      }

      // Business Rule: Load test details
      final testResult = await repository.getTestById(params.testId);
      
      return testResult.fold(
        onSuccess: (test) async {
          if (test == null) {
            dev.log('StartTestSessionUseCase: Test ${params.testId} not found');
            return ApiResult.failure(
              'Test not found',
              FailureType.notFound,
            );
          }

          // Business Rule: Validate test can be started
          final validationResult = _validateTestForSession(test);
          if (validationResult != null) {
            return ApiResult.failure(validationResult, FailureType.validation);
          }

          // Business Rule: Check if user has previous interaction
          bool wasViewed = false;
          try {
            final interactionResult = await repository.getUserTestInteraction(params.testId, user.uid);
            wasViewed = interactionResult.fold(
              onSuccess: (interaction) => interaction?.hasViewed ?? false,
              onFailure: (_, __) => false,
            );
          } catch (e) {
            dev.log('StartTestSessionUseCase: Could not check previous interaction - $e');
          }

          // Business Rule: Record test view
          try {
            await repository.recordTestView(params.testId, user.uid);
            dev.log('StartTestSessionUseCase: Recorded test view for user ${user.uid}');
          } catch (e) {
            dev.log('StartTestSessionUseCase: Failed to record test view - $e');
            // Continue anyway - this is not critical
          }

          // Business Rule: Create test session
          final session = TestSession(
            test: test,
            userId: user.uid,
            answers: {},
            currentQuestionIndex: 0,
            startTime: DateTime.now(),
            timeRemaining: test.timeLimit > 0 ? test.timeLimit * 60 : null,
            questionStartTime: DateTime.now(),
          );

          dev.log('StartTestSessionUseCase: Successfully created test session for ${test.title}');

          return ApiResult.success(TestSessionStartResult(
            session: session,
            test: test,
            wasViewed: wasViewed,
          ));
        },
        onFailure: (message, type) {
          dev.log('StartTestSessionUseCase: Failed to load test - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      dev.log('StartTestSessionUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to start test session: $e', FailureType.unknown);
    }
  }

  String? _validateTestForSession(TestItem test) {
    // Business Rule: Test must have questions
    if (test.questions.isEmpty) {
      dev.log('StartTestSessionUseCase: Test has no questions');
      return 'This test has no questions and cannot be started';
    }

    // Business Rule: Test must be published (if you have this field)
    if (!test.isPublished) {
      dev.log('StartTestSessionUseCase: Test is not published');
      return 'This test is not published and cannot be started';
    }

    // Business Rule: Validate question structure
    for (int i = 0; i < test.questions.length; i++) {
      final question = test.questions[i];
      
      if (question.question.isEmpty) {
        dev.log('StartTestSessionUseCase: Question $i has empty text');
        return 'Test contains invalid questions and cannot be started';
      }

      if (question.options.isEmpty) {
        dev.log('StartTestSessionUseCase: Question $i has no options');
        return 'Test contains questions without answer options';
      }

      if (question.correctAnswerIndex < 0 || question.correctAnswerIndex >= question.options.length) {
        dev.log('StartTestSessionUseCase: Question $i has invalid correct answer index');
        return 'Test contains questions with invalid correct answers';
      }
    }

    // Business Rule: Validate time limits are reasonable
    if (test.timeLimit < 0) {
      dev.log('StartTestSessionUseCase: Test has negative time limit');
      return 'Test has invalid time limit';
    }

    // Business Rule: Validate passing score
    if (test.passingScore < 0 || test.passingScore > 100) {
      dev.log('StartTestSessionUseCase: Test has invalid passing score');
      return 'Test has invalid passing score';
    }

    return null; // Test is valid
  }
}