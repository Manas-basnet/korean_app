import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/shared/models/test_answer.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/models/test_result.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/features/tests/domain/usecases/complete_test_session_usecase.dart';

part 'test_session_state.dart';

class TestSessionCubit extends Cubit<TestSessionState> {
  final CompleteTestSessionUseCase completeTestSessionUseCase;
  final TestsRepository testsRepository;
  final AuthService authService;
  
  Timer? _testTimer;
  Timer? _questionTimer;
  
  TestSessionCubit({
    required this.completeTestSessionUseCase, 
    required this.testsRepository,
    required this.authService,
  }) : super(const TestSessionInitial());

  void startTest(TestItem test) {
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const TestSessionError('User not authenticated', FailureType.auth));
        return;
      }

      final session = TestSession(
        test: test,
        userId: user.uid,
        answers: {},
        currentQuestionIndex: 0,
        startTime: DateTime.now(),
        questionStartTime: DateTime.now(),
        timeRemaining: test.timeLimit > 0 ? test.timeLimit * 60 : null,
      );

      emit(TestSessionInProgress(session));
      
      if (test.timeLimit > 0) {
        _startTestTimer(test.timeLimit * 60);
      }
      
      final currentQuestion = test.questions[0];
      if (currentQuestion.timeLimit > 0) {
        _startQuestionTimer(currentQuestion.timeLimit);
      }
      
      debugPrint('Started test: ${test.title} for user: ${user.uid}');
    } catch (e) {
      emit(TestSessionError('Failed to start test: $e', FailureType.unknown));
    }
  }

  void answerQuestion(int selectedAnswerIndex) {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      final session = currentState.session;
      final currentQuestion = session.test.questions[session.currentQuestionIndex];
      
      final timeSpent = _calculateQuestionTimeSpent(session);
      
      final answer = TestAnswer(
        questionId: currentQuestion.id,
        selectedAnswerIndex: selectedAnswerIndex,
        isCorrect: selectedAnswerIndex == currentQuestion.correctAnswerIndex,
        timeSpent: timeSpent,
      );

      final updatedAnswers = Map<String, TestAnswer>.from(session.answers);
      updatedAnswers[currentQuestion.id] = answer;

      final updatedSession = session.copyWith(
        answers: updatedAnswers,
        lastAnswerTime: DateTime.now(),
      );

      emit(TestSessionInProgress(updatedSession));
      
      debugPrint('Answered question ${session.currentQuestionIndex + 1}: ${answer.isCorrect ? 'Correct' : 'Incorrect'}');
    } catch (e) {
      emit(TestSessionError('Failed to answer question: $e', FailureType.unknown));
    }
  }

  void nextQuestion() {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      final session = currentState.session;
      
      if (session.currentQuestionIndex < session.test.questions.length - 1) {
        final nextIndex = session.currentQuestionIndex + 1;
        final updatedSession = session.copyWith(
          currentQuestionIndex: nextIndex,
          questionStartTime: DateTime.now(),
        );

        emit(TestSessionInProgress(updatedSession));
        
        _questionTimer?.cancel();
        
        final nextQuestion = session.test.questions[nextIndex];
        if (nextQuestion.timeLimit > 0) {
          _startQuestionTimer(nextQuestion.timeLimit);
        }
        
        debugPrint('Moved to question ${nextIndex + 1}/${session.test.questions.length}');
      } else {
        // Last question reached - don't auto-complete, wait for user to finish
        debugPrint('Reached last question, waiting for user to finish manually');
      }
    } catch (e) {
      emit(TestSessionError('Failed to proceed to next question: $e', FailureType.unknown));
    }
  }

  void previousQuestion() {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      final session = currentState.session;
      
      if (session.currentQuestionIndex > 0) {
        final prevIndex = session.currentQuestionIndex - 1;
        final updatedSession = session.copyWith(
          currentQuestionIndex: prevIndex,
          questionStartTime: DateTime.now(),
        );

        emit(TestSessionInProgress(updatedSession));
        
        _questionTimer?.cancel();
        
        final prevQuestion = session.test.questions[prevIndex];
        if (prevQuestion.timeLimit > 0) {
          _startQuestionTimer(prevQuestion.timeLimit);
        }
        
        debugPrint('Moved back to question ${prevIndex + 1}/${session.test.questions.length}');
      }
    } catch (e) {
      emit(TestSessionError('Failed to go to previous question: $e', FailureType.unknown));
    }
  }

  void goToQuestion(int questionIndex) {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      final session = currentState.session;
      
      if (questionIndex >= 0 && questionIndex < session.test.questions.length) {
        final updatedSession = session.copyWith(
          currentQuestionIndex: questionIndex,
          questionStartTime: DateTime.now(),
        );

        emit(TestSessionInProgress(updatedSession));
        
        _questionTimer?.cancel();
        
        final question = session.test.questions[questionIndex];
        if (question.timeLimit > 0) {
          _startQuestionTimer(question.timeLimit);
        }
        
        debugPrint('Jumped to question ${questionIndex + 1}/${session.test.questions.length}');
      }
    } catch (e) {
      emit(TestSessionError('Failed to go to question: $e', FailureType.unknown));
    }
  }

  Future<void> completeTestWithRating(double? rating) async {
    await _completeTest(rating, isManualCompletion: true);
  }

  Future<void> completeTestAutomatically() async {
    await _completeTest(null, isManualCompletion: false);
  }

  Future<void> _completeTest(double? rating, {required bool isManualCompletion}) async {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      emit(const TestSessionSubmitting());
      
      _testTimer?.cancel();
      _questionTimer?.cancel();
      
      final session = currentState.session;
      
      debugPrint('Completing test session using use case (manual: $isManualCompletion, rating: $rating)...');
      
      final result = await completeTestSessionUseCase.execute(
        CompleteTestSessionParams(session: session, rating: rating)
      );
      
      result.fold(
        onSuccess: (completionResult) {
          debugPrint('Test session completed successfully');
          if (!isClosed) {
            emit(TestSessionCompleted(
              completionResult.testResult,
              shouldShowRating: false, // Always false since rating is handled in UI layer
            ));
          }
        },
        onFailure: (message, type) {
          debugPrint('Failed to complete test session: $message');
          if (!isClosed) {
            emit(TestSessionError('Failed to complete test: $message', type));
          }
        },
      );
      
    } catch (e) {
      debugPrint('Error completing test: $e');
      if (!isClosed) {
        emit(TestSessionError('Failed to complete test: $e', FailureType.unknown));
      }
    }
  }

  Future<double?> getExistingRating(String testId) async {
    final user = _getCurrentUser();
    if (user == null) return null;

    try {
      final result = await testsRepository.getUserTestInteraction(testId, user.uid);
      return result.fold(
        onSuccess: (interaction) => interaction?.rating,
        onFailure: (_, __) => null,
      );
    } catch (e) {
      debugPrint('Failed to get existing rating: $e');
      return null;
    }
  }

  void pauseTest() {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      _testTimer?.cancel();
      _questionTimer?.cancel();
      
      final session = currentState.session;
      final updatedSession = session.copyWith(isPaused: true);
      
      emit(TestSessionPaused(updatedSession));
      debugPrint('Test paused');
    } catch (e) {
      emit(TestSessionError('Failed to pause test: $e', FailureType.unknown));
    }
  }

  void resumeTest() {
    final currentState = state;
    if (currentState is! TestSessionPaused) return;

    try {
      final session = currentState.session;
      final updatedSession = session.copyWith(
        isPaused: false,
        questionStartTime: DateTime.now(),
      );
      
      emit(TestSessionInProgress(updatedSession));
      
      if (session.timeRemaining != null && session.timeRemaining! > 0) {
        _startTestTimer(session.timeRemaining!);
      }
      
      final currentQuestion = session.test.questions[session.currentQuestionIndex];
      if (currentQuestion.timeLimit > 0) {
        _startQuestionTimer(currentQuestion.timeLimit);
      }
      
      debugPrint('Test resumed');
    } catch (e) {
      emit(TestSessionError('Failed to resume test: $e', FailureType.unknown));
    }
  }

  void cancelTest() {
    try {
      _testTimer?.cancel();
      _questionTimer?.cancel();
      
      emit(const TestSessionInitial());
      debugPrint('Test cancelled');
    } catch (e) {
      emit(TestSessionError('Failed to cancel test: $e', FailureType.unknown));
    }
  }

  void _startTestTimer(int seconds) {
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentState = state;
      if (currentState is! TestSessionInProgress) {
        timer.cancel();
        return;
      }

      final session = currentState.session;
      if (session.timeRemaining == null) {
        timer.cancel();
        return;
      }

      final newTimeRemaining = session.timeRemaining! - 1;
      
      if (newTimeRemaining <= 0) {
        timer.cancel();
        debugPrint('Test time expired, completing automatically');
        completeTestAutomatically();
      } else {
        final updatedSession = session.copyWith(timeRemaining: newTimeRemaining);
        emit(TestSessionInProgress(updatedSession));
      }
    });
  }

  void _startQuestionTimer(int seconds) {
    _questionTimer = Timer(Duration(seconds: seconds), () {
      nextQuestion();
    });
  }

  int _calculateQuestionTimeSpent(TestSession session) {
    if (session.questionStartTime == null) return 0;
    
    final now = DateTime.now();
    return now.difference(session.questionStartTime!).inSeconds;
  }

  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }

  @override
  Future<void> close() {
    _testTimer?.cancel();
    _questionTimer?.cancel();
    return super.close();
  }
}