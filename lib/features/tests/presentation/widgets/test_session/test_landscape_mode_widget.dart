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



class TestLandscapeModeWidget extends StatelessWidget {
  final TestSession session;
  final TestQuestion question;
  final bool isPaused;
  final LanguagePreferenceCubit languageCubit;
  final int? selectedAnswerIndex;
  final bool showingExplanation;
  final VoidCallback onExitPressed;
  final VoidCallback onToggleOrientation;
  final VoidCallback onToggleExplanation;
  final Function(int) onAnswerSelected;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final Function(String, String) onShowRatingDialog;
  final Function(int) onJumpToQuestion;

  const TestLandscapeModeWidget({
    super.key,
    required this.session,
    required this.question,
    required this.isPaused,
    required this.languageCubit,
    required this.selectedAnswerIndex,
    required this.showingExplanation,
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
    final savedAnswer = session.getAnswerForQuestion(session.currentQuestionIndex);
    final hasImageAnswers = question.hasImageAnswers;
    
    final questionFlex = hasImageAnswers ? 4 : 5;
    final answerFlex = hasImageAnswers ? 5 : 4;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(context),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: questionFlex,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildLandscapeQuestionContent(context),
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
                    ),
                  ),
                  
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  
                  Expanded(
                    flex: answerFlex,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageCubit.getLocalizedText(korean: '답안 선택', english: 'Choose Answer'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _buildLandscapeAnswerOptions(context, savedAnswer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildLandscapeFloatingActions(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMinimalHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onExitPressed,
            icon: const Icon(Icons.close_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurfaceVariant,
              minimumSize: const Size(32, 32),
              padding: const EdgeInsets.all(4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Text(
                    session.test.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.currentQuestionIndex + 1}/${session.totalQuestions}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: LinearProgressIndicator(
                    value: session.progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderActions(context),
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
          icon: const Icon(Icons.stay_current_portrait_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          tooltip: languageCubit.getLocalizedText(korean: '세로 모드', english: 'Portrait Mode'),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
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

  Widget _buildLandscapeAnswerOptions(BuildContext context, TestAnswer? savedAnswer) {
    final hasImageAnswers = question.hasImageAnswers;
    
    if (hasImageAnswers) {
      return _buildLandscapeImageAnswerGrid(context, savedAnswer);
    } else {
      return _buildLandscapeTextAnswerList(context, savedAnswer);
    }
  }

  Widget _buildLandscapeImageAnswerGrid(BuildContext context, TestAnswer? savedAnswer) {
    final optionCount = question.options.length;
    
    int crossAxisCount;
    double childAspectRatio;
    
    if (optionCount <= 2) {
      crossAxisCount = 1;
      childAspectRatio = 2.0;
    } else if (optionCount <= 4) {
      crossAxisCount = 2;
      childAspectRatio = 1.2;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    }
    
    return GridView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics()
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: optionCount,
      itemBuilder: (context, index) {
        final option = question.options[index];
        return _buildCompactAnswerOption(context, index, option, savedAnswer, isGrid: true);
      },
    );
  }

  Widget _buildLandscapeTextAnswerList(BuildContext context, TestAnswer? savedAnswer) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics()
      ),
      itemCount: question.options.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final option = question.options[index];
        return _buildCompactAnswerOption(context, index, option, savedAnswer, isCompact: true);
      },
    );
  }

  Widget _buildCompactAnswerOption(BuildContext context, int index, AnswerOption option, TestAnswer? savedAnswer, {bool isCompact = false, bool isGrid = false}) {
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
        statusIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16);
      } else if (wasSelectedAnswer) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        statusIcon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 16);
      }
    } else if (isSelected || wasSelectedAnswer) {
      borderColor = colorScheme.primary;
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.2);
    }
    
    return Material(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onAnswerSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isCompact ? 6 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.2),
            color: backgroundColor,
          ),
          child: isGrid
            ? _buildGridOptionContent(context, index, option, isSelected || wasSelectedAnswer, borderColor, statusIcon, isCompact: true)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactOptionSelector(context, index, isSelected || wasSelectedAnswer, borderColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactOptionContent(context, index, option, isCompact: true),
                  ),
                  if (statusIcon != null) ...[
                    const SizedBox(width: 8),
                    statusIcon,
                  ],
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildCompactOptionSelector(BuildContext context, int index, bool isSelected, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
        color: isSelected ? color : Colors.transparent,
      ),
      child: Center(
        child: isSelected
            ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 12)
            : Text(
                String.fromCharCode(65 + index),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 10,
                ),
              ),
      ),
    );
  }

  Widget _buildCompactOptionContent(BuildContext context, int index, AnswerOption option, {bool isCompact = false}) {
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
            height: 56,
          ),
          if (option.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              option.text,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.2,
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
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
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
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.zoom_out_map_rounded,
                            color: Colors.white,
                            size: 10,
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
            const SizedBox(height: 4),
            Text(
              option.text,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    } else {
      return Text(
        option.text,
        style: theme.textTheme.bodySmall?.copyWith(
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  Widget _buildLandscapeQuestionContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = (question.questionImageUrl?.isNotEmpty == true) || 
                    (question.questionImagePath?.isNotEmpty == true);
    final hasAudio = (question.questionAudioUrl?.isNotEmpty == true) || 
                    (question.questionAudioPath?.isNotEmpty == true);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            _buildQuestionImage(context,
              question.questionImageUrl, 
              question.questionImagePath, 
              isLandscape: true,
              showFullImage: true,
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
              height: 40,
            ),
          ],
        
          if (question.question.isNotEmpty || question.hasSubQuestion)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      languageCubit.getLocalizedText(korean: '문제', english: 'Question'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (question.question.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      question.question,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (question.hasSubQuestion) ...[
                    const SizedBox(height: 4),
                    Text(
                      question.subQuestion!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 1.2,
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

  Widget _buildQuestionImage(BuildContext context, String? imageUrl, String? imagePath, {bool isLandscape = false, bool showFullImage = false}) {
    if (showFullImage) {
      return GestureDetector(
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
            maxHeight: 200,
            minHeight: 150,
          ),
          child: Stack(
            children: [
              CustomCachedImage(
                imageUrl: imageUrl,
                imagePath: imagePath,
                fit: BoxFit.contain,
                width: double.infinity,
                borderRadius: BorderRadius.circular(16),
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
                    Icons.zoom_out_map_rounded,
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
        constraints: BoxConstraints(
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
              borderRadius: isLandscape
                  ? BorderRadius.circular(16)
                  : const BorderRadius.vertical(top: Radius.circular(16)),
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

  Widget _buildLandscapeFloatingActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFirstQuestion = session.currentQuestionIndex == 0;
    final isLastQuestion = session.currentQuestionIndex == session.totalQuestions - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isFirstQuestion) ...[
          FloatingActionButton.small(
            heroTag: "previous",
            onPressed: onPreviousQuestion,
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurfaceVariant,
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          heroTag: "next",
          onPressed: () => isLastQuestion 
              ? TestDialogs.showFinishConfirmation(
                  context,
                  languageCubit,
                  session,
                  () => onShowRatingDialog(session.test.title, session.test.id),
                )
              : onNextQuestion(),
          backgroundColor: isLastQuestion ? Colors.green : colorScheme.primary,
          foregroundColor: Colors.white,
          child: Icon(
            isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded,
            size: 24,
          ),
        ),
      ],
    );
  }



  Widget _buildGridOptionContent(BuildContext context, int index, AnswerOption option, bool isSelected, Color color, Widget? statusIcon, {bool isCompact = false}) {
    return Column(
      children: [
        Row(
          children: [
            _buildCompactOptionSelector(context, index, isSelected, color),
            const Spacer(),
            if (statusIcon != null) statusIcon,
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildCompactOptionContent(context, index, option, isCompact: true),
        ),
      ],
    );
  }

  Widget _buildExplanationCard(BuildContext context, String explanation, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 20),
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
}