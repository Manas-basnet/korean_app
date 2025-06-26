import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/question_navigation_sheet.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/test_dialogs.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/shared/models/test_answer.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/test_question.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_audio.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class TestPortraitModeWidget extends StatelessWidget {
  final TestSession session;
  final TestQuestion question;
  final bool isPaused;
  final Animation<double> slideAnimation;
  final LanguagePreferenceCubit languageCubit;
  final int? selectedAnswerIndex;
  final bool showingExplanation;
  final bool isLandscape;
  final VoidCallback onExitPressed;
  final VoidCallback onToggleOrientation;
  final VoidCallback onToggleExplanation;
  final Function(int) onAnswerSelected;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final Function(String, String) onShowRatingDialog;
  final Function(int) onJumpToQuestion;

  const TestPortraitModeWidget({
    super.key,
    required this.session,
    required this.slideAnimation,
    required this.question,
    required this.isPaused,
    required this.languageCubit,
    required this.selectedAnswerIndex,
    required this.showingExplanation,
    required this.isLandscape,
    required this.onExitPressed,
    required this.onToggleOrientation,
    required this.onToggleExplanation,
    required this.onAnswerSelected,
    required this.onPreviousQuestion,
    required this.onNextQuestion,
    required this.onShowRatingDialog,
    required this.onJumpToQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCompactTestHeader(context),
        Expanded(
          child: AnimatedBuilder(
            animation: slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - slideAnimation.value)),
                child: Opacity(
                  opacity: slideAnimation.value,
                  child: _buildResponsiveContent(context),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTestHeader(BuildContext context) {
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
                onPressed: onExitPressed,
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
                      session.test.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${session.currentQuestionIndex + 1}/${session.totalQuestions}',
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
            value: session.progress,
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
          onPressed: onToggleOrientation,
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
          tooltip: languageCubit.getLocalizedText(korean: '가로 모드', english: 'Landscape Mode'),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => QuestionNavigationSheet.show(
            context,
            session,
            languageCubit,
            onJumpToQuestion,
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
          tooltip: languageCubit.getLocalizedText(korean: '문제 목록', english: 'Question List'),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onToggleExplanation,
          icon: Icon(showingExplanation ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: showingExplanation
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest,
            foregroundColor: showingExplanation
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: languageCubit.getLocalizedText(korean: '해설', english: 'Explanation'),
        ),
        if (session.hasTimeLimit) ...[
          const SizedBox(width: 4),
          _buildTimeDisplay(context),
        ],
      ],
    );
  }

  Widget _buildTimeDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLowTime = session.timeRemaining != null && session.timeRemaining! < 300;
    
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    if (isPaused) {
      backgroundColor = colorScheme.tertiary.withValues(alpha: 0.1);
      textColor = colorScheme.tertiary;
      icon = Icons.pause_rounded;
    } else if (isLowTime) {
      backgroundColor = colorScheme.errorContainer.withValues(alpha: 0.3);
      textColor = colorScheme.error;
      icon = Icons.timer_outlined;
    } else {
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
      textColor = colorScheme.primary;
      icon = Icons.timer_outlined;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            isPaused
                ? languageCubit.getLocalizedText(korean: '일시정지', english: 'Paused')
                : session.formattedTimeRemaining,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
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
    final savedAnswer = session.getAnswerForQuestion(session.currentQuestionIndex);
    final hasImage = (question.questionImageUrl?.isNotEmpty == true) || 
                    (question.questionImagePath?.isNotEmpty == true);
    
    int questionFlex;
    int answerFlex;
    
    if (hasImage) {
      questionFlex = 4;
      answerFlex = 4;
    } else {
      final textLength = (question.question.length + (question.subQuestion?.length ?? 0));
      final hasAudio = (question.questionAudioUrl?.isNotEmpty == true) || 
                      (question.questionAudioPath?.isNotEmpty == true);
      
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
            child: _buildAnswerOptionsWithNavigation(context, savedAnswer),
          ),
          if (showingExplanation && question.explanation != null) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              child: _buildExplanationCard(context, question.explanation!, isCompact: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollableContent(BuildContext context) {
    final savedAnswer = session.getAnswerForQuestion(session.currentQuestionIndex);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(context),
          const SizedBox(height: 20),
          _buildAnswerOptionsWithNavigation(context, savedAnswer),
          if (showingExplanation && question.explanation != null) ...[
            const SizedBox(height: 20),
            _buildExplanationCard(context, question.explanation!),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAnswerOptionsWithNavigation(BuildContext context, TestAnswer? savedAnswer) {
    return Column(
      children: [
        Expanded(
          child: _buildResponsiveAnswerOptions(context, savedAnswer),
        ),
        const SizedBox(height: 12),
        _buildNavigationButtons(context),
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstQuestion = session.currentQuestionIndex == 0;
    final isLastQuestion = session.currentQuestionIndex == session.totalQuestions - 1;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (!isFirstQuestion) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPreviousQuestion,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              onPressed: () => isLastQuestion 
                  ? TestDialogs.showFinishConfirmation(
                      context,
                      languageCubit,
                      session,
                      () => onShowRatingDialog(session.test.title, session.test.id),
                    )
                  : onNextQuestion(),
              icon: Icon(
                isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                isLastQuestion 
                    ? languageCubit.getLocalizedText(korean: '완료', english: 'Finish')
                    : languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isLastQuestion ? Colors.green : colorScheme.primary,
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
    final hasImage = (question.questionImageUrl?.isNotEmpty == true) || 
                    (question.questionImagePath?.isNotEmpty == true);
    final hasAudio = (question.questionAudioUrl?.isNotEmpty == true) || 
                    (question.questionAudioPath?.isNotEmpty == true);
    final hasText = question.question.isNotEmpty || question.hasSubQuestion;
    
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
          child: _buildQuestionImage(context, question.questionImageUrl, question.questionImagePath),
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
              languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasAudio) ...[
            const SizedBox(height: 8),
            CustomCachedAudio(
              audioUrl: question.questionAudioUrl,
              audioPath: question.questionAudioPath,
              label: languageCubit.getLocalizedText(
                korean: '문제 듣기',
                english: 'Listen to Question',
              ),
              height: isCompact ? 36 : 50,
            ),
          ],
          if (question.question.isNotEmpty) ...[
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (question.hasSubQuestion) ...[
                      const SizedBox(height: 8),
                      Text(
                        question.subQuestion!,
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
          ] else if (question.hasSubQuestion) ...[
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  question.subQuestion!,
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

  Widget _buildResponsiveAnswerOptions(BuildContext context, TestAnswer? savedAnswer) {
    final hasImageAnswers = question.hasImageAnswers;
    
    if (hasImageAnswers) {
      return _buildAnswerOptionsGrid(context, savedAnswer);
    } else {
      return _buildAnswerList(context, savedAnswer);
    }
  }

  Widget _buildAnswerList(BuildContext context, TestAnswer? savedAnswer) {
    final optionCount = question.options.length;
    
    return Column(
      children: [
        for (int index = 0; index < optionCount; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          Expanded(
            child: _buildAnswerOption(context, index, question.options[index], savedAnswer),
          ),
        ],
      ],
    );
  }

  Widget _buildAnswerOptionsGrid(BuildContext context, TestAnswer? savedAnswer) {
    final optionCount = question.options.length;
    
    int crossAxisCount = optionCount <= 2 ? 1 : 2;
    final itemsPerRow = crossAxisCount;
    final rowCount = (optionCount / itemsPerRow).ceil();
    
    return Column(
      children: [
        for (int row = 0; row < rowCount; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                for (int col = 0; col < itemsPerRow; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  () {
                    final index = row * itemsPerRow + col;
                    if (index < optionCount) {
                      return Expanded(
                        child: _buildAnswerOption(
                          context, 
                          index, 
                          question.options[index], 
                          savedAnswer, 
                          isGrid: true
                        ),
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
  }

  Widget _buildAnswerOption(BuildContext context, int index, AnswerOption option, TestAnswer? savedAnswer, {bool isGrid = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = selectedAnswerIndex == index;
    final isCorrectAnswer = index == question.correctAnswerIndex;
    final wasSelectedAnswer = savedAnswer?.selectedAnswerIndex == index;
    final showResult = showingExplanation && savedAnswer != null;
    
    Color borderColor = colorScheme.outlineVariant;
    Color backgroundColor = colorScheme.surface;
    Widget? statusIcon;
    
    if (showResult) {
      if (isCorrectAnswer) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        statusIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
      } else if (wasSelectedAnswer) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        statusIcon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
      }
    } else if (isSelected || wasSelectedAnswer) {
      borderColor = colorScheme.primary;
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.2);
    }

    if (isGrid && option.isImage && (option.imageUrl?.isNotEmpty == true || option.imagePath?.isNotEmpty == true)) {
      return _buildImageGridOption(context, index, option, isSelected || wasSelectedAnswer, borderColor, statusIcon);
    }
    
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onAnswerSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            color: backgroundColor,
          ),
          child: isGrid
            ? _buildGridOptionContent(context, index, option, isSelected || wasSelectedAnswer, borderColor, statusIcon)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildOptionSelector(context, index, isSelected || wasSelectedAnswer, borderColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOptionContent(context, index, option),
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

  Widget _buildImageGridOption(BuildContext context, int index, AnswerOption option, bool isSelected, Color borderColor, Widget? statusIcon) {
    final theme = Theme.of(context);
    
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onAnswerSelected(index),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          DialogUtils.showFullScreenImage(
            context, 
            option.imageUrl, 
            option.imagePath,
            heroTag: 'option_${index}_${option.imageUrl ?? option.imagePath}',
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
                
                if (isSelected)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildImageOptionChip(context, index, isSelected, borderColor),
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
      ),
    );
  }

  Widget _buildImageOptionChip(BuildContext context, int index, bool isSelected, Color color) {
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 1,
        ),
      ),
      child: Text(
        String.fromCharCode(65 + index),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.white,
          shadows: isSelected ? null : [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOptionContent(BuildContext context, int index, AnswerOption option, bool isSelected, Color color, Widget? statusIcon) {
    return Column(
      children: [
        Row(
          children: [
            _buildOptionSelector(context, index, isSelected, color),
            const Spacer(),
            if (statusIcon != null) statusIcon,
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildOptionContent(context, index, option, isGrid: true),
        ),
      ],
    );
  }

  Widget _buildOptionSelector(BuildContext context, int index, bool isSelected, Color color) {
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

  Widget _buildOptionContent(BuildContext context, int index, AnswerOption option, {bool isGrid = false}) {
    final theme = Theme.of(context);
    
    if (option.isAudio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomCachedAudio(
            audioUrl: option.audioUrl,
            audioPath: option.audioPath,
            label: languageCubit.getLocalizedText(
              korean: '선택지 ${String.fromCharCode(65 + index)} 듣기',
              english: 'Listen to Option ${String.fromCharCode(65 + index)}',
            ),
            height: 40,
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
          Expanded(
            child: GestureDetector(
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
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      CustomCachedImage(
                        imageUrl: option.imageUrl,
                        imagePath: option.imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ],
                  ),
                ),
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
              maxLines: isGrid ? 2 : null,
              overflow: isGrid ? TextOverflow.ellipsis : null,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    } else {
      return Center(
        child: Text(
          option.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          textAlign: isGrid ? TextAlign.center : TextAlign.start,
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
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
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
                  color: colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.lightbulb_rounded, color: colorScheme.secondary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                languageCubit.getLocalizedText(korean: '해설', english: 'Explanation'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
}