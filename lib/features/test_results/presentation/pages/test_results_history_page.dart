import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:korean_language_app/shared/models/test_result.dart';
import 'package:korean_language_app/features/test_results/presentation/bloc/test_results_cubit.dart';

enum ResultFilter { all, passed, failed, recent }

class TestResultsHistoryPage extends StatefulWidget {
  const TestResultsHistoryPage({super.key});

  @override
  State<TestResultsHistoryPage> createState() => _TestResultsHistoryPageState();
}

class _TestResultsHistoryPageState extends State<TestResultsHistoryPage> {
  late ScrollController _scrollController;
  List<TestResult> _results = [];
  List<TestResult> _filteredResults = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  bool _showScrollToTop = false;
  ResultFilter _selectedFilter = ResultFilter.all;
  
  TestResultsCubit get _testResultsCubit => context.read<TestResultsCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  AuthCubit get _authCubit => context.read<AuthCubit>();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadResults();
      setState(() {
        _isInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showScrollToTop = _scrollController.offset > 300;
    if (showScrollToTop != _showScrollToTop) {
      setState(() {
        _showScrollToTop = showScrollToTop;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadResults() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = _authCubit.state;
      if (authState is! Authenticated) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final results = await _testResultsCubit.getTestResultsWithHandling();
      
      if (mounted) {
        setState(() {
          _results = results;
          _applyFilter();
          _isLoading = false;
          _error = null;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case ResultFilter.all:
        _filteredResults = _results;
        break;
      case ResultFilter.passed:
        _filteredResults = _results.where((r) => r.isPassed).toList();
        break;
      case ResultFilter.failed:
        _filteredResults = _results.where((r) => !r.isPassed).toList();
        break;
      case ResultFilter.recent:
        final now = DateTime.now();
        _filteredResults = _results.where((r) => 
          now.difference(r.completedAt).inDays <= 7
        ).toList();
        break;
    }
  }

  void _onFilterChanged(ResultFilter filter) {
    if (_selectedFilter == filter) return;
    
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadResults,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(theme, colorScheme),
            if(_results.isNotEmpty) 
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _buildIntegratedStats(theme, colorScheme),
                ),
              ),
            _buildSliverContent(),
          ],
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: AnimatedScale(
          scale: _showScrollToTop ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: FloatingActionButton(
            onPressed: _showScrollToTop ? _scrollToTop : null,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 4,
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ),
      ),
    );
  }

Widget _buildSliverAppBar(ThemeData theme, ColorScheme colorScheme) {
  return SliverAppBar(
    expandedHeight: 150,
    pinned: false,
    floating: true,
    snap: true,
    backgroundColor: colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: false,
    flexibleSpace: LayoutBuilder(
      builder: (context, constraints) {
        final expandRatio =
            (constraints.maxHeight - kToolbarHeight) / (140 - kToolbarHeight);
        final isExpanded = expandRatio > 0.1;

        return FlexibleSpaceBar(
          background: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha : 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AnimatedOpacity(
                  opacity: isExpanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: colorScheme.onSurface,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: colorScheme.onSurface,
                            ),
                            tooltip: _languageCubit.getLocalizedText(
                              korean: '뒤로',
                              english: 'Back',
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _languageCubit.getLocalizedText(
                                korean: '내 시험 결과',
                                english: 'My Test Results',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFilterTabs(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildFilterTabs(ThemeData theme) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: ResultFilter.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = ResultFilter.values[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => _onFilterChanged(filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha : 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _getFilterDisplayName(filter),
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha : 0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntegratedStats(ThemeData theme, ColorScheme colorScheme) {
    final totalTests = _results.length;
    final passedTests = _results.where((r) => r.isPassed).length;
    final averageScore = totalTests > 0 
        ? _results.map((r) => r.score).reduce((a, b) => a + b) / totalTests
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha : 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha : 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha : 0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: colorScheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _languageCubit.getLocalizedText(
                  korean: '성과 요약',
                  english: 'Performance Overview',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  _languageCubit.getLocalizedText(korean: '총 시험', english: 'Total'),
                  totalTests.toString(),
                  Icons.quiz_rounded,
                  Colors.blue[600]!,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatCard(
                  _languageCubit.getLocalizedText(korean: '합격', english: 'Passed'),
                  passedTests.toString(),
                  Icons.check_circle_rounded,
                  Colors.green[600]!,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatCard(
                  _languageCubit.getLocalizedText(korean: '평균 점수', english: 'Avg Score'),
                  '${averageScore.toStringAsFixed(0)}%',
                  Icons.trending_up_rounded,
                  Colors.orange[600]!,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha : 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
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
              color: color.withValues(alpha : 0.8),
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getFilterDisplayName(ResultFilter filter) {
    switch (filter) {
      case ResultFilter.all:
        return _languageCubit.getLocalizedText(korean: '전체', english: 'All');
      case ResultFilter.passed:
        return _languageCubit.getLocalizedText(korean: '합격', english: 'Passed');
      case ResultFilter.failed:
        return _languageCubit.getLocalizedText(korean: '불합격', english: 'Failed');
      case ResultFilter.recent:
        return _languageCubit.getLocalizedText(korean: '최근', english: 'Recent');
    }
  }

  Widget _buildSliverContent() {
    if (_isLoading && _results.isEmpty) {
      return _buildLoadingView();
    }

    if (_error != null && _results.isEmpty) {
      return _buildErrorView();
    }

    if (_filteredResults.isEmpty && _results.isNotEmpty) {
      return _buildNoResultsForFilterView();
    }

    if (_results.isEmpty) {
      return _buildEmptyView();
    }

    return _buildResultsList();
  }

  Widget _buildLoadingView() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.4,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _languageCubit.getLocalizedText(
                korean: '결과를 불러올 수 없습니다',
                english: 'Failed to load results',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                _languageCubit.getLocalizedText(
                  korean: '다시 시도',
                  english: 'Try Again',
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
    );
  }

  Widget _buildEmptyView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha : 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.quiz_outlined,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _languageCubit.getLocalizedText(
                korean: '아직 시험 결과가 없습니다',
                english: 'No test results yet',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _languageCubit.getLocalizedText(
                korean: '시험을 치르면 결과가 여기에 표시됩니다',
                english: 'Take some tests and your results will appear here',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go(Routes.tests),
              icon: const Icon(Icons.quiz_rounded),
              label: Text(
                _languageCubit.getLocalizedText(
                  korean: '시험 보러 가기',
                  english: 'Take a Test',
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
    );
  }

  Widget _buildNoResultsForFilterView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.3,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 60,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _languageCubit.getLocalizedText(
                korean: '선택한 필터에 해당하는 결과가 없습니다',
                english: 'No results match the selected filter',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final result = _filteredResults[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildResultCard(result),
            );
          },
          childCount: _filteredResults.length,
        ),
      ),
    );
  }

  Widget _buildResultCard(TestResult result) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.isPassed 
              ? Colors.green.withValues(alpha : 0.15)
              : Colors.red.withValues(alpha : 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha : 0.04),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _goToDetails(result),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.testTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(result.completedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: result.isPassed 
                            ? Colors.green.withValues(alpha : 0.1)
                            : Colors.red.withValues(alpha : 0.1),
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
                                ? _languageCubit.getLocalizedText(korean: '합격', english: 'PASS')
                                : _languageCubit.getLocalizedText(korean: '불합격', english: 'FAIL'),
                            style: TextStyle(
                              color: result.isPassed ? Colors.green[700] : Colors.red[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(alpha : 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildResultInfo(
                          Icons.percent_rounded,
                          '${result.score}%',
                          _languageCubit.getLocalizedText(korean: '점수', english: 'Score'),
                          result.isPassed ? Colors.green[600]! : Colors.red[600]!,
                          theme,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: colorScheme.surfaceContainerHigh.withValues(alpha : 0.6),
                      ),
                      Expanded(
                        child: _buildResultInfo(
                          Icons.check_circle_outline_rounded,
                          '${result.correctAnswers}/${result.totalQuestions}',
                          _languageCubit.getLocalizedText(korean: '정답', english: 'Correct'),
                          Colors.blue[600]!,
                          theme,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: colorScheme.surfaceContainerHigh.withValues(alpha : 0.6),
                      ),
                      Expanded(
                        child: _buildResultInfo(
                          Icons.timer_rounded,
                          result.formattedDuration,
                          _languageCubit.getLocalizedText(korean: '시간', english: 'Time'),
                          Colors.orange[600]!,
                          theme,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultInfo(IconData icon, String value, String label, Color color, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: color.withValues(alpha : 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return _languageCubit.getLocalizedText(korean: '오늘', english: 'Today');
    } else if (difference == 1) {
      return _languageCubit.getLocalizedText(korean: '어제', english: 'Yesterday');
    } else if (difference < 7) {
      return _languageCubit.getLocalizedText(korean: '$difference일 전', english: '$difference days ago');
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _goToDetails(TestResult result) {
    context.push(Routes.testResult, extra: result);
  }

}