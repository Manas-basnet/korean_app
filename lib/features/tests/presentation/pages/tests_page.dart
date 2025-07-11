import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/sort_bottomsheet.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_detail_bottomsheet.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';
import 'package:korean_language_app/features/test_upload/presentation/bloc/test_upload_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/test_search/test_search_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/bloc/tests_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_search_delegate.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_card.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_grid_skeleton.dart';

class TestsPage extends StatefulWidget {
  const TestsPage({super.key});

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  late ScrollController _scrollController;
  bool _isRefreshing = false;
  bool _isInitialized = false;
  TestCategory _selectedCategory = TestCategory.all;
  TestSortType _selectedSortType = TestSortType.recent;
  String _searchQuery = '';
  bool _isSearching = false;
  
  Timer? _scrollDebounceTimer;
  static const Duration _scrollDebounceDelay = Duration(milliseconds: 100);
  bool _hasTriggeredLoadMore = false;
  
  TestsCubit get _testsCubit => context.read<TestsCubit>();
  TestSearchCubit get _testSearchCubit => context.read<TestSearchCubit>();
  TestUploadCubit get _testUploadCubit => context.read<TestUploadCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testsCubit.loadInitialTests();
      setState(() {
        _isInitialized = true;
      });
    });
    
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }
  
  void _onScroll() {
    if (!_scrollController.hasClients || _isRefreshing || _isSearching) return;
    
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_scrollDebounceDelay, () {
      if (!mounted) return;
      
      if (_isNearBottom()) {
        final state = _testsCubit.state;
        
        if (state.hasMore && 
            !state.currentOperation.isInProgress && 
            !_hasTriggeredLoadMore) {
          
          _hasTriggeredLoadMore = true;
          _testsCubit.requestLoadMoreTests();
          
          Timer(const Duration(seconds: 1), () {
            if (mounted) {
              _hasTriggeredLoadMore = false;
            }
          });
        }
      } else {
        _hasTriggeredLoadMore = false;
      }
    });
  }
  
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return false;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    return maxScroll > 0 && currentScroll >= (maxScroll * 0.7);
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    
    try {
      if (_isSearching) {
        _testSearchCubit.searchTests(_searchQuery);
      } else {
        await _testsCubit.hardRefresh();
      }
      _hasTriggeredLoadMore = false;
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _onCategoryChanged(TestCategory category) {
    if (_selectedCategory == category) return;
    
    setState(() {
      _selectedCategory = category;
      _isSearching = false;
      _searchQuery = '';
      _hasTriggeredLoadMore = false;
    });
    
    if (category == TestCategory.all) {
      _testsCubit.loadInitialTests(sortType: _selectedSortType);
    } else {
      _testsCubit.loadTestsByCategory(category, sortType: _selectedSortType);
    }
  }

  void _onSortTypeChanged(TestSortType sortType) {
    if (_selectedSortType == sortType) return;
    
    setState(() {
      _selectedSortType = sortType;
      _hasTriggeredLoadMore = false;
    });
    
    _testsCubit.changeSortType(sortType);
  }

  void _showSortBottomSheet() {
    SortBottomSheet.show(
      context,
      selectedSortType: _selectedSortType,
      languageCubit: _languageCubit,
      onSortTypeChanged: _onSortTypeChanged,
    );
  }

  void _showSearchDelegate() {
    showSearch(
      context: context,
      delegate: TestSearchDelegate(
        testSearchCubit: _testSearchCubit,
        languageCubit: _languageCubit,
        onTestSelected: _startTest,
        checkEditPermission: (test) async {
          return await _testsCubit.canUserEditTest(test);
        },
        onEditTest: _editTest,
        onDeleteTest: _deleteTest,
        onViewDetails: _viewTestDetails,
      ),
    );
  }

  IconData _getSortTypeIcon(TestSortType sortType) {
    switch (sortType) {
      case TestSortType.recent:
        return Icons.schedule_outlined;
      case TestSortType.popular:
        return Icons.trending_up_outlined;
      case TestSortType.rating:
        return Icons.star_outline;
      case TestSortType.viewCount:
        return Icons.visibility_outlined;
    }
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
      floatingActionButton: FloatingActionButton(
        heroTag: "tests_page_fab",
        onPressed: () => context.push(Routes.testUpload),
        tooltip: _languageCubit.getLocalizedText(
          korean: '시험 만들기',
          english: 'Create Test',
        ),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          cacheExtent: 600,
          slivers: [                
            _buildSliverAppBar(theme, colorScheme),
            _buildSliverContent(),
          ],
        ),
      )
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 140,
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
              (constraints.maxHeight - kToolbarHeight) / (120 - kToolbarHeight);
          final isExpanded = expandRatio > 0.1;

          return FlexibleSpaceBar(
            background: Container(
              color: colorScheme.surface,
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _languageCubit.getLocalizedText(
                                    korean: '시험',
                                    english: 'Tests',
                                  ),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if(kIsWeb)
                                  IconButton(
                                    icon: const Icon(Icons.refresh_outlined),
                                    onPressed: () {
                                      context.read<TestsCubit>().hardRefresh();
                                    },
                                    tooltip: _languageCubit.getLocalizedText(
                                      korean: '새로고침',
                                      english: 'Refresh',
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.search_outlined),
                                  onPressed: _showSearchDelegate,
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '검색',
                                    english: 'Search',
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.drafts_outlined),
                                  onPressed: () => context.push(Routes.unpublishedTests),
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '비공개 시험',
                                    english: 'Unpublished Tests',
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.analytics_outlined),
                                  onPressed: () => context.push(Routes.testResults),
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '내 결과',
                                    english: 'My Results',
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoryTabs(theme),
                            ),
                            const SizedBox(width: 12),
                            _buildSortButton(theme, colorScheme),
                          ],
                        ),
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

  Widget _buildCategoryTabs(ThemeData theme) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: TestCategory.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = TestCategory.values[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () => _onCategoryChanged(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                category.getDisplayName(_languageCubit.getLocalizedText),
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortButton(ThemeData theme, ColorScheme colorScheme) {
    return OutlinedButton.icon(
      onPressed: _showSortBottomSheet,
      icon: Icon(
        _getSortTypeIcon(_selectedSortType),
        size: 16,
      ),
      label: const Icon(Icons.sort, size: 16),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
  
  Widget _buildSliverContent() {
    return BlocConsumer<TestsCubit, TestsState>(
      listener: (context, state) {
        final operation = state.currentOperation;
        
        if (operation.status == TestsOperationStatus.failed) {
          String errorMessage = operation.message ?? 'Operation failed';
          
          switch (operation.type) {
            case TestsOperationType.loadTests:
              errorMessage = 'Failed to load tests';
              break;
            case TestsOperationType.loadMoreTests:
              errorMessage = 'Failed to load more tests';
              break;
            case TestsOperationType.refreshTests:
              errorMessage = 'Failed to refresh tests';
              break;
            default:
              break;
          }
          
          _snackBarCubit.showErrorLocalized(
            korean: errorMessage,
            english: errorMessage,
          );
        }
        
        if (state.hasError) {
          _snackBarCubit.showErrorLocalized(
            korean: state.error ?? '오류가 발생했습니다.',
            english: state.error ?? 'An error occurred.',
          );
        }
      },
      builder: (context, state) {
        final screenSize = MediaQuery.sizeOf(context);
        
        if (state.isLoading && state.tests.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.6,
              child: const TestGridSkeleton(),
            ),
          );
        }
        
        if (state.hasError && state.tests.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.7,
              child: ErrorView(
                message: state.error ?? '',
                errorType: state.errorType,
                onRetry: () {
                  if (_selectedCategory == TestCategory.all) {
                    _testsCubit.loadInitialTests(sortType: _selectedSortType);
                  } else {
                    _testsCubit.loadTestsByCategory(_selectedCategory, sortType: _selectedSortType);
                  }
                },
              ),
            ),
          );
        }
        
        return _buildSliverTestsList(state, screenSize);
      },
    );
  }
  
  Widget _buildSliverTestsList(TestsState state, Size screenSize) {
    if (state.tests.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyTestsView());
    }
    
    final isTablet = screenSize.width > 600;
    final isMonitor = screenSize.width > 1024;
    final crossAxisCount = isMonitor ? 4 : isTablet ? 3 : 2;
    final childAspectRatio = isMonitor ? 0.7 : isTablet ? 0.6 : 0.65;
    
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
            ),
            itemCount: state.tests.length,
            itemBuilder: (context, index) {
              final test = state.tests[index];
              return TestCard(
                test: test,
                canEdit: true,
                onTap: () => _startTest(test),
                onLongPress: () => _viewTestDetails(test),
                onEdit: () => _editTest(test),
                onDelete: () => _deleteTest(test),
                onViewDetails: () => _viewTestDetails(test),
              );
            },
          ),
        ),
        _buildLoadMoreIndicator(state),
      ]),
    );
  }

  Widget _buildLoadMoreIndicator(TestsState state) {
    final isLoadingMore = state.currentOperation.type == TestsOperationType.loadMoreTests &&
        state.currentOperation.status == TestsOperationStatus.inProgress;
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isLoadingMore) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _languageCubit.getLocalizedText(
                korean: '더 많은 시험을 불러오는 중...',
                english: 'Loading more tests...',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!state.hasMore && state.tests.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _languageCubit.getLocalizedText(
                      korean: '더 이상 시험이 없습니다',
                      english: 'No more tests',
                    ),
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
    
    return const SizedBox.shrink();
  }

  Widget _buildEmptyTestsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    
    return Container(
      width: double.infinity,
      height: screenSize.height * 0.6,
      padding: EdgeInsets.all(screenSize.width * 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            _languageCubit.getLocalizedText(
              korean: '시험이 없습니다',
              english: 'No tests available',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageCubit.getLocalizedText(
              korean: '새 시험을 만들어보세요',
              english: 'Create your first test',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.push(Routes.testUpload),
            icon: const Icon(Icons.add),
            label: Text(
              _languageCubit.getLocalizedText(
                korean: '시험 만들기',
                english: 'Create Test',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _startTest(TestItem test) async {
    if (test.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '시험 ID가 유효하지 않습니다',
        english: 'Invalid test ID',
      );
      return;
    }

    _snackBarCubit.showProgressLocalized(
      korean: '시험을 준비하고 있습니다...',
      english: 'Preparing test...',
    );

    try {
      await _testsCubit.loadTestById(test.id);

      final testsState = _testsCubit.state;
      final operation = testsState.currentOperation;
      
      if (operation.type == TestsOperationType.loadTestById && 
          operation.status == TestsOperationStatus.completed && 
          testsState.selectedTest != null) {
        _snackBarCubit.dismiss();
        context.push(Routes.testTaking(test.id));
      } else {
        String errorMessage;
        if (testsState.hasError) {
          errorMessage = testsState.errorType == FailureType.network
              ? _languageCubit.getLocalizedText(
                  korean: '오프라인 상태에서는 캐시된 시험만 이용할 수 있습니다',
                  english: 'Only cached tests are available offline',
                )
              : testsState.error ?? _languageCubit.getLocalizedText(
                  korean: '시험을 불러올 수 없습니다',
                  english: 'Failed to load test',
                );
        } else {
          errorMessage = _languageCubit.getLocalizedText(
            korean: '시험을 찾을 수 없습니다',
            english: 'Test not found',
          );
        }
        
        _snackBarCubit.showError(message: errorMessage);
      }
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '시험을 불러오는 중 오류가 발생했습니다',
        english: 'Error loading test',
      );
    }
  }
    
  void _viewTestDetails(TestItem test) {
    HapticFeedback.lightImpact();
    TestDetailsBottomSheet.show(
      context, 
      test: test,
      languageCubit: _languageCubit,
      onStartTest: () => _startTest(test),
    );
  }
  
  void _editTest(TestItem test) async {
    if (test.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '시험 ID가 유효하지 않습니다',
        english: 'Invalid test ID',
      );
      return;
    }

    final hasPermission = await _testsCubit.canUserEditTest(test);
    if (!hasPermission) {
      _snackBarCubit.showErrorLocalized(
        korean: '이 시험을 편집할 권한이 없습니다',
        english: 'You do not have permission to edit this test',
      );
      return;
    }

    final result = await context.push(Routes.testEdit(test.id));

    if (result == true) {
      _refreshData();
    }
  }

  void _deleteTest(TestItem test) async {
    final hasPermission = await _testsCubit.canUserDeleteTest(test);
    if (!hasPermission) {
      _snackBarCubit.showErrorLocalized(
        korean: '이 시험을 삭제할 권한이 없습니다',
        english: 'You do not have permission to delete this test',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '시험 삭제',
            english: 'Delete Test',
          ),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '"${test.title}"을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.',
            english: 'Are you sure you want to delete "${test.title}"? This action cannot be undone.',
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '취소',
                english: 'CANCEL',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '삭제',
                english: 'DELETE',
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      final success = await _testUploadCubit.deleteExistingTest(test.id);
      
      if (success) {
        _snackBarCubit.showSuccessLocalized(
          korean: '시험이 성공적으로 삭제되었습니다',
          english: 'Test deleted successfully',
        );
        
        _refreshData();
      } else {
        _snackBarCubit.showErrorLocalized(
          korean: '시험 삭제에 실패했습니다',
          english: 'Failed to delete test',
        );
      }
    }
  }
}