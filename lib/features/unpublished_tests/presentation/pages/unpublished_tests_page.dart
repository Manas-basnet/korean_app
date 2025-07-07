import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/presentation/connectivity/bloc/connectivity_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';
import 'package:korean_language_app/features/test_upload/presentation/bloc/test_upload_cubit.dart';
import 'package:korean_language_app/features/unpublished_tests/presentation/bloc/unpublished_tests_cubit.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_card.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/test_grid_skeleton.dart';

class UnpublishedTestsPage extends StatefulWidget {
  const UnpublishedTestsPage({super.key});

  @override
  State<UnpublishedTestsPage> createState() => _UnpublishedTestsPageState();
}

class _UnpublishedTestsPageState extends State<UnpublishedTestsPage> {
  late ScrollController _scrollController;
  bool _isRefreshing = false;
  final Map<String, bool> _editPermissionCache = {};
  bool _isInitialized = false;
  TestCategory _selectedCategory = TestCategory.all;
  
  Timer? _scrollDebounceTimer;
  static const Duration _scrollDebounceDelay = Duration(milliseconds: 100);
  bool _hasTriggeredLoadMore = false;
  
  UnpublishedTestsCubit get _unpublishedTestsCubit => context.read<UnpublishedTestsCubit>();
  TestUploadCubit get _testUploadCubit => context.read<TestUploadCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unpublishedTestsCubit.loadInitialTests();
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
    if (!_scrollController.hasClients || _isRefreshing) return;
    
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_scrollDebounceDelay, () {
      if (!mounted) return;
      
      if (_isNearBottom()) {
        final state = _unpublishedTestsCubit.state;
        
        if (state.hasMore && 
            !state.currentOperation.isInProgress && 
            !_hasTriggeredLoadMore) {
          
          _hasTriggeredLoadMore = true;
          _unpublishedTestsCubit.loadMoreTests();
          
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
      await _unpublishedTestsCubit.hardRefresh();
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
    
    final hasPermission = await _unpublishedTestsCubit.canUserEditTest(testId);
    _editPermissionCache[testId] = hasPermission;
    return hasPermission;
  }

  void _onCategoryChanged(TestCategory category) {
    if (_selectedCategory == category) return;
    
    setState(() {
      _selectedCategory = category;
      _hasTriggeredLoadMore = false;
    });
    
    _editPermissionCache.clear();
    
    if (category == TestCategory.all) {
      _unpublishedTestsCubit.loadInitialTests();
    } else {
      _unpublishedTestsCubit.loadTestsByCategory(category);
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
        heroTag: "unpub_tests_page_fab",
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
    final screenSize = MediaQuery.sizeOf(context);
    final expandedHeight = screenSize.height * 0.16; // Slightly smaller for unpublished
    final minHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    
    return SliverAppBar(
      expandedHeight: expandedHeight,
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
          final availableHeight = constraints.maxHeight - minHeight;
          final totalExpandableHeight = expandedHeight - minHeight;
          final expandRatio = totalExpandableHeight > 0 
              ? (availableHeight / totalExpandableHeight).clamp(0.0, 1.0)
              : 0.0;
          final isExpanded = expandRatio > 0.1;

          return FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
              ),
              child: SafeArea(
                child: AnimatedOpacity(
                  opacity: isExpanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildAppBarContent(theme, colorScheme, screenSize),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBarContent(ThemeData theme, ColorScheme colorScheme, Size screenSize) {
    final horizontalPadding = screenSize.width * 0.04;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding, 
        screenSize.height * 0.015, 
        horizontalPadding, 
        screenSize.height * 0.01
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and actions
          Row(
            children: [
              // Back button
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: screenSize.width * 0.06,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  padding: EdgeInsets.all(screenSize.width * 0.02),
                ),
              ),
              SizedBox(width: screenSize.width * 0.02),
              
              // Title
              Expanded(
                child: FittedBox(
                  child: Text(
                    _languageCubit.getLocalizedText(
                      korean: '비공개 시험',
                      english: 'Unpublished Tests',
                    ),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      fontSize: screenSize.width * 0.065,
                    ),
                  ),
                ),
              ),
              
              // Actions
              _buildCompactHeaderActions(colorScheme, screenSize),
            ],
          ),
          
          SizedBox(height: screenSize.height * 0.02),
          
          // Category tabs only (no sort button needed for unpublished)
          _buildMinimalCategoryTabs(theme, screenSize),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderActions(ColorScheme colorScheme, Size screenSize) {
    final iconSize = screenSize.width * 0.055;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMinimalActionButton(
          icon: Icons.search_rounded,
          onPressed: _showSearchDelegate,
          tooltip: _languageCubit.getLocalizedText(
            korean: '검색',
            english: 'Search',
          ),
          colorScheme: colorScheme,
          iconSize: iconSize,
        ),
        _buildMinimalActionButton(
          icon: Icons.public_rounded,
          onPressed: () => context.pop(),
          tooltip: _languageCubit.getLocalizedText(
            korean: '공개 시험',
            english: 'Published Tests',
          ),
          colorScheme: colorScheme,
          iconSize: iconSize,
        ),
      ],
    );
  }

  Widget _buildMinimalActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required ColorScheme colorScheme,
    required double iconSize,
  }) {
    return Container(
      margin: EdgeInsets.only(left: MediaQuery.sizeOf(context).width * 0.01),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width * 0.025),
        ),
      ),
    );
  }

  Widget _buildMinimalCategoryTabs(ThemeData theme, Size screenSize) {
    return SizedBox(
      height: screenSize.height * 0.04,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TestCategory.values.length,
        separatorBuilder: (context, index) => SizedBox(width: screenSize.width * 0.02),
        itemBuilder: (context, index) {
          final category = TestCategory.values[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () => _onCategoryChanged(category),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.035,
                vertical: screenSize.height * 0.008,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                category.getDisplayName(_languageCubit.getLocalizedText),
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: screenSize.width * 0.032,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverContent(bool isOffline) {
    return BlocConsumer<UnpublishedTestsCubit, UnpublishedTestsState>(
      listener: (context, state) {
        final operation = state.currentOperation;
        
        if (operation.status == UnpublishedTestsOperationStatus.failed) {
          String errorMessage = operation.message ?? 'Operation failed';
          
          switch (operation.type) {
            case UnpublishedTestsOperationType.loadTests:
              errorMessage = 'Failed to load unpublished tests';
              break;
            case UnpublishedTestsOperationType.loadMoreTests:
              errorMessage = 'Failed to load more unpublished tests';
              break;
            case UnpublishedTestsOperationType.searchTests:
              errorMessage = 'Failed to search unpublished tests';
              break;
            case UnpublishedTestsOperationType.refreshTests:
              errorMessage = 'Failed to refresh unpublished tests';
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
        
        if (isOffline && state.tests.isEmpty && state.isLoading) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.7,
              child: ErrorView(
                message: '',
                errorType: FailureType.network,
                onRetry: () {
                  context.read<ConnectivityCubit>().checkConnectivity();
                  if (context.read<ConnectivityCubit>().state is ConnectivityConnected) {
                    if (_selectedCategory == TestCategory.all) {
                      _unpublishedTestsCubit.loadInitialTests();
                    } else {
                      _unpublishedTestsCubit.loadTestsByCategory(_selectedCategory);
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
                    _unpublishedTestsCubit.loadInitialTests();
                  } else {
                    _unpublishedTestsCubit.loadTestsByCategory(_selectedCategory);
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
  
  Widget _buildSliverTestsList(UnpublishedTestsState state, Size screenSize) {
    if (state.tests.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyTestsView(),
      );
    }
    
    final isLoadingMore = state.currentOperation.type == UnpublishedTestsOperationType.loadMoreTests && 
                         state.currentOperation.isInProgress;
    
    // Responsive grid parameters
    final isTablet = screenSize.width > 600;
    final crossAxisCount = isTablet ? 3 : 2;
    final childAspectRatio = isTablet ? 0.8 : 0.75;
    final gridPadding = screenSize.width * 0.05;
    final gridSpacing = screenSize.width * 0.04;
    
    return SliverPadding(
      padding: EdgeInsets.all(gridPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
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
                    key: ValueKey('${test.id}_unpublished'),
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
                  padding: EdgeInsets.all(screenSize.width * 0.03),
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
    final screenSize = MediaQuery.sizeOf(context);
    
    return Container(
      width: double.infinity,
      height: screenSize.height * 0.6,
      padding: EdgeInsets.all(screenSize.width * 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: screenSize.width * 0.2,
            height: screenSize.width * 0.2,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.drafts_outlined,
              size: screenSize.width * 0.1,
              color: Colors.orange,
            ),
          ),
          SizedBox(height: screenSize.height * 0.03),
          Text(
            _languageCubit.getLocalizedText(
              korean: '비공개 시험이 없습니다',
              english: 'No unpublished tests available',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: screenSize.width * 0.05,
            ),
          ),
          SizedBox(height: screenSize.height * 0.015),
          Text(
            _languageCubit.getLocalizedText(
              korean: '새 시험을 만들어 초안으로 저장하세요',
              english: 'Create a new test and save it as draft',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: screenSize.width * 0.035,
            ),
          ),
          SizedBox(height: screenSize.height * 0.04),
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
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.06,
                vertical: screenSize.height * 0.015,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSearchDelegate() {
    _snackBarCubit.showInfoLocalized(
      korean: '검색 기능이 곧 제공될 예정입니다',
      english: 'Search functionality coming soon',
    );
  }
  
  void _startTest(TestItem test) {
    if (test.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '시험 ID가 유효하지 않습니다',
        english: 'Invalid test ID',
      );
      return;
    }
    context.push(Routes.testTaking(test.id));
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
    final screenSize = MediaQuery.sizeOf(context);
    
    return Container(
      margin: EdgeInsets.all(screenSize.width * 0.04),
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
                  margin: EdgeInsets.only(
                    top: screenSize.height * 0.015,
                    bottom: screenSize.height * 0.01,
                  ),
                  width: screenSize.width * 0.1,
                  height: screenSize.height * 0.005,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.all(screenSize.width * 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                test.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                  fontSize: screenSize.width * 0.055,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.02,
                                vertical: screenSize.height * 0.005,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _languageCubit.getLocalizedText(
                                  korean: '비공개',
                                  english: 'Draft',
                                ),
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: screenSize.width * 0.025,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenSize.height * 0.015),
                        Text(
                          test.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                            fontSize: screenSize.width * 0.04,
                          ),
                        ),
                        SizedBox(height: screenSize.height * 0.03),
                        
                        Wrap(
                          spacing: screenSize.width * 0.03,
                          runSpacing: screenSize.height * 0.015,
                          children: [
                            _buildDetailChip(
                              icon: Icons.quiz_rounded,
                              label: '${test.questionCount} Questions',
                              color: colorScheme.primary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.timer_rounded,
                              label: test.formattedTimeLimit,
                              color: colorScheme.tertiary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.school_rounded,
                              label: '${test.formattedPassingScore} to pass',
                              color: colorScheme.secondary,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                            _buildDetailChip(
                              icon: Icons.category_rounded,
                              label: test.category.getDisplayName(_languageCubit.getLocalizedText),
                              color: Colors.purple[600]!,
                              theme: theme,
                              screenSize: screenSize,
                            ),
                          ],
                        ),
                        
                        SizedBox(height: screenSize.height * 0.04),
                        
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _editTest(test);
                                },
                                icon: const Icon(Icons.edit_rounded),
                                label: Text(
                                  _languageCubit.getLocalizedText(
                                    korean: '편집',
                                    english: 'Edit',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: screenSize.height * 0.02,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: screenSize.width * 0.03),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _startTest(test);
                                },
                                icon: const Icon(Icons.visibility_rounded),
                                label: Text(
                                  _languageCubit.getLocalizedText(
                                    korean: '미리보기',
                                    english: 'Preview',
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: screenSize.height * 0.02,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    required Size screenSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.03,
        vertical: screenSize.height * 0.01,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: screenSize.width * 0.04, color: color),
          SizedBox(width: screenSize.width * 0.015),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: screenSize.width * 0.03,
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

    final hasPermission = await _unpublishedTestsCubit.canUserEditTest(test.id);
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
    final hasPermission = await _unpublishedTestsCubit.canUserDeleteTest(test.id);
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