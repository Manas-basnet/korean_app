import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/test_portrait_mode_widget.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/test_landscape_mode_widget.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/test_dialogs.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/tests_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_rating_dialog.dart';

class TestTakingPage extends StatefulWidget {
  final String testId;

  const TestTakingPage({super.key, required this.testId});

  @override
  State<TestTakingPage> createState() => _TestTakingPageState();
}

class _TestTakingPageState extends State<TestTakingPage>
    with TickerProviderStateMixin {
  int? _selectedAnswerIndex;
  bool _showingExplanation = false;
  bool _isLandscape = false;
  late AnimationController _slideAnimationController;
  late Animation<double> _slideAnimation;
  bool _isNavigatingToResult = false;

  TestSessionCubit get _sessionCubit => context.read<TestSessionCubit>();
  TestsCubit get _testsCubit => context.read<TestsCubit>();
  LanguagePreferenceCubit get _languageCubit =>
      context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndStartTest();
    });
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

  Future<void> _loadAndStartTest() async {
    final testsState = _testsCubit.state;
    
    if (testsState.selectedTest != null && testsState.selectedTest!.id == widget.testId) {
      _sessionCubit.startTest(testsState.selectedTest!);
      _slideAnimationController.forward();
    } else {
      _snackBarCubit.showErrorLocalized(
        korean: '시험 데이터를 찾을 수 없습니다',
        english: 'Test data not found',
      );
      if (mounted) {
        context.pop();
      }
    }
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

  void _selectAnswer(int index) {
    if (_selectedAnswerIndex == index) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedAnswerIndex = index;
    });

    _sessionCubit.answerQuestion(index);
  }

  void _nextQuestion() {
    setState(() {
      _selectedAnswerIndex = null;
      _showingExplanation = false;
    });
    
    _slideAnimationController.reset();
    _sessionCubit.nextQuestion();
    _slideAnimationController.forward();
  }

  void _previousQuestion() {
    setState(() {
      _selectedAnswerIndex = null;
      _showingExplanation = false;
    });
    
    _slideAnimationController.reset();
    _sessionCubit.previousQuestion();
    _slideAnimationController.forward();
  }

  void _jumpToQuestion(int questionIndex) {
    setState(() {
      _selectedAnswerIndex = null;
      _showingExplanation = false;
    });
    
    _slideAnimationController.reset();
    _sessionCubit.goToQuestion(questionIndex);
    _slideAnimationController.forward();
    Navigator.pop(context);
  }

  void _toggleExplanation() {
    setState(() {
      _showingExplanation = !_showingExplanation;
    });
  }

  Future<void> _handleTestCompleted(TestSessionCompleted state) async {
    if (!_isNavigatingToResult) {
      _isNavigatingToResult = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.pushReplacement('/test-result', extra: state.result);
        }
      });
    }
  }

  Future<void> _showRatingDialogAndCompleteTest(String testTitle, String testId) async {
    double? existingRating;
    try {
      existingRating = await _sessionCubit.getExistingRating(testId);
    } catch (e) {
      existingRating = null;
    }

    if (!mounted) return;

    final rating = await TestRatingDialogHelper.showRatingDialog(
      context,
      testTitle: testTitle,
      existingRating: existingRating,
    );
    
    _sessionCubit.completeTestWithRating(rating);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TestSessionCubit, TestSessionState>(
      listener: (context, state) {
        if (state is TestSessionCompleted) {
          _handleTestCompleted(state);
        } else if (state is TestSessionError && !_isNavigatingToResult) {
          _snackBarCubit.showErrorLocalized(
            korean: state.error ?? '오류가 발생했습니다',
            english: state.error ?? 'An error occurred',
          );
        }
      },
      builder: (context, state) {
        if (state is TestSessionInitial) {
          return _buildLoadingScreen();
        }

        if (state is TestSessionInProgress || state is TestSessionPaused) {
          final session = state is TestSessionInProgress
              ? state.session
              : (state as TestSessionPaused).session;
          return _buildTestScreen(session, state is TestSessionPaused);
        }

        if (state is TestSessionSubmitting || state is TestSessionCompleted) {
          return _buildSubmittingScreen();
        }

        if (state is TestSessionError) {
          return _buildErrorScreen();
        }

        return _buildLoadingScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _languageCubit.getLocalizedText(
                korean: '시험을 준비하고 있습니다...',
                english: 'Preparing your test...',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittingScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_rounded,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _languageCubit.getLocalizedText(
                korean: '답안을 제출하고 있습니다...',
                english: 'Submitting your answers...',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _languageCubit.getLocalizedText(
                  korean: '오류가 발생했습니다',
                  english: 'Something went wrong',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  _languageCubit.getLocalizedText(
                    korean: '돌아가기',
                    english: 'Go Back',
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestScreen(TestSession session, bool isPaused) {
    final question = session.test.questions[session.currentQuestionIndex];
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLandscape 
            ? TestLandscapeModeWidget(
                session: session,
                question: question,
                isPaused: isPaused,
                languageCubit: _languageCubit,
                selectedAnswerIndex: _selectedAnswerIndex,
                showingExplanation: _showingExplanation,
                onExitPressed: () => TestDialogs.showExitConfirmation(
                  context,
                  _languageCubit,
                  () => context.pop(),
                ),
                onToggleOrientation: _toggleOrientation,
                onToggleExplanation: _toggleExplanation,
                onAnswerSelected: _selectAnswer,
                onPreviousQuestion: _previousQuestion,
                onNextQuestion: _nextQuestion,
                onShowRatingDialog: _showRatingDialogAndCompleteTest,
                onJumpToQuestion: _jumpToQuestion,
              )
            : TestPortraitModeWidget(
                session: session,
                question: question,
                isPaused: isPaused,
                slideAnimation: _slideAnimation,
                languageCubit: _languageCubit,
                selectedAnswerIndex: _selectedAnswerIndex,
                showingExplanation: _showingExplanation,
                isLandscape: _isLandscape,
                onExitPressed: () => TestDialogs.showExitConfirmation(
                  context,
                  _languageCubit,
                  () => context.pop(),
                ),
                onToggleOrientation: _toggleOrientation,
                onToggleExplanation: _toggleExplanation,
                onAnswerSelected: _selectAnswer,
                onPreviousQuestion: _previousQuestion,
                onNextQuestion: _nextQuestion,
                onShowRatingDialog: _showRatingDialogAndCompleteTest,
                onJumpToQuestion: _jumpToQuestion,
              ),
      ),
    );
  }
}