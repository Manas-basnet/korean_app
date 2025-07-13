import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/vocabulary_card.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/vocabulary_detail_bottomsheet.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/vocabulary_grid_skeleton.dart';
import 'package:korean_language_app/features/vocabularies/presentation/widgets/vocabulary_search_delegate.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabularies_cubit.dart';
import 'package:korean_language_app/features/vocabularies/presentation/bloc/vocabulary_search/vocabulary_search_cubit.dart';

class VocabulariesPage extends StatefulWidget {
  const VocabulariesPage({super.key});

  @override
  State<VocabulariesPage> createState() => _VocabulariesPageState();
}

class _VocabulariesPageState extends State<VocabulariesPage> {
  late ScrollController _scrollController;
  bool _isRefreshing = false;
  bool _isInitialized = false;
  BookLevel _selectedLevel = BookLevel.beginner;
  SupportedLanguage _selectedLanguage = SupportedLanguage.korean;
  String _filterType = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  
  Timer? _scrollDebounceTimer;
  static const Duration _scrollDebounceDelay = Duration(milliseconds: 100);
  bool _hasTriggeredLoadMore = false;
  
  VocabulariesCubit get _vocabulariesCubit => context.read<VocabulariesCubit>();
  VocabularySearchCubit get _vocabularySearchCubit => context.read<VocabularySearchCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vocabulariesCubit.loadInitialVocabularies();
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
        final state = _vocabulariesCubit.state;
        
        if (state.hasMore && 
            !state.currentOperation.isInProgress && 
            !_hasTriggeredLoadMore) {
          
          _hasTriggeredLoadMore = true;
          _vocabulariesCubit.requestLoadMoreVocabularies();
          
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
        _vocabularySearchCubit.searchVocabularies(_searchQuery);
      } else {
        await _vocabulariesCubit.hardRefresh();
      }
      _hasTriggeredLoadMore = false;
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _onFilterChanged(String filterType) {
    if (_filterType == filterType) return;
    
    setState(() {
      _filterType = filterType;
      _isSearching = false;
      _searchQuery = '';
      _hasTriggeredLoadMore = false;
    });
    
    if (filterType == 'all') {
      _vocabulariesCubit.loadInitialVocabularies();
    } else if (filterType == 'level') {
      _vocabulariesCubit.loadVocabulariesByLevel(_selectedLevel);
    } else if (filterType == 'language') {
      _vocabulariesCubit.loadVocabulariesByLanguage(_selectedLanguage);
    }
  }

  void _onLevelChanged(BookLevel level) {
    if (_selectedLevel == level) return;
    
    setState(() {
      _selectedLevel = level;
      _hasTriggeredLoadMore = false;
    });
    
    if (_filterType == 'level') {
      _vocabulariesCubit.loadVocabulariesByLevel(level);
    }
  }

  void _onLanguageChanged(SupportedLanguage language) {
    if (_selectedLanguage == language) return;
    
    setState(() {
      _selectedLanguage = language;
      _hasTriggeredLoadMore = false;
    });
    
    if (_filterType == 'language') {
      _vocabulariesCubit.loadVocabulariesByLanguage(language);
    }
  }

  void _showSearchDelegate() {
    showSearch(
      context: context,
      delegate: VocabularySearchDelegate(
        vocabularySearchCubit: _vocabularySearchCubit,
        languageCubit: _languageCubit,
        onVocabularySelected: _goToChapters,
        onViewDetails: _viewVocabularyDetails,
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
        heroTag: "vocabularies_page_fab",
        onPressed: () => context.push(Routes.vocabularyUpload),
        tooltip: _languageCubit.getLocalizedText(
          korean: '단어장 만들기',
          english: 'Create Vocabulary',
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
                                  Icons.library_books,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _languageCubit.getLocalizedText(
                                    korean: '단어장',
                                    english: 'Vocabularies',
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
                                      context.read<VocabulariesCubit>().hardRefresh();
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
                                  icon: const Icon(Icons.person_outline),
                                  onPressed: () => context.push('/my-vocabularies'),
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '내 단어장',
                                    english: 'My Vocabularies',
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
                              child: _buildFilterTabs(theme),
                            ),
                            const SizedBox(width: 12),
                            _buildFilterButton(theme, colorScheme),
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

  Widget _buildFilterTabs(ThemeData theme) {
    final filters = [
      {'key': 'all', 'label': _languageCubit.getLocalizedText(korean: '전체', english: 'All')},
      {'key': 'level', 'label': _languageCubit.getLocalizedText(korean: '레벨', english: 'Level')},
      {'key': 'language', 'label': _languageCubit.getLocalizedText(korean: '언어', english: 'Language')},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _filterType == filter['key'];

          return GestureDetector(
            onTap: () => _onFilterChanged(filter['key']!),
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
                filter['label']!,
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

  Widget _buildFilterButton(ThemeData theme, ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list,
        color: colorScheme.onSurfaceVariant,
      ),
      onSelected: (value) {
        if (_filterType == 'level') {
          if (value.startsWith('level_')) {
            final levelName = value.substring(6);
            final level = BookLevel.values.firstWhere((e) => e.name == levelName);
            _onLevelChanged(level);
          }
        } else if (_filterType == 'language') {
          if (value.startsWith('lang_')) {
            final langName = value.substring(5);
            final language = SupportedLanguage.values.firstWhere((e) => e.name == langName);
            _onLanguageChanged(language);
          }
        }
      },
      itemBuilder: (context) {
        if (_filterType == 'level') {
          return BookLevel.values.map((level) {
            return PopupMenuItem<String>(
              value: 'level_${level.name}',
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: level.getColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(level.getName(_languageCubit)),
                ],
              ),
            );
          }).toList();
        } else if (_filterType == 'language') {
          return SupportedLanguage.values.map((language) {
            return PopupMenuItem<String>(
              value: 'lang_${language.name}',
              child: Row(
                children: [
                  Text(language.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(language.displayName),
                ],
              ),
            );
          }).toList();
        }
        return [];
      },
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
  
  Widget _buildSliverContent() {
    return BlocConsumer<VocabulariesCubit, VocabulariesState>(
      listener: (context, state) {
        final operation = state.currentOperation;
        
        if (operation.status == VocabulariesOperationStatus.failed) {
          String errorMessage = operation.message ?? 'Operation failed';
          
          switch (operation.type) {
            case VocabulariesOperationType.loadVocabularies:
              errorMessage = 'Failed to load vocabularies';
              break;
            case VocabulariesOperationType.loadMoreVocabularies:
              errorMessage = 'Failed to load more vocabularies';
              break;
            case VocabulariesOperationType.refreshVocabularies:
              errorMessage = 'Failed to refresh vocabularies';
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
        
        if (state.isLoading && state.vocabularies.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.6,
              child: const VocabularyGridSkeleton(),
            ),
          );
        }
        
        if (state.hasError && state.vocabularies.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.7,
              child: ErrorView(
                message: state.error ?? '',
                errorType: state.errorType,
                onRetry: () {
                  if (_filterType == 'all') {
                    _vocabulariesCubit.loadInitialVocabularies();
                  } else if (_filterType == 'level') {
                    _vocabulariesCubit.loadVocabulariesByLevel(_selectedLevel);
                  } else if (_filterType == 'language') {
                    _vocabulariesCubit.loadVocabulariesByLanguage(_selectedLanguage);
                  }
                },
              ),
            ),
          );
        }
        
        return _buildSliverVocabulariesList(state, screenSize);
      },
    );
  }
  
  Widget _buildSliverVocabulariesList(VocabulariesState state, Size screenSize) {
    if (state.vocabularies.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyVocabulariesView());
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
            itemCount: state.vocabularies.length,
            itemBuilder: (context, index) {
              final vocabulary = state.vocabularies[index];
              return VocabularyCard(
                vocabulary: vocabulary,
                canEdit: true,
                onTap: () => _goToChapters(vocabulary),
                onLongPress: () => _viewVocabularyDetails(vocabulary),
                onEdit: () => _editVocabulary(vocabulary),
                onDelete: () => _deleteVocabulary(vocabulary),
                onViewDetails: () => _viewVocabularyDetails(vocabulary),
              );
            },
          ),
        ),
        _buildLoadMoreIndicator(state),
      ]),
    );
  }

  Widget _buildLoadMoreIndicator(VocabulariesState state) {
    final isLoadingMore = state.currentOperation.type == VocabulariesOperationType.loadMoreVocabularies &&
        state.currentOperation.status == VocabulariesOperationStatus.inProgress;
    
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
                korean: '더 많은 단어장을 불러오는 중...',
                english: 'Loading more vocabularies...',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!state.hasMore && state.vocabularies.isNotEmpty) {
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
                      korean: '더 이상 단어장이 없습니다',
                      english: 'No more vocabularies',
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

  Widget _buildEmptyVocabulariesView() {
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
            Icons.school_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            _languageCubit.getLocalizedText(
              korean: '단어장이 없습니다',
              english: 'No vocabularies available',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageCubit.getLocalizedText(
              korean: '새 단어장을 만들어보세요',
              english: 'Create your first vocabulary',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.push(Routes.vocabularyUpload),
            icon: const Icon(Icons.add),
            label: Text(
              _languageCubit.getLocalizedText(
                korean: '단어장 만들기',
                english: 'Create Vocabulary',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _goToChapters(VocabularyItem vocabulary) async {
    if (vocabulary.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '단어장 ID가 유효하지 않습니다',
        english: 'Invalid vocabulary ID',
      );
      return;
    }
    context.push(Routes.vocabularyChapters(vocabulary.id));
  }
    
  void _viewVocabularyDetails(VocabularyItem vocabulary) {
    HapticFeedback.lightImpact();
    VocabularyDetailsBottomSheet.show(
      context, 
      vocabulary: vocabulary,
      languageCubit: _languageCubit,
      onStartStudying: () => _goToChapters(vocabulary),
    );
  }
  
  void _editVocabulary(VocabularyItem vocabulary) async {
    if (vocabulary.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '단어장 ID가 유효하지 않습니다',
        english: 'Invalid vocabulary ID',
      );
      return;
    }

    final result = await context.push(Routes.vocabularyEdit(vocabulary.id));

    if (result == true) {
      _refreshData();
    }
  }

  void _deleteVocabulary(VocabularyItem vocabulary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '단어장 삭제',
            english: 'Delete Vocabulary',
          ),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '"${vocabulary.title}"을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.',
            english: 'Are you sure you want to delete "${vocabulary.title}"? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
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
                english: 'Delete',
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      _snackBarCubit.showSuccessLocalized(
        korean: '단어장이 성공적으로 삭제되었습니다',
        english: 'Vocabulary deleted successfully',
      );
      
      _refreshData();
    }
  }
}