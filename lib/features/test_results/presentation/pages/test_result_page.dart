import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/core/shared/models/test_result.dart';

class TestResultPage extends StatelessWidget {
  final TestResult result;

  const TestResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCubit = context.read<LanguagePreferenceCubit>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
          ),
        ),
        title: Text(
          languageCubit.getLocalizedText(
            korean: '시험 결과',
            english: 'Test Results',
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildResultHeader(context, theme, colorScheme, languageCubit),
            const SizedBox(height: 16),
            _buildScoreSection(context, theme, colorScheme, languageCubit),
            const SizedBox(height: 16),
            _buildStatsGrid(context, theme, colorScheme, languageCubit),
            const SizedBox(height: 16),
            _buildDetailsSection(context, theme, colorScheme, languageCubit),
            const SizedBox(height: 20),
            _buildActionButtons(context, theme, colorScheme, languageCubit),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context, ThemeData theme, ColorScheme colorScheme, LanguagePreferenceCubit languageCubit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.isPassed 
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: result.isPassed 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
            ),
            child: Icon(
              result.isPassed ? Icons.celebration_rounded : Icons.sentiment_dissatisfied_rounded,
              size: 24,
              color: result.isPassed ? Colors.green[600] : Colors.red[600],
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isPassed
                      ? languageCubit.getLocalizedText(korean: '축하합니다!', english: 'Congratulations!')
                      : languageCubit.getLocalizedText(korean: '아쉽네요', english: 'Keep Trying!'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: result.isPassed ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  result.testTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: result.isPassed 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  result.isPassed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 14,
                  color: result.isPassed ? Colors.green[700] : Colors.red[700],
                ),
                const SizedBox(width: 6),
                Text(
                  result.isPassed
                      ? languageCubit.getLocalizedText(korean: '합격', english: 'PASS')
                      : languageCubit.getLocalizedText(korean: '불합격', english: 'FAIL'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: result.isPassed ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(BuildContext context, ThemeData theme, ColorScheme colorScheme, LanguagePreferenceCubit languageCubit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: result.score / 100,
                  strokeWidth: 6,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    result.isPassed ? Colors.green[600]! : Colors.red[600]!,
                  ),
                ),
              ),
              Text(
                '${result.score}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: result.isPassed ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.percent_rounded,
                        color: colorScheme.primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      languageCubit.getLocalizedText(
                        korean: '최종 점수',
                        english: 'Final Score',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (result.resultSummary.isNotEmpty)
                  Text(
                    result.resultSummary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${result.correctAnswers} / ${result.totalQuestions} ${languageCubit.getLocalizedText(korean: '문제 정답', english: 'questions correct')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, ThemeData theme, ColorScheme colorScheme, LanguagePreferenceCubit languageCubit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              languageCubit.getLocalizedText(korean: '정답', english: 'Correct'),
              '${result.correctAnswers}',
              Icons.check_circle_rounded,
              Colors.green[600]!,
              theme,
              colorScheme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              languageCubit.getLocalizedText(korean: '오답', english: 'Wrong'),
              '${result.totalQuestions - result.correctAnswers}',
              Icons.cancel_rounded,
              Colors.red[600]!,
              theme,
              colorScheme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              languageCubit.getLocalizedText(korean: '시간', english: 'Time'),
              result.formattedDuration,
              Icons.timer_rounded,
              Colors.blue[600]!,
              theme,
              colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, ThemeData theme, ColorScheme colorScheme, LanguagePreferenceCubit languageCubit) {
    final averageTimePerQuestion = result.totalQuestions > 0 
        ? result.totalTimeSpent / result.totalQuestions 
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                languageCubit.getLocalizedText(
                  korean: '상세 정보',
                  english: 'Details',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildDetailRow(
            languageCubit.getLocalizedText(korean: '시작 시간', english: 'Started'),
            _formatDateTime(result.startedAt),
            Icons.play_arrow_rounded,
            theme,
            colorScheme,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            languageCubit.getLocalizedText(korean: '완료 시간', english: 'Completed'),
            _formatDateTime(result.completedAt),
            Icons.flag_rounded,
            theme,
            colorScheme,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            languageCubit.getLocalizedText(korean: '문제당 평균 시간', english: 'Avg. per Question'),
            '${averageTimePerQuestion.toStringAsFixed(1)}s',
            Icons.av_timer_rounded,
            theme,
            colorScheme,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            languageCubit.getLocalizedText(korean: '총 문항 수', english: 'Total Questions'),
            '${result.totalQuestions}',
            Icons.quiz_rounded,
            theme,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme, ColorScheme colorScheme, LanguagePreferenceCubit languageCubit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.testReview, extra: result),
              icon: const Icon(Icons.rate_review_rounded, size: 20),
              label: Text(
                languageCubit.getLocalizedText(
                  korean: '답안 검토하기',
                  english: 'Review Answers',
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pushReplacement(Routes.testResults),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(
                      korean: '내 결과',
                      english: 'My Results',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go(Routes.tests),
                  icon: const Icon(Icons.quiz_rounded, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(
                      korean: '다른 시험',
                      english: 'More Tests',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    foregroundColor: colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}