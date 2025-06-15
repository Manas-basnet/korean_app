import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/enums/question_type.dart';
import 'package:korean_language_app/core/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/shared/models/test_question.dart';
import 'package:korean_language_app/core/shared/models/test_result.dart';
import 'package:korean_language_app/core/shared/models/test_answer.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_audio.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

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

  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();

  @override
  void initState() {
    super.initState();
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
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
      _slideAnimationController.forward(from: 0.0);
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _slideAnimationController.forward(from: 0.0);
    }
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < widget.testResult.testQuestions.length) {
      setState(() {
        _currentQuestionIndex = index;
      });
      Navigator.of(context).pop(); // Close navigation sheet
      _slideAnimationController.forward(from: 0.0);
    }
  }

  void _showQuestionNavigation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuestionNavigationSheet(),
    );
  }

  void _showFullScreenImage(String? imageUrl, String? imagePath, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: CustomCachedImage(
                imageUrl: imageUrl,
                imagePath: imagePath,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_languageCubit.getLocalizedText(
          korean: '시험 검토',
          english: 'Test Review',
        )),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: _toggleOrientation,
            icon: Icon(_isLandscape ? Icons.stay_current_portrait : Icons.stay_current_landscape),
          ),
          IconButton(
            onPressed: _showQuestionNavigation,
            icon: const Icon(Icons.grid_view),
          ),
        ],
      ),
      body: _isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
    );
  }

  Widget _buildPortraitLayout() {
    final question = widget.testResult.testQuestions[_currentQuestionIndex];
    final userAnswer = _getUserAnswerForQuestion(question.id);

    return Column(
      children: [
        _buildHeader(),
        if (widget.testResult.isLegacyResult) _buildLegacyDataWarning(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildQuestionCard(question),
                const SizedBox(height: 16),
                _buildAnswerOptions(question, userAnswer),
                const SizedBox(height: 16),
                if (question.explanation?.isNotEmpty == true)
                  _buildExplanationCard(question.explanation!),
              ],
            ),
          ),
        ),
        _buildNavigation(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    final question = widget.testResult.testQuestions[_currentQuestionIndex];
    final userAnswer = _getUserAnswerForQuestion(question.id);

    return Column(
      children: [
        _buildHeader(),
        if (widget.testResult.isLegacyResult) _buildLegacyDataWarning(),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildQuestionCard(question, isLandscape: true),
                      if (question.explanation?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _buildExplanationCard(question.explanation!, isCompact: true),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildAnswerOptions(question, userAnswer, isCompact: true),
                      ),
                      _buildNavigation(),
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

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.testResult.testTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _languageCubit.getLocalizedText(
                        korean: '문제 ${_currentQuestionIndex + 1} / ${widget.testResult.testQuestions.length}',
                        english: 'Question ${_currentQuestionIndex + 1} of ${widget.testResult.testQuestions.length}',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildScoreBadge(),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildScoreBadge() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.testResult.isPassed ? colorScheme.primaryContainer : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${widget.testResult.score}%',
        style: theme.textTheme.labelMedium?.copyWith(
          color: widget.testResult.isPassed ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (_currentQuestionIndex + 1) / widget.testResult.testQuestions.length;

    return LinearProgressIndicator(
      value: progress,
      backgroundColor: colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
      minHeight: 6,
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
      onTap: () => _showFullScreenImage(imageUrl, imagePath, 'question'),
      child: Container(
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

  Widget _buildAnswerOptions(TestQuestion question, TestAnswer? userAnswer, {bool isCompact = false}) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageCubit.getLocalizedText(korean: '답안 검토', english: 'Answer Review'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildAnswerSummary(question, userAnswer),
        const SizedBox(height: 16),
        if (isCompact)
          Expanded(
            child: ListView.separated(
              itemCount: question.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = question.options[index];
                return _buildAnswerOption(index, option, question, userAnswer, isCompact: true);
              },
            ),
          )
        else
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAnswerOption(index, option, question, userAnswer),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildAnswerSummary(TestQuestion question, TestAnswer? userAnswer) {
    final theme = Theme.of(context);
    final correctAnswerText = question.options[question.correctAnswerIndex].text;
    final userAnswerText = userAnswer != null 
        ? question.options[userAnswer.selectedAnswerIndex].text 
        : _languageCubit.getLocalizedText(korean: '답안 없음', english: 'No answer');
    final isCorrect = userAnswer?.isCorrect ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.withOpacity(0.1) 
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect 
                    ? _languageCubit.getLocalizedText(korean: '정답', english: 'Correct')
                    : _languageCubit.getLocalizedText(korean: '오답', english: 'Incorrect'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isCorrect ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isCorrect && userAnswer != null) ...[
            _buildAnswerSummaryRow(
              _languageCubit.getLocalizedText(korean: '내 답:', english: 'Your answer:'),
              '${String.fromCharCode(65 + userAnswer.selectedAnswerIndex)}. ${userAnswerText.length > 50 ? '${userAnswerText.substring(0, 50)}...' : userAnswerText}',
              Colors.red,
            ),
            const SizedBox(height: 4),
          ],
          _buildAnswerSummaryRow(
            _languageCubit.getLocalizedText(korean: '정답:', english: 'Correct answer:'),
            '${String.fromCharCode(65 + question.correctAnswerIndex)}. ${correctAnswerText.length > 50 ? '${correctAnswerText.substring(0, 50)}...' : correctAnswerText}',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSummaryRow(String label, String value, Color color) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerOption(int index, AnswerOption option, TestQuestion question, TestAnswer? userAnswer, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCorrectAnswer = index == question.correctAnswerIndex;
    final wasSelectedAnswer = userAnswer?.selectedAnswerIndex == index;
    
    Color borderColor = colorScheme.outlineVariant;
    Color backgroundColor = colorScheme.surface;
    Widget? suffixIcon;
    
    if (isCorrectAnswer && wasSelectedAnswer) {
      // User selected the correct answer
      borderColor = Colors.green;
      backgroundColor = Colors.green.withOpacity(0.1);
      suffixIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _languageCubit.getLocalizedText(korean: '내 답', english: 'Your answer'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      );
    } else if (isCorrectAnswer && !wasSelectedAnswer) {
      // Correct answer but user didn't select it
      borderColor = Colors.green;
      backgroundColor = Colors.green.withOpacity(0.1);
      suffixIcon = const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (!isCorrectAnswer && wasSelectedAnswer) {
      // User selected wrong answer
      borderColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.1);
      suffixIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _languageCubit.getLocalizedText(korean: '내 답', english: 'Your answer'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.cancel, color: Colors.red, size: 20),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        children: [
          _buildAnswerIndicator(index, isCorrectAnswer, wasSelectedAnswer),
          const SizedBox(width: 12),
          Expanded(
            child: _buildOptionContent(index, option, isCompact: isCompact),
          ),
          if (suffixIcon != null) ...[
            const SizedBox(width: 12),
            suffixIcon,
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerIndicator(int index, bool isCorrect, bool wasSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color color = colorScheme.onSurfaceVariant;
    Color backgroundColor = Colors.transparent;
    
    if (isCorrect && wasSelected) {
      // User selected correct answer
      color = Colors.white;
      backgroundColor = Colors.green;
    } else if (isCorrect && !wasSelected) {
      // Correct answer not selected
      color = Colors.white;
      backgroundColor = Colors.green;
    } else if (!isCorrect && wasSelected) {
      // Wrong answer selected
      color = Colors.white;
      backgroundColor = Colors.red;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(
          color: isCorrect ? Colors.green : 
                wasSelected ? Colors.red : colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          String.fromCharCode(65 + index),
          style: theme.textTheme.labelMedium?.copyWith(
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
            onTap: () => _showFullScreenImage(option.imageUrl, option.imagePath, 'answer'),
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
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tertiary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _languageCubit.getLocalizedText(korean: '해설', english: 'Explanation'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: Text(_languageCubit.getLocalizedText(
                korean: '이전',
                english: 'Previous',
              )),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: _currentQuestionIndex < widget.testResult.testQuestions.length - 1 ? _nextQuestion : null,
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              label: Text(_languageCubit.getLocalizedText(
                korean: '다음',
                english: 'Next',
              )),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigationSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _languageCubit.getLocalizedText(
                      korean: '문제 목록',
                      english: 'Question List',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: widget.testResult.testQuestions.length,
              itemBuilder: (context, index) {
                final question = widget.testResult.testQuestions[index];
                final userAnswer = _getUserAnswerForQuestion(question.id);
                final isCorrect = userAnswer?.isCorrect ?? false;
                final isAnswered = userAnswer != null;
                final isCurrent = index == _currentQuestionIndex;

                Color backgroundColor = colorScheme.surfaceContainerHighest;
                Color textColor = colorScheme.onSurfaceVariant;
                Color borderColor = Colors.transparent;

                if (isCurrent) {
                  backgroundColor = colorScheme.primary.withOpacity(0.1);
                  borderColor = colorScheme.primary;
                  textColor = colorScheme.primary;
                } else if (isAnswered) {
                  if (isCorrect) {
                    backgroundColor = Colors.green.withOpacity(0.1);
                    textColor = Colors.green;
                  } else {
                    backgroundColor = Colors.red.withOpacity(0.1);
                    textColor = Colors.red;
                  }
                }

                return GestureDetector(
                  onTap: () => _goToQuestion(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildLegacyDataWarning() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '이 시험 결과는 이전 버전에서 생성되어 상세한 검토가 제한됩니다.',
                english: 'This test result was created in a previous version and has limited review functionality.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
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
}