import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/book_upload_cubit.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_card.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_detail_bottomsheet.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_grid_skeleton.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_search_delegate.dart';
import 'package:korean_language_app/features/tests/presentation/widgets/sort_bottomsheet.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/presentation/connectivity/bloc/connectivity_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
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
  
  BooksCubit get _booksCubit => context.read<BooksCubit>();
  BookUploadCubit get _bookUploadCubit => context.read<BookUploadCubit>();
  BookSearchCubit get _bookSearchCubit => context.read<BookSearchCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _booksCubit.loadInitialBooks();
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
        final state = _booksCubit.state;
        
        if (state.hasMore && 
            !state.currentOperation.isInProgress && 
            !_hasTriggeredLoadMore) {
          
          _hasTriggeredLoadMore = true;
          _booksCubit.requestLoadMoreBooks();
          
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
        _bookSearchCubit.searchBooks(_searchQuery);
      } else {
        await _booksCubit.hardRefresh();
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
      _booksCubit.loadInitialBooks(sortType: _selectedSortType);
    } else {
      _booksCubit.loadBooksByCategory(category, sortType: _selectedSortType);
    }
  }

  void _onSortTypeChanged(TestSortType sortType) {
    if (_selectedSortType == sortType) return;
    
    setState(() {
      _selectedSortType = sortType;
      _hasTriggeredLoadMore = false;
    });
    
    _booksCubit.changeSortType(sortType);
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
      delegate: BookSearchDelegate(
        bookSearchCubit: _bookSearchCubit,
        languageCubit: _languageCubit,
        onBookSelected: _startReading,
        checkEditPermission: (book) async {
          return await _booksCubit.canUserEditBook(book);
        },
        onEditBook: _editBook,
        onDeleteBook: _deleteBook,
        onViewDetails: _viewBookDetails,
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
        heroTag: "books_page_fab",
        onPressed: () => context.push(Routes.bookUpload),
        tooltip: _languageCubit.getLocalizedText(
          korean: '책 만들기',
          english: 'Create Book',
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
              cacheExtent: 600,
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
                                korean: '도서',
                                english: 'Books',
                              ),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                if(kIsWeb)
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () {
                                      context.read<BooksCubit>().hardRefresh();
                                    },
                                    tooltip: _languageCubit.getLocalizedText(
                                      korean: '새로고침',
                                      english: 'Refresh',
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: colorScheme.onSurface,
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: _showSearchDelegate,
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '검색',
                                    english: 'Search',
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.onSurface,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.library_books_outlined),
                                  onPressed: () => context.push('/my-books'),
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '내 도서',
                                    english: 'My Books',
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCategoryTabsSliver(theme),
                            ),
                            const SizedBox(width: 12),
                            _buildSortButtonSliver(theme, colorScheme),
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
                category.getDisplayName(_languageCubit.getLocalizedText),
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

  Widget _buildSortButtonSliver(ThemeData theme, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _showSortBottomSheet,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
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
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.sort_rounded,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSliverContent(bool isOffline) {
    return BlocConsumer<BooksCubit, BooksState>(
      listener: (context, state) {
        final operation = state.currentOperation;
        
        if (operation.status == BooksOperationStatus.failed) {
          String errorMessage = operation.message ?? 'Operation failed';
          
          switch (operation.type) {
            case BooksOperationType.loadBooks:
              errorMessage = 'Failed to load books';
              break;
            case BooksOperationType.loadMoreBooks:
              errorMessage = 'Failed to load more books';
              break;
            case BooksOperationType.refreshBooks:
              errorMessage = 'Failed to refresh books';
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
        final screenSize = MediaQuery.of(context).size;
        
        if (isOffline && state.books.isEmpty && state.isLoading) {
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
                      _booksCubit.loadInitialBooks(sortType: _selectedSortType);
                    } else {
                      _booksCubit.loadBooksByCategory(_selectedCategory, sortType: _selectedSortType);
                    }
                  }
                },
              ),
            ),
          );
        }
        
        if (state.isLoading && state.books.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.6,
              child: const BookGridSkeleton(),
            ),
          );
        }
        
        if (state.hasError && state.books.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: screenSize.height * 0.7,
              child: ErrorView(
                message: state.error ?? '',
                errorType: state.errorType,
                onRetry: () {
                  if (_selectedCategory == TestCategory.all) {
                    _booksCubit.loadInitialBooks(sortType: _selectedSortType);
                  } else {
                    _booksCubit.loadBooksByCategory(_selectedCategory, sortType: _selectedSortType);
                  }
                },
              ),
            ),
          );
        }
        
        return _buildSliverBooksList(state, screenSize);
      },
    );
  }
  
  Widget _buildSliverBooksList(BooksState state, Size screenSize) {
    if (state.books.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyBooksView());
    }
    
    final isTablet = screenSize.width > 600;
    final crossAxisCount = isTablet ? 3 : 2;
    final childAspectRatio = isTablet ? 0.7 : 0.75;
    
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
              mainAxisSpacing: 16,
            ),
            itemCount: state.books.length,
            itemBuilder: (context, index) {
              final book = state.books[index];
              return BookCard(
                book: book,
                canEdit: true,
                onTap: () => _startReading(book),
                onLongPress: () => _viewBookDetails(book),
                onEdit: () => _editBook(book),
                onDelete: () => _deleteBook(book),
                onViewDetails: () => _viewBookDetails(book),
              );
            },
          ),
        ),
        _buildLoadMoreIndicator(state),
      ]),
    );
  }

  Widget _buildLoadMoreIndicator(BooksState state) {
    final isLoadingMore = state.currentOperation.type == BooksOperationType.loadMoreBooks &&
        state.currentOperation.status == BooksOperationStatus.inProgress;
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isLoadingMore) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _languageCubit.getLocalizedText(
                      korean: '더 많은 도서를 불러오는 중...',
                      english: 'Loading more books...',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
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
    
    if (!state.hasMore && state.books.isNotEmpty) {
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
                      korean: '더 이상 도서가 없습니다',
                      english: 'No more books',
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

  Widget _buildEmptyBooksView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    
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
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.library_books_outlined,
              size: screenSize.width * 0.1,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: screenSize.height * 0.03),
          Text(
            _languageCubit.getLocalizedText(
              korean: '도서가 없습니다',
              english: 'No books available',
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
              korean: '새 도서를 만들려면 + 버튼을 누르세요',
              english: 'Tap the + button to create a new book',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: screenSize.width * 0.035,
            ),
          ),
          SizedBox(height: screenSize.height * 0.04),
          FilledButton.icon(
            onPressed: () => context.push('/book-upload'),
            icon: const Icon(Icons.add),
            label: Text(
              _languageCubit.getLocalizedText(
                korean: '도서 만들기',
                english: 'Create Book',
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
  
  void _startReading(BookItem book) async {
    if (book.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '도서 ID가 유효하지 않습니다',
        english: 'Invalid book ID',
      );
      return;
    }

    _snackBarCubit.showProgressLocalized(
      korean: '도서를 준비하고 있습니다...',
      english: 'Preparing book...',
    );

    try {
      await _booksCubit.loadBookById(book.id);

      final booksState = _booksCubit.state;
      final operation = booksState.currentOperation;
      
      if (operation.type == BooksOperationType.loadBookById && 
          operation.status == BooksOperationStatus.completed && 
          booksState.selectedBook != null) {
        _snackBarCubit.dismiss();
        context.push('/book-reading/${book.id}');
      } else {
        String errorMessage;
        if (booksState.hasError) {
          errorMessage = booksState.errorType == FailureType.network
              ? _languageCubit.getLocalizedText(
                  korean: '오프라인 상태에서는 캐시된 도서만 이용할 수 있습니다',
                  english: 'Only cached books are available offline',
                )
              : booksState.error ?? _languageCubit.getLocalizedText(
                  korean: '도서를 불러올 수 없습니다',
                  english: 'Failed to load book',
                );
        } else {
          errorMessage = _languageCubit.getLocalizedText(
            korean: '도서를 찾을 수 없습니다',
            english: 'Book not found',
          );
        }
        
        _snackBarCubit.showError(message: errorMessage);
      }
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '도서를 불러오는 중 오류가 발생했습니다',
        english: 'Error loading book',
      );
    }
  }
    
  void _viewBookDetails(BookItem book) {
    HapticFeedback.lightImpact();
    BookDetailsBottomSheet.show(
      context, 
      book: book,
      languageCubit: _languageCubit,
      onStartReading: () => _startReading(book),
    );
  }
  
  void _editBook(BookItem book) async {
    if (book.id.isEmpty) {
      _snackBarCubit.showErrorLocalized(
        korean: '도서 ID가 유효하지 않습니다',
        english: 'Invalid book ID',
      );
      return;
    }

    final hasPermission = await _booksCubit.canUserEditBook(book);
    if (!hasPermission) {
      _snackBarCubit.showErrorLocalized(
        korean: '이 도서를 편집할 권한이 없습니다',
        english: 'You do not have permission to edit this book',
      );
      return;
    }

    final result = await context.push('/book-edit/${book.id}');

    if (result == true) {
      _refreshData();
    }
  }

  void _deleteBook(BookItem book) async {
    final hasPermission = await _booksCubit.canUserDeleteBook(book);
    if (!hasPermission) {
      _snackBarCubit.showErrorLocalized(
        korean: '이 도서를 삭제할 권한이 없습니다',
        english: 'You do not have permission to delete this book',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '도서 삭제',
            english: 'Delete Book',
          ),
        ),
        content: Text(
          _languageCubit.getLocalizedText(
            korean: '"${book.title}"을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.',
            english: 'Are you sure you want to delete "${book.title}"? This action cannot be undone.',
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
      await _bookUploadCubit.deleteBook(book.id);
      _snackBarCubit.showSuccessLocalized(
        korean: '도서가 성공적으로 삭제되었습니다',
        english: 'Book deleted successfully',
      );
      
      _refreshData();
    }
  }
}