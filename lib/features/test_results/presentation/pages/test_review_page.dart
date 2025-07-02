import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/features/test_results/presentation/widgets/test_review_landscape_mode_widget.dart';
import 'package:korean_language_app/features/test_results/presentation/widgets/test_review_portrait_mode_widget.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_answer.dart';


class TestReviewPage extends StatefulWidget {
  final TestResult testResult;

  const TestReviewPage({super.key, required this.testResult});

  @override
  State<TestReviewPage> createState() => _TestReviewPageState();
}

class _TestReviewPageState extends State<TestReviewPage>
    with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  bool _isLandscape = false;
  late AnimationController _slideAnimationController;
  late Animation<double> _slideAnimation;

  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideAnimationController.forward();
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.testResult.testQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _slideAnimationController.reset();
      _slideAnimationController.forward();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _slideAnimationController.reset();
      _slideAnimationController.forward();
    }
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < widget.testResult.testQuestions.length) {
      setState(() {
        _currentQuestionIndex = index;
      });
      Navigator.of(context).pop();
      _slideAnimationController.reset();
      _slideAnimationController.forward();
    }
  }

  TestAnswer? _getUserAnswerForQuestion(String questionId) {
    try {
      return widget.testResult.answers.firstWhere(
        (answer) => answer.questionId == questionId,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.testResult.testQuestions[_currentQuestionIndex];
    final userAnswer = _getUserAnswerForQuestion(question.id);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLandscape 
            ? TestReviewLandscapeModeWidget(
                testResult: widget.testResult,
                currentQuestionIndex: _currentQuestionIndex,
                question: question,
                userAnswer: userAnswer,
                languageCubit: _languageCubit,
                onExitPressed: () => Navigator.of(context).pop(),
                onToggleOrientation: _toggleOrientation,
                onPreviousQuestion: _previousQuestion,
                onNextQuestion: _nextQuestion,
                onJumpToQuestion: _goToQuestion,
              )
            : TestReviewPortraitModeWidget(
                testResult: widget.testResult,
                currentQuestionIndex: _currentQuestionIndex,
                question: question,
                userAnswer: userAnswer,
                slideAnimation: _slideAnimation,
                languageCubit: _languageCubit,
                onExitPressed: () => Navigator.of(context).pop(),
                onToggleOrientation: _toggleOrientation,
                onPreviousQuestion: _previousQuestion,
                onNextQuestion: _nextQuestion,
                onJumpToQuestion: _goToQuestion,
              ),
      ),
    );
  }
}