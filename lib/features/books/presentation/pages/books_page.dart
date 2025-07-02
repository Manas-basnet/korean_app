import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/features/books/presentation/pages/chapter_list_page.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/presentation/connectivity/bloc/connectivity_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/favorite_books/favorite_books_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/bloc/file_upload_cubit.dart';
import 'package:korean_language_app/features/book_upload/presentation/pages/book_edit_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/book_search_page.dart';
import 'package:korean_language_app/features/books/presentation/pages/pdf_viewer_page.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_detail_bottomsheet.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_grid_card.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_grid_skeleton.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _isRefreshing = false;
  final Map<String, bool> _editPermissionCache = {};
  bool _isInitialized = false;
  CourseCategory _selectedCategory = CourseCategory.korean;

  String? _currentPdfLoadingBookId;

  KoreanBooksCubit get _koreanBooksCubit => context.read<KoreanBooksCubit>();
  BookSearchCubit get _bookSearchCubit => context.read<BookSearchCubit>();
  FavoriteBooksCubit get _favoriteBooksCubit =>
      context.read<FavoriteBooksCubit>();
  LanguagePreferenceCubit get _languageCubit =>
      context.read<LanguagePreferenceCubit>();
  FileUploadCubit get _fileUploadCubit => context.read<FileUploadCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _koreanBooksCubit.loadInitialBooks();
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
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isRefreshing) return;

    if (_isNearBottom()) {
      final state = _koreanBooksCubit.state;

      if (state.hasMore && !state.currentOperation.isInProgress) {
        _koreanBooksCubit.loadMoreBooks();
      }
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return false;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);

    try {
      await _koreanBooksCubit.hardRefresh();
      _editPermissionCache.clear();
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<bool> _checkEditPermission(String bookId) async {
    if (_editPermissionCache.containsKey(bookId)) {
      return _editPermissionCache[bookId]!;
    }

    final hasPermission = await _koreanBooksCubit.canUserEditBook(bookId);
    _editPermissionCache[bookId] = hasPermission;
    return hasPermission;
  }

  void _onCategoryChanged(CourseCategory category) {
    if (_selectedCategory == category) return;

    setState(() {
      _selectedCategory = category;
    });

    _editPermissionCache.clear();

    if (category == CourseCategory.korean) {
      _koreanBooksCubit.loadInitialBooks();
    } else {
      _koreanBooksCubit.loadInitialBooks();
    }
  }

  String _getCategoryDisplayName(CourseCategory category) {
    switch (category) {
      case CourseCategory.korean:
        return _languageCubit.getLocalizedText(
          korean: '한국어',
          english: 'Korean',
        );
      case CourseCategory.nepali:
        return _languageCubit.getLocalizedText(
          korean: '네팔어',
          english: 'Nepali',
        );
      case CourseCategory.test:
        return _languageCubit.getLocalizedText(
          korean: '테스트',
          english: 'Test',
        );
      case CourseCategory.global:
        return _languageCubit.getLocalizedText(
          korean: '글로벌',
          english: 'Global',
        );
      case CourseCategory.favorite:
        return _languageCubit.getLocalizedText(
          korean: '즐겨찾기',
          english: 'Favorites',
        );
    }
  }

  void _showSearchDelegate() {
    showSearch(
      context: context,
      delegate: BookSearchDelegate(
        bookSearchCubit: _bookSearchCubit,
        favoriteBooksCubit: _favoriteBooksCubit,
        languageCubit: _languageCubit,
        onToggleFavorite: _toggleFavorite,
        onViewPdf: _viewBook,
        onEditBook: _editBook,
        onDeleteBook: _deleteBook,
        checkEditPermission: _checkEditPermission,
        onInfoClicked: _showBookDetails,
        onDownloadClicked: _showDownloadOptions,
      ),
    );
  }

  void _viewBook(BookItem book) {
    if (book.uploadType == BookUploadType.chapterWise) {
      _navigateToChapters(book);
    } else {
      _viewSinglePdf(book);
    }
  }

  void _navigateToChapters(BookItem book) {
    context.push(
      Routes.chapters,
      extra: ChaptersPage(book: book),
    );
  }

  void _viewSinglePdf(BookItem book) {
    _currentPdfLoadingBookId = book.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPdfLoadingDialog(book.title),
    );

    _koreanBooksCubit.loadBookPdf(book.id);
  }

  Widget _buildPdfLoadingDialog(String title) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _languageCubit.getLocalizedText(
              korean: '"$title" 로딩 중...',
              english: 'Loading "$title"...',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageCubit.getLocalizedText(
              korean: '잠시만 기다려주세요',
              english: 'This may take a moment',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _editBook(BookItem book) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _fileUploadCubit,
          child: BookEditPage(book: book),
        ),
      ),
    )
        .then((_) {
      _koreanBooksCubit.loadInitialBooks();
    });
  }

  void _deleteBook(BookItem book) async {
    final hasPermission = await _koreanBooksCubit.canUserDeleteBook(book.id);
    if (!hasPermission) {
      _snackBarCubit.showErrorLocalized(
        korean: '이 책을 삭제할 권한이 없습니다',
        english: 'You do not have permission to delete this book',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              _languageCubit.getLocalizedText(
                korean: '책 삭제',
                english: 'Delete Book',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              _languageCubit.getLocalizedText(
                korean: '"${book.title}"을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.',
                english:
                    'Are you sure you want to delete "${book.title}"? This action cannot be undone.',
              ),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(
                  _languageCubit.getLocalizedText(
                    korean: '취소',
                    english: 'CANCEL',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
        ) ??
        false;

    if (confirmed) {
      final success = await _fileUploadCubit.deleteBook(book.id);
      if (success) {
        _koreanBooksCubit.removeBookFromState(book.id);
        _snackBarCubit.showSuccessLocalized(
          korean: '책이 성공적으로 삭제되었습니다',
          english: 'Book deleted successfully',
        );
      } else {
        _snackBarCubit.showErrorLocalized(
          korean: '책 삭제에 실패했습니다',
          english: 'Failed to delete book',
        );
      }
    }
  }

  void _toggleFavorite(BookItem book) {
    _favoriteBooksCubit.toggleFavorite(book);
  }

  void _showBookDetails(BookItem book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookDetailsBottomSheet(book: book),
    );
  }

  void _showDownloadOptions(BookItem book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '책 다운로드',
            english: 'Download Book',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (book.uploadType == BookUploadType.singlePdf) ...[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(
                  _languageCubit.getLocalizedText(
                    korean: 'PDF로 다운로드',
                    english: 'Download as PDF',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _downloadPdf(book);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.auto_stories),
                title: Text(
                  _languageCubit.getLocalizedText(
                    korean: '모든 챕터 다운로드',
                    english: 'Download All Chapters',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _downloadAllChapters(book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(
                  _languageCubit.getLocalizedText(
                    korean: '개별 챕터 다운로드',
                    english: 'Download Individual Chapters',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showChapterDownloadOptions(book);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadPdf(BookItem book) async {
    _snackBarCubit.showInfoLocalized(
      korean: '다운로드 기능은 곧 출시될테요',
      english: 'Download feature coming soon',
    );
  }

  void _downloadAllChapters(BookItem book) async {
    _snackBarCubit.showInfoLocalized(
      korean: '모든 챕터 다운로드 기능은 곧 출시될테요',
      english: 'Download all chapters feature coming soon',
    );
  }

  void _showChapterDownloadOptions(BookItem book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _languageCubit.getLocalizedText(
            korean: '챕터 선택',
            english: 'Select Chapters',
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: book.chapters.length,
            itemBuilder: (context, index) {
              final chapter = book.chapters[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${chapter.order}'),
                ),
                title: Text(chapter.title),
                subtitle: chapter.description != null 
                    ? Text(chapter.description!)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _downloadChapter(book, chapter);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _languageCubit.getLocalizedText(
                korean: '취소',
                english: 'Cancel',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadChapter(BookItem book, dynamic chapter) async {
    _snackBarCubit.showInfoLocalized(
      korean: '챕터 다운로드 기능은 곧 출시될테요',
      english: 'Chapter download feature coming soon',
    );
  }

  void _testBook(BookItem book) {
    _snackBarCubit.showInfoLocalized(
      korean: '퀴즈 기능은 곧 출시됩니다',
      english: 'Quiz feature coming soon',
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

    return BlocListener<KoreanBooksCubit, KoreanBooksState>(
      listener: (context, state) {
        _handlePdfLoadingState(state);
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        floatingActionButton: FloatingActionButton(
          heroTag: "books_page_fab",
          onPressed: () => context.push(Routes.uploadBooks),
          tooltip: _languageCubit.getLocalizedText(
            korean: '책 업로드',
            english: 'Upload Book',
          ),
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<ConnectivityCubit, ConnectivityState>(
          builder: (context, connectivityState) {
            final bool isOffline =
                connectivityState is ConnectivityDisconnected;

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
      ),
    );
  }

  void _handlePdfLoadingState(KoreanBooksState state) {
    final operation = state.currentOperation;

    if (operation.type == KoreanBooksOperationType.loadPdf) {
      if (_currentPdfLoadingBookId != null &&
          operation.bookId == _currentPdfLoadingBookId) {
        if (operation.status == KoreanBooksOperationStatus.completed &&
            state.loadedPdfFile != null) {
          Navigator.of(context, rootNavigator: true).pop();
          _verifyAndOpenPdf(state.loadedPdfFile!, state.books.firstWhere((b) => b.id == operation.bookId));
          _currentPdfLoadingBookId = null;
        } else if (operation.status == KoreanBooksOperationStatus.failed) {
          Navigator.of(context, rootNavigator: true).pop();
          _showRetrySnackBar(
            _getReadableErrorMessage(operation.message ?? 'Failed to load PDF'),
            () => _retryPdfLoad(operation.bookId ?? ''),
          );
          _currentPdfLoadingBookId = null;
        }
      }
    }
  }

  void _retryPdfLoad(String bookId) {
    final state = _koreanBooksCubit.state;
    final book = state.books.firstWhere((b) => b.id == bookId);
    _viewSinglePdf(book);
  }

  void _verifyAndOpenPdf(File pdfFile, BookItem item) async {
    try {
      final fileExists = await pdfFile.exists();
      final fileSize = fileExists ? await pdfFile.length() : 0;

      if (!fileExists || fileSize == 0) {
        throw Exception('PDF file is empty or does not exist');
      }

      Future.microtask(() => _openPdfViewer(pdfFile, item));
    } catch (e) {
      _snackBarCubit.showErrorLocalized(
        korean: '오류: PDF 파일을 열 수 없습니다',
        english: 'Error: PDF file cannot be opened',
      );
    }
  }

  void _openPdfViewer(File pdfFile, BookItem item) {
    context.push(
      Routes.pdfViewer,
      extra: PDFViewerScreen(pdfFile: pdfFile, title: item.title, book: item,),
    );
  }

  void _showRetrySnackBar(String message, VoidCallback onRetry) {
    _snackBarCubit.showErrorLocalized(
      korean: message,
      english: message,
      actionLabelKorean: '다시 시도',
      actionLabelEnglish: 'Retry',
      action: onRetry,
    );
  }

  String _getReadableErrorMessage(String technicalError) {
    if (technicalError.contains('No internet connection')) {
      return _languageCubit.getLocalizedText(
        korean: '오프라인 상태인 것 같습니다. 연결을 확인하고 다시 시도하세요.',
        english:
            'You seem to be offline. Please check your connection and try again.',
      );
    } else if (technicalError.contains('not found')) {
      return _languageCubit.getLocalizedText(
        korean: '죄송합니다. PDF를 찾을 수 없습니다.',
        english: 'Sorry, the book PDF could not be found.',
      );
    } else if (technicalError.contains('corrupted') ||
        technicalError.contains('empty')) {
      return _languageCubit.getLocalizedText(
        korean: '죄송합니다. PDF 파일이 손상된 것 같습니다.',
        english: 'Sorry, the PDF file appears to be damaged.',
      );
    } else {
      return _languageCubit.getLocalizedText(
        korean: 'PDF를 로드할 수 없습니다. 다시 시도하세요.',
        english: 'Could not load the PDF. Please try again.',
      );
    }
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
                    color: colorScheme.outlineVariant.withValues(alpha:0.3),
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
                                korean: '책',
                                english: 'Books',
                              ),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.search),
                                  onPressed: _showSearchDelegate,
                                  style: IconButton.styleFrom(
                                    foregroundColor: colorScheme.onSurface,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.favorite),
                                  onPressed: () {
                                    context.push(Routes.favoriteBooks);
                                  },
                                  tooltip: _languageCubit.getLocalizedText(
                                    korean: '즐겨찾기',
                                    english: 'Favorites',
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
                        _buildCategoryTabsSliver(theme),
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
        itemCount: CourseCategory.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = CourseCategory.values[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () => _onCategoryChanged(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha:0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha:0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _getCategoryDisplayName(category),
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha:0.6),
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

  Widget _buildSliverContent(bool isOffline) {
    return BlocConsumer<KoreanBooksCubit, KoreanBooksState>(
      listener: (context, state) {
        final operation = state.currentOperation;

        if (operation.status == KoreanBooksOperationStatus.failed) {
          String errorMessage = operation.message ?? 'Operation failed';

          switch (operation.type) {
            case KoreanBooksOperationType.loadBooks:
              errorMessage = 'Failed to load books';
              break;
            case KoreanBooksOperationType.loadMoreBooks:
              errorMessage = 'Failed to load more books';
              break;
            case KoreanBooksOperationType.refreshBooks:
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
        if (isOffline && state.books.isEmpty && state.isLoading) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: ErrorView(
                message: '',
                errorType: FailureType.network,
                onRetry: () {
                  context.read<ConnectivityCubit>().checkConnectivity();
                  if (context.read<ConnectivityCubit>().state
                      is ConnectivityConnected) {
                    _koreanBooksCubit.loadInitialBooks();
                  }
                },
              ),
            ),
          );
        }

        if (state.isLoading && state.books.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const BookGridSkeleton(),
            ),
          );
        }

        if (state.hasError && state.books.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: ErrorView(
                message: state.error ?? '',
                errorType: state.errorType,
                onRetry: () {
                  _koreanBooksCubit.loadInitialBooks();
                },
              ),
            ),
          );
        }

        return _buildSliverBooksList(state);
      },
    );
  }

  Widget _buildSliverBooksList(KoreanBooksState state) {
    if (state.books.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyBooksView(),
      );
    }

    final isLoadingMore =
        state.currentOperation.type == KoreanBooksOperationType.loadMoreBooks &&
            state.currentOperation.isInProgress;

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < state.books.length) {
              final book = state.books[index];
              return FutureBuilder<bool>(
                future: _checkEditPermission(book.id),
                builder: (context, snapshot) {
                  final canEdit = snapshot.data ?? false;

                  return BlocBuilder<FavoriteBooksCubit, FavoriteBooksState>(
                    builder: (context, favoritesState) {
                      bool isFavorite = favoritesState.books
                          .any((favBook) => favBook.id == book.id);

                      return BookGridCard(
                        key: ValueKey(book.id),
                        book: book,
                        isFavorite: isFavorite,
                        showEditOptions: canEdit,
                        onViewClicked: () => _viewBook(book),
                        onTestClicked: () => _testBook(book),
                        onEditClicked: canEdit ? () => _editBook(book) : null,
                        onDeleteClicked:
                            canEdit ? () => _deleteBook(book) : null,
                        onToggleFavorite: () => _toggleFavorite(book),
                        onInfoClicked: () => _showBookDetails(book),
                        onDownloadClicked: () => _showDownloadOptions(book),
                      );
                    },
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
                        color: Colors.black.withValues(alpha:0.1),
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
          childCount: state.books.length + (isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildEmptyBooksView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _languageCubit.getLocalizedText(
                korean: '책이 없습니다',
                english: 'No books available',
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _languageCubit.getLocalizedText(
                korean: '새 책을 추가하려면 + 버튼을 누르세요',
                english: 'Tap the + button to add new books',
              ),
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}