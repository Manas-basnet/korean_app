import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/features/test_results/presentation/widgets/question_review_navigation_sheet.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/shared/models/test_related/test_answer.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/test_related/test_question.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_audio.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class TestReviewPortraitModeWidget extends StatefulWidget {
  final TestResult testResult;
  final int currentQuestionIndex;
  final TestQuestion question;
  final TestAnswer? userAnswer;
  final Animation<double> slideAnimation;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onExitPressed;
  final VoidCallback onToggleOrientation;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final Function(int) onJumpToQuestion;

  const TestReviewPortraitModeWidget({
    super.key,
    required this.testResult,
    required this.currentQuestionIndex,
    required this.question,
    required this.userAnswer,
    required this.slideAnimation,
    required this.languageCubit,
    required this.onExitPressed,
    required this.onToggleOrientation,
    required this.onPreviousQuestion,
    required this.onNextQuestion,
    required this.onJumpToQuestion,
  });

  @override
  State<TestReviewPortraitModeWidget> createState() => _TestReviewPortraitModeWidgetState();
}

class _TestReviewPortraitModeWidgetState extends State<TestReviewPortraitModeWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCompactReviewHeader(context),
        if (widget.testResult.isLegacyResult) _buildLegacyDataWarning(context),
        Expanded(
          child: AnimatedBuilder(
            animation: widget.slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - widget.slideAnimation.value)),
                child: Opacity(
                  opacity: widget.slideAnimation.value,
                  child: _buildResponsiveContent(context),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactReviewHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onExitPressed,
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      '${widget.currentQuestionIndex + 1}/${widget.testResult.testQuestions.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(context),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (widget.currentQuestionIndex + 1) / widget.testResult.testQuestions.length,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            minHeight: 3,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
   
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: widget.onToggleOrientation,
          icon: const Icon(Icons.stay_current_landscape_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: widget.languageCubit.getLocalizedText(korean: '가로 모드', english: 'Landscape Mode'),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => TestReviewQuestionNavigationSheet.show(
            context,
            widget.testResult,
            widget.currentQuestionIndex,
            widget.languageCubit,
            widget.onJumpToQuestion,
          ),
          icon: const Icon(Icons.grid_view_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: widget.languageCubit.getLocalizedText(korean: '문제 목록', english: 'Question List'),
        ),
        const SizedBox(width: 4),
        _buildScoreBadge(context),
      ],
    );
  }

  Widget _buildScoreBadge(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.testResult.isPassed ? colorScheme.primaryContainer : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${widget.testResult.score}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: widget.testResult.isPassed ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildResponsiveContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final availableHeight = constraints.maxHeight;
        
        final isSmallScreen = screenHeight < 700;
        
        if (isSmallScreen) {
          return _buildScrollableContent(context);
        } else {
          return _buildNonScrollableContent(context, availableHeight);
        }
      },
    );
  }

  Widget _buildNonScrollableContent(BuildContext context, double availableHeight) {
    final hasImage = (widget.question.questionImageUrl?.isNotEmpty == true) || 
                    (widget.question.questionImagePath?.isNotEmpty == true);
    
    int questionFlex;
    int answerFlex;
    
    if (hasImage) {
      questionFlex = 4;
      answerFlex = 4;
    } else {
      final textLength = (widget.question.question.length + (widget.question.subQuestion?.length ?? 0));
      final hasAudio = (widget.question.questionAudioUrl?.isNotEmpty == true) || 
                      (widget.question.questionAudioPath?.isNotEmpty == true);
      
      if (textLength > 200 || hasAudio) {
        questionFlex = 4;
        answerFlex = 4;
      } else if (textLength > 100) {
        questionFlex = 3;
        answerFlex = 5;
      } else {
        questionFlex = 2;
        answerFlex = 6;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            flex: questionFlex,
            child: _buildQuestionCard(context, isCompact: true),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: answerFlex,
            child: _buildAnswerOptionsWithNavigation(context),
          ),
          if (widget.question.explanation?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: _buildExplanationCard(context, widget.question.explanation!, isCompact: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollableContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(context),
          const SizedBox(height: 20),
          _buildAnswerOptionsWithNavigation(context),
          if (widget.question.explanation?.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _buildExplanationCard(context, widget.question.explanation!),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnswerOptionsWithNavigation(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildAnswerReview(context),
        ),
        const SizedBox(height: 12),
        _buildNavigationButtons(context),
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstQuestion = widget.currentQuestionIndex == 0;
    final isLastQuestion = widget.currentQuestionIndex == widget.testResult.testQuestions.length - 1;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (!isFirstQuestion) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onPreviousQuestion,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  widget.languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: isLastQuestion ? null : widget.onNextQuestion,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                widget.languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
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

  Widget _buildQuestionCard(BuildContext context, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = (widget.question.questionImageUrl?.isNotEmpty == true) || 
                    (widget.question.questionImagePath?.isNotEmpty == true);
    final hasAudio = (widget.question.questionAudioUrl?.isNotEmpty == true) || 
                    (widget.question.questionAudioPath?.isNotEmpty == true);
    final hasText = widget.question.question.isNotEmpty || widget.question.hasSubQuestion;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: hasImage ? _buildImageQuestionLayout(context, hasAudio, hasText, isCompact) : _buildTextOnlyQuestionLayout(context, hasAudio, isCompact),
    );
  }

  Widget _buildImageQuestionLayout(BuildContext context, bool hasAudio, bool hasText, bool isCompact) {
    return Column(
      children: [
        Expanded(
          flex: hasText ? 3 : 4,
          child: _buildQuestionImage(context, widget.question.questionImageUrl, widget.question.questionImagePath),
        ),
        if (hasText || hasAudio)
          Expanded(
            flex: hasText ? 2 : 1,
            child: _buildQuestionTextContent(context, hasAudio, isCompact),
          ),
      ],
    );
  }

  Widget _buildTextOnlyQuestionLayout(BuildContext context, bool hasAudio, bool isCompact) {
    return SizedBox(
      width: double.infinity,
      child: _buildQuestionTextContent(context, hasAudio, isCompact),
    );
  }

  Widget _buildQuestionTextContent(BuildContext context, bool hasAudio, bool isCompact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasAudio) ...[
            const SizedBox(height: 8),
            CustomCachedAudio(
              audioUrl: widget.question.questionAudioUrl,
              audioPath: widget.question.questionAudioPath,
              label: widget.languageCubit.getLocalizedText(
                korean: '문제 듣기',
                english: 'Listen to Question',
              ),
              height: isCompact ? 36 : 50,
            ),
          ],
          if (widget.question.question.isNotEmpty) ...[
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.question.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (widget.question.hasSubQuestion) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.question.subQuestion!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (widget.question.hasSubQuestion) ...[
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.question.subQuestion!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionImage(BuildContext context, String? imageUrl, String? imagePath) {
    return GestureDetector(
      onTap: () => DialogUtils.showFullScreenImage(context, imageUrl, imagePath),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        DialogUtils.showFullScreenImage(
          context, 
          imageUrl, 
          imagePath,
          heroTag: 'question_${imageUrl ?? imagePath}',
        );
      },
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            CustomCachedImage(
              imageUrl: imageUrl,
              imagePath: imagePath,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerReview(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.languageCubit.getLocalizedText(korean: '답안 검토', english: 'Answer Review'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _buildCompactStatusIndicator(context),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildAnswerOptions(context),
        ),
      ],
    );
  }

  Widget _buildCompactStatusIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = widget.userAnswer?.isCorrect ?? false;
    final hasUserAnswer = widget.userAnswer != null;

    if (!hasUserAnswer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.grey, size: 16),
            const SizedBox(width: 4),
            Text(
              widget.languageCubit.getLocalizedText(korean: '미응답', english: 'No Answer'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.withValues(alpha: 0.1) 
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isCorrect 
                ? widget.languageCubit.getLocalizedText(korean: '정답', english: 'Correct')
                : widget.languageCubit.getLocalizedText(korean: '오답', english: 'Incorrect'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOptions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasImageAnswers = widget.question.hasImageAnswers;
        final optionCount = widget.question.options.length;
        final availableHeight = constraints.maxHeight;
        
        if (hasImageAnswers) {
          return _buildImageAnswerOptions(context, availableHeight);
        } else {
          return _buildTextAnswerOptions(context, availableHeight, optionCount);
        }
      },
    );
  }

  Widget _buildTextAnswerOptions(BuildContext context, double availableHeight, int optionCount) {
    const minItemHeight = 50.0;
    const spacing = 8.0;
    final totalSpacing = (optionCount - 1) * spacing;
    final requiredHeight = (optionCount * minItemHeight) + totalSpacing;
    
    if (requiredHeight <= availableHeight) {
      return Column(
        children: [
          for (int index = 0; index < optionCount; index++) ...[
            if (index > 0) const SizedBox(height: spacing),
            Expanded(
              child: _buildAnswerOption(context, index, widget.question.options[index]),
            ),
          ],
        ],
      );
    } else {
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: optionCount,
        separatorBuilder: (context, index) => const SizedBox(height: spacing),
        itemBuilder: (context, index) {
          final option = widget.question.options[index];
          return Container(
            constraints: const BoxConstraints(minHeight: minItemHeight),
            child: _buildAnswerOption(context, index, option),
          );
        },
      );
    }
  }

  Widget _buildImageAnswerOptions(BuildContext context, double availableHeight) {
    final optionCount = widget.question.options.length;
    int crossAxisCount = optionCount <= 2 ? 1 : 2;
    const minItemHeight = 120.0;
    const spacing = 8.0;
    
    final itemsPerColumn = (optionCount / crossAxisCount).ceil();
    final totalSpacing = (itemsPerColumn - 1) * spacing;
    final requiredHeight = (itemsPerColumn * minItemHeight) + totalSpacing;
    
    if (requiredHeight <= availableHeight) {
      final itemsPerRow = crossAxisCount;
      final rowCount = (optionCount / itemsPerRow).ceil();
      
      return Column(
        children: [
          for (int row = 0; row < rowCount; row++) ...[
            if (row > 0) const SizedBox(height: spacing),
            Expanded(
              child: Row(
                children: [
                  for (int col = 0; col < itemsPerRow; col++) ...[
                    if (col > 0) const SizedBox(width: spacing),
                    () {
                      final index = row * itemsPerRow + col;
                      if (index < optionCount) {
                        return Expanded(
                          child: _buildAnswerOption(context, index, widget.question.options[index], isGrid: true),
                        );
                      } else {
                        return const Expanded(child: SizedBox());
                      }
                    }(),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      return GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.2,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: optionCount,
        itemBuilder: (context, index) {
          final option = widget.question.options[index];
          return _buildAnswerOption(context, index, option, isGrid: true);
        },
      );
    }
  }

  Widget _buildAnswerOption(BuildContext context, int index, AnswerOption option, {bool isGrid = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCorrectAnswer = index == widget.question.correctAnswerIndex;
    final wasSelectedAnswer = widget.userAnswer?.selectedAnswerIndex == index;
    
    Color borderColor = colorScheme.outlineVariant;
    Color backgroundColor = colorScheme.surface;
    Widget? suffixIcon;
    
    if (isCorrectAnswer && wasSelectedAnswer) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withValues(alpha: 0.1);
      suffixIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.languageCubit.getLocalizedText(korean: '내 답', english: 'Your answer'),
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
      borderColor = Colors.green;
      backgroundColor = Colors.green.withValues(alpha: 0.1);
      suffixIcon = const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (!isCorrectAnswer && wasSelectedAnswer) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.1);
      suffixIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.languageCubit.getLocalizedText(korean: '내 답', english: 'Your answer'),
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

    if (isGrid && option.isImage && (option.imageUrl?.isNotEmpty == true || option.imagePath?.isNotEmpty == true)) {
      return _buildImageGridOption(context, index, option, wasSelectedAnswer, borderColor, suffixIcon);
    }

    return Container(
      padding: EdgeInsets.all(isGrid ? 12 : 16),
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
            child: _buildOptionContent(context, index, option, isCompact: isGrid),
          ),
          if (suffixIcon != null && !isGrid) ...[
            const SizedBox(width: 12),
            suffixIcon,
          ],
        ],
      ),
    );
  }

  Widget _buildImageGridOption(BuildContext context, int index, AnswerOption option, bool isSelected, Color borderColor, Widget? statusIcon) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        DialogUtils.showFullScreenImage(
          context, 
          option.imageUrl, 
          option.imagePath,
          heroTag: 'option_${index}_${option.imageUrl ?? option.imagePath}',
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor, 
            width: isSelected ? 2.5 : 1.2
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CustomCachedImage(
                imageUrl: option.imageUrl,
                imagePath: option.imagePath,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
              
              Positioned(
                top: 8,
                left: 8,
                child: _buildImageOptionChip(context, index, borderColor),
              ),
              
              if (statusIcon != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: statusIcon,
                  ),
                ),
              
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.zoom_out_map_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
              
              if (option.text.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      option.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageOptionChip(BuildContext context, int index, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        String.fromCharCode(65 + index),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerIndicator(int index, bool isCorrect, bool wasSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color color = colorScheme.onSurfaceVariant;
    Color backgroundColor = Colors.transparent;
    
    if (isCorrect && wasSelected) {
      color = Colors.white;
      backgroundColor = Colors.green;
    } else if (isCorrect && !wasSelected) {
      color = Colors.white;
      backgroundColor = Colors.green;
    } else if (!isCorrect && wasSelected) {
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

  Widget _buildOptionContent(BuildContext context, int index, AnswerOption option, {bool isCompact = false}) {
    final theme = Theme.of(context);
    
    if (option.isAudio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomCachedAudio(
            audioUrl: option.audioUrl,
            audioPath: option.audioPath,
            label: widget.languageCubit.getLocalizedText(
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

  Widget _buildExplanationCard(BuildContext context, String explanation, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.3),
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
                widget.languageCubit.getLocalizedText(korean: '해설', english: 'Explanation'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
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
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                )
              : Text(
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

  Widget _buildLegacyDataWarning(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
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
              widget.languageCubit.getLocalizedText(
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
}