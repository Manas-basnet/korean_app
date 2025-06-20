import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/features/test_results/domain/repositories/test_results_repository.dart';
import 'package:korean_language_app/shared/models/test_answer.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/models/test_result.dart';

part 'test_session_state.dart';

class TestSessionCubit extends Cubit<TestSessionState> {
  final TestResultsRepository testResultsRepository;
  final AuthService authService;
  
  Timer? _testTimer;
  Timer? _questionTimer;
  
  TestSessionCubit({
    required this.testResultsRepository,
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
      
      dev.log('Started test: ${test.title} for user: ${user.uid}');
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
      
      dev.log('Answered question ${session.currentQuestionIndex + 1}: ${answer.isCorrect ? 'Correct' : 'Incorrect'}');
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
        
        dev.log('Moved to question ${nextIndex + 1}/${session.test.questions.length}');
      } else {
        _completeTest();
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
        
        dev.log('Moved back to question ${prevIndex + 1}/${session.test.questions.length}');
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
        
        dev.log('Jumped to question ${questionIndex + 1}/${session.test.questions.length}');
      }
    } catch (e) {
      emit(TestSessionError('Failed to go to question: $e', FailureType.unknown));
    }
  }

  Future<void> completeTest() async {
    await _completeTest();
  }

  Future<void> _completeTest() async {
    final currentState = state;
    if (currentState is! TestSessionInProgress) return;

    try {
      emit(const TestSessionSubmitting());
      
      _testTimer?.cancel();
      _questionTimer?.cancel();
      
      final session = currentState.session;
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
      
      dev.log('Test completed - Score: $score%, Passed: $isPassed. Attempting to save...');
      
      try {
        final result = await testResultsRepository.saveTestResult(testResult);
        
        result.fold(
          onSuccess: (success) {
            dev.log('Test result saved successfully');
            if (!isClosed) {
              emit(TestSessionCompleted(testResult));
            }
          },
          onFailure: (message, type) {
            dev.log('Failed to save test result: $message');
            if (!isClosed) {
              emit(TestSessionCompleted(testResult));
            }
          },
        );
      } catch (saveError) {
        dev.log('Error saving test result: $saveError, but test is completed');
        if (!isClosed) {
          emit(TestSessionCompleted(testResult));
        }
      }
      
    } catch (e) {
      dev.log('Error completing test: $e');
      if (!isClosed) {
        emit(TestSessionError('Failed to complete test: $e', FailureType.unknown));
      }
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
      dev.log('Test paused');
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
      
      dev.log('Test resumed');
    } catch (e) {
      emit(TestSessionError('Failed to resume test: $e', FailureType.unknown));
    }
  }

  void cancelTest() {
    try {
      _testTimer?.cancel();
      _questionTimer?.cancel();
      
      emit(const TestSessionInitial());
      dev.log('Test cancelled');
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
        _completeTest();
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
    if (kDebugMode) {
      print('Closing TestSessionCubit...');
    }
    _testTimer?.cancel();
    _questionTimer?.cancel();
    return super.close();
  }
}