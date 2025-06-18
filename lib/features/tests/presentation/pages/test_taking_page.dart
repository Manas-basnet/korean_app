import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/enums/question_type.dart';
import 'package:korean_language_app/core/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/core/shared/models/test_question.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/tests_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_audio.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

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
  Timer? _autoAdvanceTimer;
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
    _autoAdvanceTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadAndStartTest() async {
    try {
      await _testsCubit.loadTestById(widget.testId);

      final testsState = _testsCubit.state;
      if (testsState.selectedTest != null) {
        _sessionCubit.startTest(testsState.selectedTest!);
        _slideAnimationController.forward();
      } else {
        _snackBarCubit.showErrorLocalized(
          korean: '시험을 찾을 수 없습니다',
          english: 'Test not found',
        );
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '시험을 불러오는 중 오류가 발생했습니다',
        english: 'Error loading test',
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

    final currentState = _sessionCubit.state;
    if (currentState is TestSessionInProgress) {
      final session = currentState.session;
      final isLastQuestion = session.currentQuestionIndex == session.totalQuestions - 1;
      
      if (!isLastQuestion) {
        _autoAdvanceTimer?.cancel();
        _autoAdvanceTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) _nextQuestion();
        });
      }
    }
  }

  void _nextQuestion() {
    _autoAdvanceTimer?.cancel();
    setState(() {
      _selectedAnswerIndex = null;
      _showingExplanation = false;
    });
    
    _slideAnimationController.reset();
    _sessionCubit.nextQuestion();
    _slideAnimationController.forward();
  }

  void _previousQuestion() {
    _autoAdvanceTimer?.cancel();
    setState(() {
      _selectedAnswerIndex = null;
      _showingExplanation = false;
    });
    
    _slideAnimationController.reset();
    _sessionCubit.previousQuestion();
    _slideAnimationController.forward();
  }

  void _jumpToQuestion(int questionIndex) {
    _autoAdvanceTimer?.cancel();
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

  void _showQuestionNavigation(TestSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuestionNavigationSheet(session),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TestSessionCubit, TestSessionState>(
      listener: (context, state) {
        if (state is TestSessionCompleted && !_isNavigatingToResult) {
          _isNavigatingToResult = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.pushReplacement(Routes.testResult, extra: state.result);
            }
          });
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
                color: colorScheme.primaryContainer.withOpacity(0.1),
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
                color: colorScheme.primaryContainer.withOpacity(0.1),
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
                  color: colorScheme.errorContainer.withOpacity(0.1),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: _isLandscape 
            ? _buildLandscapeLayout(session, question, isPaused)
            : _buildPortraitLayout(session, question, isPaused),
      ),
    );
  }

  Widget _buildLandscapeLayout(TestSession session, TestQuestion question, bool isPaused) {
    final savedAnswer = session.getAnswerForQuestion(session.currentQuestionIndex);
    
    return Column(
      children: [
        _buildCompactHeader(session, isPaused),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildLandscapeQuestionContent(question),
                      ),
                      if (_showingExplanation && question.explanation != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: _buildExplanationCard(question.explanation!, isCompact: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 16),
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
              
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _languageCubit.getLocalizedText(korean: '답안 선택', english: 'Choose Answer'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: question.options.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final option = question.options[index];
                            return _buildAnswerOption(index, option, question, savedAnswer, session, isCompact: true);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLandscapeNavigation(session),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeQuestionContent(TestQuestion question) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = (question.questionImageUrl?.isNotEmpty == true) || 
                     (question.questionImagePath?.isNotEmpty == true);
    final hasAudio = (question.questionAudioUrl?.isNotEmpty == true) || 
                     (question.questionAudioPath?.isNotEmpty == true);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage)
          Expanded(
            flex: hasImage && question.question.isNotEmpty ? 3 : 1,
            child: _buildQuestionImage(
              question.questionImageUrl, 
              question.questionImagePath, 
              isLandscape: true,
              isFixed: true,
            ),
          ),
        
        if (hasAudio) ...[
          const SizedBox(height: 12),
          CustomCachedAudio(
            audioUrl: question.questionAudioUrl,
            audioPath: question.questionAudioPath,
            label: _languageCubit.getLocalizedText(
              korean: '문제 듣기',
              english: 'Listen to Question',
            ),
            height: 50,
          ),
        ],
        
        if (question.question.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  question.question,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: hasImage || hasAudio ? 3 : 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPortraitLayout(TestSession session, TestQuestion question, bool isPaused) {
    return Column(
      children: [
        _buildTestHeader(session, isPaused),
        Expanded(
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                child: Opacity(
                  opacity: _slideAnimation.value,
                  child: _buildQuestionContent(session, question),
                ),
              );
            },
          ),
        ),
        _buildTestNavigation(session),
      ],
    );
  }

  Widget _buildCompactHeader(TestSession session, bool isPaused) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitConfirmation(),
            icon: const Icon(Icons.close_rounded, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurfaceVariant,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.test.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${session.currentQuestionIndex + 1}/${session.totalQuestions}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: session.progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildHeaderActions(session, isPaused),
        ],
      ),
    );
  }

  Widget _buildTestHeader(TestSession session, bool isPaused) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _showExitConfirmation(),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.test.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _languageCubit.getLocalizedText(
                        korean: '${session.currentQuestionIndex + 1}/${session.totalQuestions}',
                        english: '${session.currentQuestionIndex + 1} of ${session.totalQuestions}',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(session, isPaused),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(session),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(TestSession session, bool isPaused) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToggleButtons(
          isSelected: [!_isLandscape, _isLandscape],
          onPressed: (index) => _toggleOrientation(),
          borderRadius: BorderRadius.circular(8),
          selectedColor: colorScheme.onPrimary,
          fillColor: colorScheme.primary,
          color: colorScheme.onSurfaceVariant,
          constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
          borderColor: Colors.transparent,
          selectedBorderColor: Colors.transparent,
          children: const [
            Icon(Icons.stay_current_portrait_rounded, size: 16),
            Icon(Icons.stay_current_landscape_rounded, size: 16),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _showQuestionNavigation(session),
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: _languageCubit.getLocalizedText(korean: '문제 목록', english: 'Question List'),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _toggleExplanation,
          icon: Icon(_showingExplanation ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: _showingExplanation 
                ? colorScheme.primary.withOpacity(0.1) 
                : colorScheme.surfaceContainerHighest,
            foregroundColor: _showingExplanation 
                ? colorScheme.primary 
                : colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: _languageCubit.getLocalizedText(korean: '해설', english: 'Explanation'),
        ),
        if (session.hasTimeLimit) ...[
          const SizedBox(width: 8),
          _buildTimeDisplay(session, isPaused),
        ],
      ],
    );
  }

  Widget _buildTimeDisplay(TestSession session, bool isPaused) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLowTime = session.timeRemaining != null && session.timeRemaining! < 300;
    
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    if (isPaused) {
      backgroundColor = colorScheme.tertiary.withOpacity(0.1);
      textColor = colorScheme.tertiary;
      icon = Icons.pause_rounded;
    } else if (isLowTime) {
      backgroundColor = colorScheme.errorContainer.withOpacity(0.3);
      textColor = colorScheme.error;
      icon = Icons.timer_outlined;
    } else {
      backgroundColor = colorScheme.primaryContainer.withOpacity(0.3);
      textColor = colorScheme.primary;
      icon = Icons.timer_outlined;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            isPaused
                ? _languageCubit.getLocalizedText(korean: '일시정지', english: 'Paused')
                : session.formattedTimeRemaining,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(TestSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _languageCubit.getLocalizedText(korean: '진행률', english: 'Progress'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(session.progress * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: session.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildQuestionContent(TestSession session, TestQuestion question) {
    final savedAnswer = session.getAnswerForQuestion(session.currentQuestionIndex);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(question),
          const SizedBox(height: 24),
          _buildAnswerOptions(question, savedAnswer, session),
          const SizedBox(height: 24),
          if (_showingExplanation && question.explanation != null)
            _buildExplanationCard(question.explanation!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(TestQuestion question, {bool isLandscape = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = (question.questionImageUrl?.isNotEmpty == true) || 
                     (question.questionImagePath?.isNotEmpty == true);
    final hasAudio = (question.questionAudioUrl?.isNotEmpty == true) || 
                     (question.questionAudioPath?.isNotEmpty == true);
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            _buildQuestionImage(question.questionImageUrl, question.questionImagePath, isLandscape: isLandscape),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasAudio) ...[
                  const SizedBox(height: 16),
                  CustomCachedAudio(
                    audioUrl: question.questionAudioUrl,
                    audioPath: question.questionAudioPath,
                    label: _languageCubit.getLocalizedText(
                      korean: '문제 듣기',
                      english: 'Listen to Question',
                    ),
                  ),
                ],
                if (question.question.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    question.question,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionImage(String? imageUrl, String? imagePath, {bool isLandscape = false, bool isFixed = false}) {
    return GestureDetector(
      onTap: () => DialogUtils.showFullScreenImage(context ,imageUrl, imagePath),
      child: Container(
        width: double.infinity,
        constraints: isFixed ? const BoxConstraints.expand() : BoxConstraints(
          maxHeight: isLandscape ? 200 : 250,
          minHeight: isLandscape ? 150 : 200,
        ),
        child: Stack(
          children: [
            CustomCachedImage(
              imageUrl: imageUrl,
              imagePath: imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              borderRadius: isLandscape && !isFixed
                  ? BorderRadius.circular(16)
                  : isFixed
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOptions(TestQuestion question, savedAnswer, TestSession session) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageCubit.getLocalizedText(korean: '답안 선택', english: 'Choose Answer'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...question.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAnswerOption(index, option, question, savedAnswer, session),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAnswerOption(int index, AnswerOption option, TestQuestion question, savedAnswer, TestSession session, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedAnswerIndex == index;
    final isCorrectAnswer = index == question.correctAnswerIndex;
    final wasSelectedAnswer = savedAnswer?.selectedAnswerIndex == index;
    final showResult = _showingExplanation && savedAnswer != null;
    
    Color borderColor = colorScheme.outlineVariant;
    Color backgroundColor = colorScheme.surface;
    Widget? statusIcon;
    
    if (showResult) {
      if (isCorrectAnswer) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.1);
        statusIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
      } else if (wasSelectedAnswer) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.1);
        statusIcon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
      }
    } else if (isSelected || wasSelectedAnswer) {
      borderColor = colorScheme.primary;
      backgroundColor = colorScheme.primaryContainer.withOpacity(0.2);
    }
    
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isCompact ? 10 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            color: backgroundColor,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOptionSelector(index, isSelected || wasSelectedAnswer, borderColor),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionContent(index, option, isCompact: isCompact),
              ),
              if (statusIcon != null) ...[
                const SizedBox(width: 12),
                statusIcon,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionSelector(int index, bool isSelected, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
        color: isSelected ? color : Colors.transparent,
      ),
      child: Center(
        child: isSelected
            ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 14)
            : Text(
                String.fromCharCode(65 + index),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
      ),
    );
  }

  Widget _buildOptionContent(int index, AnswerOption option, {bool isCompact = false}) {
    final theme = Theme.of(context);
    
    if (option.isAudio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomCachedAudio(
            audioUrl: option.audioUrl,
            audioPath: option.audioPath,
            label: _languageCubit.getLocalizedText(
              korean: '선택지 ${String.fromCharCode(65 + index)} 듣기',
              english: 'Listen to Option ${String.fromCharCode(65 + index)}',
            ),
            height: isCompact ? 40 : 50,
          ),
          if (option.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              option.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    }
    
    if (option.isImage && (option.imageUrl?.isNotEmpty == true || option.imagePath?.isNotEmpty == true)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => DialogUtils.showFullScreenImage(context, option.imageUrl, option.imagePath),
            child: Container(
              constraints: BoxConstraints(maxHeight: isCompact ? 80 : 120),
              child: CustomCachedImage(
                imageUrl: option.imageUrl,
                imagePath: option.imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (option.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              option.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    } else {
      return Text(
        option.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  Widget _buildExplanationCard(String explanation, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.lightbulb_rounded, color: colorScheme.secondary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                _languageCubit.getLocalizedText(korean: '해설', english: 'Explanation'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isCompact 
              ? Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      explanation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : Text(
                  explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLandscapeNavigation(TestSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstQuestion = session.currentQuestionIndex == 0;
    final isLastQuestion = session.currentQuestionIndex == session.totalQuestions - 1;
    
    return Row(
      children: [
        if (!isFirstQuestion)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _previousQuestion,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                _languageCubit.getLocalizedText(korean: '이전', english: 'Prev'),
                style: theme.textTheme.labelMedium,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        
        if (!isFirstQuestion) const SizedBox(width: 8),
        
        Expanded(
          child: isLastQuestion && _selectedAnswerIndex != null && !_showingExplanation
              ? FilledButton.icon(
                  onPressed: () => _showFinishConfirmation(session),
                  icon: const Icon(Icons.flag_rounded, size: 16),
                  label: Text(
                    _languageCubit.getLocalizedText(korean: '완료', english: 'Finish'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                )
              : FilledButton.icon(
                  onPressed: isLastQuestion ? () => _showFinishConfirmation(session) : _nextQuestion,
                  icon: Icon(isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    isLastQuestion
                        ? _languageCubit.getLocalizedText(korean: '완료', english: 'Finish')
                        : _languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isLastQuestion ? Colors.green : colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTestNavigation(TestSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstQuestion = session.currentQuestionIndex == 0;
    final isLastQuestion = session.currentQuestionIndex == session.totalQuestions - 1;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          if (!isFirstQuestion)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(_languageCubit.getLocalizedText(korean: '이전', english: 'Previous')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          
          if (!isFirstQuestion) const SizedBox(width: 16),
          
          Expanded(
            child: FilledButton.icon(
              onPressed: () => isLastQuestion ? _showFinishConfirmation(session) : _nextQuestion(),
              icon: Icon(isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 18),
              label: Text(
                isLastQuestion
                    ? _languageCubit.getLocalizedText(korean: '완료', english: 'Finish')
                    : _languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isLastQuestion ? Colors.green : colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigationSheet(TestSession session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Text(
                  _languageCubit.getLocalizedText(korean: '문제 목록', english: 'Question Navigation'),
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
          Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 400),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: session.totalQuestions,
              itemBuilder: (context, index) {
                final isCurrentQuestion = index == session.currentQuestionIndex;
                final isAnswered = session.isQuestionAnswered(index);
                
                Color backgroundColor;
                Color textColor;
                Color borderColor;
                
                if (isCurrentQuestion) {
                  backgroundColor = colorScheme.primary;
                  textColor = colorScheme.onPrimary;
                  borderColor = colorScheme.primary;
                } else if (isAnswered) {
                  backgroundColor = colorScheme.primaryContainer;
                  textColor = colorScheme.onPrimaryContainer;
                  borderColor = colorScheme.primary.withOpacity(0.5);
                } else {
                  backgroundColor = colorScheme.surfaceContainerHighest;
                  textColor = colorScheme.onSurfaceVariant;
                  borderColor = colorScheme.outlineVariant;
                }
                
                return Material(
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _jumpToQuestion(index),
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
                          if (isAnswered && !isCurrentQuestion)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFinishConfirmation(TestSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _languageCubit.getLocalizedText(korean: '시험 완료', english: 'Finish Test'),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '정말로 시험을 완료하시겠습니까?\n답변: ${session.answeredQuestionsCount}/${session.totalQuestions}',
            english: 'Are you sure you want to finish?\nAnswered: ${session.answeredQuestionsCount}/${session.totalQuestions}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageCubit.getLocalizedText(korean: '취소', english: 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _sessionCubit.completeTest();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: Text(_languageCubit.getLocalizedText(korean: '완료', english: 'Finish')),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _languageCubit.getLocalizedText(korean: '시험 종료', english: 'Exit Test'),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '시험을 종료하시겠습니까? 진행 상황이 저장되지 않습니다.',
            english: 'Exit the test? Your progress will not be saved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_languageCubit.getLocalizedText(korean: '계속하기', english: 'Continue')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_languageCubit.getLocalizedText(korean: '종료', english: 'Exit')),
          ),
        ],
      ),
    );
  }
}