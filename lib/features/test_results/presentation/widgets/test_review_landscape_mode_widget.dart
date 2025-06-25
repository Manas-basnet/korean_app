import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/features/test_results/presentation/widgets/question_review_navigation_sheet.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/shared/models/test_answer.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/models/test_question.dart';
import 'package:korean_language_app/shared/models/test_result.dart';
import 'package:korean_language_app/core/utils/dialog_utils.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_audio.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/custom_cached_image.dart';

class TestReviewLandscapeModeWidget extends StatelessWidget {
  final TestResult testResult;
  final int currentQuestionIndex;
  final TestQuestion question;
  final TestAnswer? userAnswer;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onExitPressed;
  final VoidCallback onToggleOrientation;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final Function(int) onJumpToQuestion;

  const TestReviewLandscapeModeWidget({
    super.key,
    required this.testResult,
    required this.currentQuestionIndex,
    required this.question,
    required this.userAnswer,
    required this.languageCubit,
    required this.onExitPressed,
    required this.onToggleOrientation,
    required this.onPreviousQuestion,
    required this.onNextQuestion,
    required this.onJumpToQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final hasImageAnswers = question.hasImageAnswers;
    
    final questionFlex = hasImageAnswers ? 4 : 5;
    final answerFlex = hasImageAnswers ? 5 : 4;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(context),
            if (testResult.isLegacyResult) _buildLegacyDataWarning(context),
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
                          if (question.explanation != null) ...[
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
                      child: _buildAnswerReviewWithNavigation(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerReviewWithNavigation(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              languageCubit.getLocalizedText(korean: '답안 검토', english: 'Answer Review'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _buildCompactStatusIndicator(context),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _buildResponsiveAnswerOptions(context),
              ),
              const SizedBox(height: 8),
              _buildNavigationButtons(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstQuestion = currentQuestionIndex == 0;
    final isLastQuestion = currentQuestionIndex == testResult.testQuestions.length - 1;

    return SizedBox(
      height: 38,
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
              onPressed: isLastQuestion ? null : onNextQuestion,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
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

  Widget _buildResponsiveAnswerOptions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final availableHeight = constraints.maxHeight;
        
        final isSmallScreen = screenHeight < 400;
        
        if (question.hasImageAnswers) {
          return _buildResponsiveImageAnswers(context, availableHeight, isSmallScreen);
        } else {
          return _buildResponsiveTextAnswers(context, availableHeight, isSmallScreen);
        }
      },
    );
  }

  Widget _buildResponsiveImageAnswers(BuildContext context, double availableHeight, bool isSmallScreen) {
    final optionCount = question.options.length;
    
    if (isSmallScreen) {
      return _buildScrollableImageGrid(context);
    }
    
    int crossAxisCount;
    if (optionCount <= 2) {
      crossAxisCount = 1;
    } else if (optionCount <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 2;
    }
    
    const minItemHeight = 80.0;
    const spacing = 8.0;
    final itemsPerRow = crossAxisCount;
    final rowCount = (optionCount / itemsPerRow).ceil();
    final totalSpacing = (rowCount - 1) * spacing;
    final requiredHeight = (rowCount * minItemHeight) + totalSpacing;
    
    if (requiredHeight <= availableHeight) {
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
                          child: _buildCompactAnswerOption(
                            context, 
                            index, 
                            question.options[index], 
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
    } else {
      return _buildScrollableImageGrid(context);
    }
  }

  Widget _buildResponsiveTextAnswers(BuildContext context, double availableHeight, bool isSmallScreen) {
    final optionCount = question.options.length;
    const minItemHeight = 40.0;
    const spacing = 6.0;
    final totalSpacing = (optionCount - 1) * spacing;
    final requiredHeight = (optionCount * minItemHeight) + totalSpacing;
    
    if (isSmallScreen || requiredHeight > availableHeight) {
      return _buildScrollableTextList(context);
    }
    
    return Column(
      children: [
        for (int index = 0; index < optionCount; index++) ...[
          if (index > 0) const SizedBox(height: spacing),
          Expanded(
            child: _buildCompactAnswerOption(
              context, 
              index, 
              question.options[index], 
              isCompact: false
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScrollableImageGrid(BuildContext context) {
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
        return _buildCompactAnswerOption(context, index, option, isGrid: true);
      },
    );
  }

  Widget _buildScrollableTextList(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics()
      ),
      itemCount: question.options.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final option = question.options[index];
        return _buildCompactAnswerOption(context, index, option, isCompact: true);
      },
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
                    testResult.testTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentQuestionIndex + 1}/${testResult.testQuestions.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: LinearProgressIndicator(
                    value: (currentQuestionIndex + 1) / testResult.testQuestions.length,
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
          onPressed: () => TestReviewQuestionNavigationSheet.show(
            context,
            testResult,
            currentQuestionIndex,
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
        color: testResult.isPassed ? colorScheme.primaryContainer : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${testResult.score}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: testResult.isPassed ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCompactStatusIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = userAnswer?.isCorrect ?? false;
    final hasUserAnswer = userAnswer != null;

    if (!hasUserAnswer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.grey, size: 12),
            const SizedBox(width: 3),
            Text(
              languageCubit.getLocalizedText(korean: '미응답', english: 'No Answer'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.withValues(alpha: 0.1) 
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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
            size: 12,
          ),
          const SizedBox(width: 3),
          Text(
            isCorrect 
                ? languageCubit.getLocalizedText(korean: '정답', english: 'Correct')
                : languageCubit.getLocalizedText(korean: '오답', english: 'Incorrect'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAnswerOption(BuildContext context, int index, AnswerOption option, {bool isCompact = false, bool isGrid = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCorrectAnswer = index == question.correctAnswerIndex;
    final wasSelectedAnswer = userAnswer?.selectedAnswerIndex == index;
    
    Color borderColor = colorScheme.outlineVariant;
    Color backgroundColor = colorScheme.surface;
    Widget? statusIcon;
    
    if (isCorrectAnswer) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withValues(alpha: 0.1);
      statusIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16);
    } else if (wasSelectedAnswer) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.1);
      statusIcon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 16);
    }

    if (isGrid && option.isImage && (option.imageUrl?.isNotEmpty == true || option.imagePath?.isNotEmpty == true)) {
      return _buildImageGridOption(context, index, option, wasSelectedAnswer, borderColor, statusIcon);
    }
    
    return Container(
      padding: EdgeInsets.all(isCompact ? 6 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
        color: backgroundColor,
      ),
      child: isGrid
        ? _buildGridOptionContent(context, index, option, wasSelectedAnswer, borderColor, statusIcon)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCompactOptionSelector(context, index, wasSelectedAnswer, borderColor),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactOptionContent(context, index, option),
              ),
              if (statusIcon != null) ...[
                const SizedBox(width: 8),
                statusIcon,
              ],
            ],
          ),
    );
  }

  Widget _buildCompactOptionSelector(BuildContext context, int index, bool isSelected, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
        color: isSelected ? color : Colors.transparent,
      ),
      child: Center(
        child: Text(
          String.fromCharCode(65 + index),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactOptionContent(BuildContext context, int index, AnswerOption option) {
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
            const SizedBox(height: 4),
            Text(
              option.text,
              style: theme.textTheme.bodyMedium?.copyWith(
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
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
          textAlign: TextAlign.center,
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
              fit: BoxFit.contain,
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

  Widget _buildGridOptionContent(BuildContext context, int index, AnswerOption option, bool isSelected, Color color, Widget? statusIcon) {
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
          child: _buildCompactOptionContent(context, index, option),
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
              languageCubit.getLocalizedText(
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