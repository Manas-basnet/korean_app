import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_session/test_session_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/question_navigation_sheet.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_session/test_dialogs.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
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
    required this.question,
    required this.isPaused,
    required this.slideAnimation,
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
        _buildTestHeader(context),
        Expanded(
          child: AnimatedBuilder(
            animation: slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - slideAnimation.value)),
                child: Opacity(
                  opacity: slideAnimation.value,
                  child: _buildQuestionContent(context),
                ),
              );
            },
          ),
        ),
        _buildTestNavigation(context),
      ],
    );
  }

  Widget _buildTestHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
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
                      languageCubit.getLocalizedText(
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
              _buildHeaderActions(context),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(context),
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
          icon: Icon(
            isLandscape
                ? Icons.stay_current_landscape_rounded
                : Icons.stay_current_portrait_rounded,
            size: 16
          ),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: languageCubit.getLocalizedText(
            korean: isLandscape ? '세로 모드' : '가로 모드',
            english: isLandscape ? 'Portrait Mode' : 'Landscape Mode'
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => QuestionNavigationSheet.show(
            context,
            session,
            languageCubit,
            onJumpToQuestion,
          ),
          icon: const Icon(Icons.grid_view_rounded, size: 18),
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
          icon: Icon(showingExplanation ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded, size: 18),
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
                ? languageCubit.getLocalizedText(korean: '일시정지', english: 'Paused')
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

  Widget _buildProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              languageCubit.getLocalizedText(korean: '진행률', english: 'Progress'),
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

  Widget _buildQuestionContent(BuildContext context) {
    final savedAnswer = session.getAnswerForQuestion(session.currentQuestionIndex);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(context),
          const SizedBox(height: 24),
          _buildAnswerOptions(context, savedAnswer),
          const SizedBox(height: 24),
          if (showingExplanation && question.explanation != null)
            _buildExplanationCard(context, question.explanation!),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context) {
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            _buildQuestionImage(context, question.questionImageUrl, question.questionImagePath),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
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
                    label: languageCubit.getLocalizedText(
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
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
                if (question.hasSubQuestion) ...[
                  const SizedBox(height: 8),
                  Text(
                    question.subQuestion!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: colorScheme.onSurfaceVariant,
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
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxHeight: 250,
          minHeight: 200,
        ),
        child: Stack(
          children: [
            CustomCachedImage(
              imageUrl: imageUrl,
              imagePath: imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
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

  Widget _buildAnswerOptions(BuildContext context, dynamic savedAnswer) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageCubit.getLocalizedText(korean: '답안 선택', english: 'Choose Answer'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildResponsiveAnswerOptions(context, savedAnswer),
      ],
    );
  }

  Widget _buildResponsiveAnswerOptions(BuildContext context, dynamic savedAnswer) {
    final hasImageAnswers = question.hasImageAnswers;
    
    if (hasImageAnswers) {
      return _buildAnswerOptionsGrid(context, savedAnswer);
    } else {
      return _buildAnswerList(context, savedAnswer);
    }
  }

  Widget _buildAnswerList(BuildContext context, dynamic savedAnswer) {
    return Column(
      children: question.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAnswerOption(context, index, option, savedAnswer),
        );
      }).toList(),
    );
  }

  Widget _buildAnswerOptionsGrid(BuildContext context, dynamic savedAnswer) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: question.options.length,
      itemBuilder: (context, index) {
        final option = question.options[index];
        return _buildAnswerOption(context, index, option, savedAnswer, isGrid: true);
      },
    );
  }

  Widget _buildAnswerOption(BuildContext context, int index, AnswerOption option, dynamic savedAnswer, {bool isGrid = false}) {
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
    
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onAnswerSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            color: backgroundColor,
          ),
          child: isGrid
            ? _buildGridOptionContent(context, index, option, isSelected || wasSelectedAnswer, borderColor, statusIcon)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
        children: [
          CustomCachedAudio(
            audioUrl: option.audioUrl,
            audioPath: option.audioPath,
            label: languageCubit.getLocalizedText(
              korean: '선택지 ${String.fromCharCode(65 + index)} 듣기',
              english: 'Listen to Option ${String.fromCharCode(65 + index)}',
            ),
            height: 50,
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
                      Positioned(
                        top: 4,
                        right: 4,
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
      return Container(
        width: double.infinity,
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

  Widget _buildTestNavigation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstQuestion = session.currentQuestionIndex == 0;
    final isLastQuestion = session.currentQuestionIndex == session.totalQuestions - 1;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (!isFirstQuestion)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPreviousQuestion,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(languageCubit.getLocalizedText(korean: '이전', english: 'Previous')),
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
              onPressed: () => isLastQuestion 
                  ? TestDialogs.showFinishConfirmation(
                      context,
                      languageCubit,
                      session,
                      () => onShowRatingDialog(session.test.title, session.test.id),
                    )
                  : onNextQuestion(),
              icon: Icon(isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 18),
              label: Text(
                isLastQuestion
                    ? languageCubit.getLocalizedText(korean: '완료', english: 'Finish')
                    : languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
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

  Widget _buildExplanationCard(BuildContext context, String explanation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 12),
          Text(
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