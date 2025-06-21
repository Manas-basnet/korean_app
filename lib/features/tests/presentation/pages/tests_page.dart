import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/presentation/connectivity/bloc/connectivity_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
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
  final Map<String, bool> _editPermissionCache = {};
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
      context.read<ConnectivityCubit>().checkConnectivity();
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
    
    return maxScroll > 0 && currentScroll >= (maxScroll * 0.8);
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    
    try {
      if (_isSearching) {
        _testSearchCubit.searchTests(_searchQuery);
      } else {
        await _testsCubit.hardRefresh();
      }
      _editPermissionCache.clear();
      _hasTriggeredLoadMore = false;
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<bool> _checkEditPermission(String testId) async {
    if (_editPermissionCache.containsKey(testId)) {
      return _editPermissionCache[testId]!;
    }
    
    final hasPermission = await _testsCubit.canUserEditTest(testId);
    _editPermissionCache[testId] = hasPermission;
    return hasPermission;
  }

  void _onCategoryChanged(TestCategory category) {
    if (_selectedCategory == category) return;
    
    setState(() {
      _selectedCategory = category;
      _isSearching = false;
      _searchQuery = '';
      _hasTriggeredLoadMore = false;
    });
    
    _editPermissionCache.clear();
    
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
    
    _editPermissionCache.clear();
    _testsCubit.changeSortType(sortType);
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildSortBottomSheet(),
    );
  }

  Widget _buildSortBottomSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _languageCubit.getLocalizedText(
                  korean: '정렬',
                  english: 'Sort',
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...TestSortType.values.map((sortType) {
            final isSelected = _selectedSortType == sortType;
            return ListTile(
              leading: Icon(
                _getSortTypeIcon(sortType),
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                sortType.getDisplayName(_languageCubit.getLocalizedText),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              trailing: isSelected 
                  ? Icon(Icons.check_rounded, color: colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _onSortTypeChanged(sortType);
              },
            );
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getSortTypeIcon(TestSortType sortType) {
    switch (sortType) {
      case TestSortType.recent:
        return Icons.schedule_rounded;
      case TestSortType.popular:
        return Icons.trending_up_rounded;
      case TestSortType.rating:
        return Icons.star_rounded;
      case TestSortType.viewCount:
        return Icons.visibility_rounded;
    }
  }

  void _showSearchDelegate() {
    showSearch(
      context: context,
      delegate: TestSearchDelegate(
        testSearchCubit: _testSearchCubit,
        languageCubit: _languageCubit,
        onTestSelected: _startTest,
        checkEditPermission: _checkEditPermission,
        onEditTest: _editTest,
        onDeleteTest: _deleteTest,
        onViewDetails: _viewTestDetails,
      ),
    );
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
        onPressed: () => context.push(Routes.testUpload),
        tooltip: _languageCubit.getLocalizedText(
          korean: '시험 만들기',
          english: 'Create Test',
        ),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, connectivityState) {
          final bool isOffline = connectivityState is ConnectivityDisconnected;
          
          return RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (isOffline)
                  SliverToBoxAdapter(
                    child: ErrorView(
                      message: '',
                      errorType: FailureType.network,
                      onRetry: () {
                        context.read<ConnectivityCubit>().checkConnectivity();
                      },
                      isCompact: true,
                    ),
                  ),
                
                _buildSliverAppBar(theme, colorScheme),
                _buildSliverContent(isOffline),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 170,
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
              (constraints.maxHeight - kToolbarHeight) / (160 - kToolbarHeight);
          final isExpanded = expandRatio > 0.1;

          return FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _languageCubit.getLocalizedText(
                                korean: '시험',
                                english: 'Tests',
                              ),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            _buildHeaderActions(colorScheme)
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCategoryTabsSliver(theme),
                        const SizedBox(height: 12),
                        _buildSortChip(theme, colorScheme),
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

  Widget _buildSortChip(ThemeData theme, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _showSortBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getSortTypeIcon(_selectedSortType),
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedSortType.getDisplayName(_languageCubit.getLocalizedText),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabsSliver(ThemeData theme) {
    return SizedBox(
      height: 40,
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
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _getCategoryDisplayName(category),
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  String _getCategoryDisplayName(TestCategory category) {
    switch (category) {
      case TestCategory.all:
        return _languageCubit.getLocalizedText(
          korean: '전체',
          english: 'All',
        );
      case TestCategory.practice:
        return _languageCubit.getLocalizedText(
          korean: '연습',  
          english: 'Practice',
        );
      case TestCategory.topikI:
        return _languageCubit.getLocalizedText(
          korean: 'TOPIK I',
          english: 'TOPIK I',
        );
      case TestCategory.topikII:
        return _languageCubit.getLocalizedText(
          korean: 'TOPIK II',
          english: 'TOPIK II',
        );
    }
  }

  Widget _buildHeaderActions(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _showSearchDelegate,
          icon: const Icon(Icons.search_rounded),
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
          ),
          tooltip: _languageCubit.getLocalizedText(
            korean: '검색',
            english: 'Search',
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => context.push(Routes.unpublishedTests),
          icon: const Icon(Icons.drafts_rounded),
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
          ),
          tooltip: _languageCubit.getLocalizedText(
            korean: '비공개 시험',
            english: 'Unpublished Tests',
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => context.push(Routes.testResults),
          icon: const Icon(Icons.history_rounded),
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
          ),
          tooltip: _languageCubit.getLocalizedText(
            korean: '내 결과',
            english: 'My Results',
          ),
        ),
      ],
    );
  }

  Widget _buildSliverContent(bool isOffline) {
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
        if (isOffline && state.tests.isEmpty && state.isLoading) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: ErrorView(
                message: '',
                errorType: FailureType.network,
                onRetry: () {
                  context.read<ConnectivityCubit>().checkConnectivity();
                  if (context.read<ConnectivityCubit>().state is ConnectivityConnected) {
                    if (_selectedCategory == TestCategory.all) {
                      _testsCubit.loadInitialTests(sortType: _selectedSortType);
                    } else {
                      _testsCubit.loadTestsByCategory(_selectedCategory, sortType: _selectedSortType);
                    }
                  }
                },
              ),
            ),
          );
        }
        
        if (state.isLoading && state.tests.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const TestGridSkeleton(),
            ),
          );
        }
        
        if (state.hasError && state.tests.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
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
        
        return _buildSliverTestsList(state);
      },
    );
  }
  
  Widget _buildSliverTestsList(TestsState state) {
    if (state.tests.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyTestsView(),
      );
    }
    
    final isLoadingMore = state.currentOperation.type == TestsOperationType.loadMoreTests && 
                         state.currentOperation.isInProgress;
    
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < state.tests.length) {
              final test = state.tests[index];
              return FutureBuilder<bool>(
                future: _checkEditPermission(test.id),
                builder: (context, snapshot) {
                  final canEdit = snapshot.data ?? false;
                  
                  return TestCard(
                    key: ValueKey(test.id),
                    test: test,
                    canEdit: canEdit,
                    onTap: () => _startTest(test),
                    onEdit: canEdit ? () => _editTest(test) : null,
                    onDelete: canEdit ? () => _deleteTest(test) : null,
                    onViewDetails: () => _viewTestDetails(test),
                  );
                },
              );
            } else if (isLoadingMore) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(),
                ),
              );
            }
            return null;
          },
          childCount: state.tests.length + (isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildEmptyTestsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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
              korean: '시험이 없습니다',
              english: 'No tests available',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _languageCubit.getLocalizedText(
              korean: '새 시험을 만들려면 + 버튼을 누르세요',
              english: 'Tap the + button to create a new test',
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
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTestDetailsBottomSheet(test),
    );
  }

  Widget _buildTestDetailsBottomSheet(TestItem test) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          test.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildDetailChip(
                              icon: Icons.quiz_rounded,
                              label: '${test.questionCount} Questions',
                              color: colorScheme.primary,
                              theme: theme,
                            ),
                            _buildDetailChip(
                              icon: Icons.timer_rounded,
                              label: test.formattedTimeLimit,
                              color: colorScheme.tertiary,
                              theme: theme,
                            ),
                            _buildDetailChip(
                              icon: Icons.school_rounded,
                              label: '${test.formattedPassingScore} to pass',
                              color: colorScheme.secondary,
                              theme: theme,
                            ),
                            if (test.rating > 0)
                              _buildDetailChip(
                                icon: Icons.star_rounded,
                                label: '${test.formattedRating} (${test.ratingCount})',
                                color: Colors.amber[600]!,
                                theme: theme,
                              ),
                            _buildDetailChip(
                              icon: Icons.visibility_rounded,
                              label: '${test.formattedViewCount} views',
                              color: Colors.blue[600]!,
                              theme: theme,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _startTest(test);
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _languageCubit.getLocalizedText(
                                korean: '시험 시작',
                                english: 'Start Test',
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

    final hasPermission = await _testsCubit.canUserEditTest(test.id);
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
    final hasPermission = await _testsCubit.canUserDeleteTest(test.id);
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