import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/features/books/domain/usecase/check_book_permission_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecase/get_book_by_id_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecase/load_books_usecase.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

part 'books_state.dart';

class BooksCubit extends Cubit<BooksState> {
  final LoadBooksUseCase loadBooksUseCase;
  final CheckBookEditPermissionUseCase checkEditPermissionUseCase;
  final GetBookByIdUseCase getBookByIdUseCase;
  final NetworkInfo networkInfo;
  
  int _currentPage = 0;
  static const int _pageSize = 20;
  CourseCategory _currentCategory = CourseCategory.korean;
  TestSortType _currentSortType = TestSortType.recent;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  Timer? _loadMoreDebounceTimer;
  static const Duration _loadMoreDebounceDelay = Duration(milliseconds: 300);
  
  BooksCubit({
    required this.loadBooksUseCase,
    required this.checkEditPermissionUseCase,
    required this.getBookByIdUseCase,
    required this.networkInfo,
  }) : super(const BooksInitial()) {
    _initializeConnectivityListener();
  }

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      
      if (isConnected && (state.books.isEmpty || state.hasError)) {
        debugPrint('Connection restored, reloading books...');
        if (_currentCategory == TestCategory.all) {
          loadInitialBooks(sortType: _currentSortType);
        } else {
          loadBooksByCategory(_currentCategory, sortType: _currentSortType);
        }
      }
    });
  }
  
  Future<void> loadInitialBooks({TestSortType sortType = TestSortType.recent}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _currentCategory = CourseCategory.korean;
    _currentSortType = sortType;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const BooksOperation(
          type: BooksOperationType.loadBooks,
          status: BooksOperationStatus.inProgress,
        ),
      ));
      
      final result = await loadBooksUseCase.execute(LoadBooksParams(
        page: 0,
        pageSize: _pageSize,
        sortType: sortType,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadInitialBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.books.length} books');
          
          emit(BooksState(
            books: loadResult.books,
            hasMore: loadResult.hasMore,
            currentOperation: const BooksOperation(
              type: BooksOperationType.loadBooks,
              status: BooksOperationStatus.completed,
            ),
            currentSortType: sortType,
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadInitialBooks failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const BooksOperation(
            type: BooksOperationType.loadBooks,
            status: BooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading initial books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load books: $e', BooksOperationType.loadBooks);
    }
  }

  Future<void> loadBooksByCategory(CourseCategory category, {TestSortType sortType = TestSortType.recent}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _currentCategory = category;
    _currentSortType = sortType;
    _currentPage = 0;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const BooksOperation(
          type: BooksOperationType.loadBooks,
          status: BooksOperationStatus.inProgress,
        ),
      ));

      final result = await loadBooksUseCase.execute(LoadBooksParams(
        page: 0,
        pageSize: _pageSize,
        sortType: sortType,
        category: category,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadBooksByCategory completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.books.length} books');
          
          emit(BooksState(
            books: loadResult.books,
            hasMore: loadResult.hasMore,
            currentOperation: const BooksOperation(
              type: BooksOperationType.loadBooks,
              status: BooksOperationStatus.completed,
            ),
            currentSortType: sortType,
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadBooksByCategory failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const BooksOperation(
            type: BooksOperationType.loadBooks,
            status: BooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading books by category after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load books: $e', BooksOperationType.loadBooks);
    }
  }

  void changeSortType(TestSortType sortType) {
    if (_currentSortType == sortType) return;
    
    _currentSortType = sortType;
    if (_currentCategory == TestCategory.all) {
      loadInitialBooks(sortType: sortType);
    } else {
      loadBooksByCategory(_currentCategory, sortType: sortType);
    }
  }
  
  void requestLoadMoreBooks() {
    _loadMoreDebounceTimer?.cancel();
    _loadMoreDebounceTimer = Timer(_loadMoreDebounceDelay, () {
      _performLoadMoreBooks();
    });
  }
  

  Future<void> _performLoadMoreBooks() async {
    final currentState = state;
    
    if (!currentState.hasMore || currentState.currentOperation.isInProgress) {
      return;
    }
    
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      debugPrint('loadMoreBooks skipped - not connected');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(currentState.copyWith(
        currentOperation: const BooksOperation(
          type: BooksOperationType.loadMoreBooks,
          status: BooksOperationStatus.inProgress,
        ),
      ));
      
      final nextPage = _currentPage + 1;
      
      final result = await loadBooksUseCase.execute(LoadBooksParams(
        page: nextPage,
        pageSize: _pageSize,
        sortType: _currentSortType,
        category: _currentCategory == TestCategory.all ? null : _currentCategory,
        loadMore: true,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          if (loadResult.books.isNotEmpty) {
            final allBooks = [...state.books, ...loadResult.books];
            _currentPage = nextPage;
            
            _operationStopwatch.stop();
            debugPrint('loadMoreBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.books.length} new books');
            
            emit(state.copyWith(
              books: allBooks,
              hasMore: loadResult.hasMore,
              currentOperation: const BooksOperation(
                type: BooksOperationType.loadMoreBooks,
                status: BooksOperationStatus.completed,
              ),
            ));
          } else {
            emit(state.copyWith(
              hasMore: false,
              currentOperation: const BooksOperation(
                type: BooksOperationType.loadMoreBooks,
                status: BooksOperationStatus.completed,
              ),
            ));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadMoreBooks failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message, 
            errorType: type
          ).copyWithOperation(const BooksOperation(
            type: BooksOperationType.loadMoreBooks,
            status: BooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading more books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load more books: $e', BooksOperationType.loadMoreBooks);
    }
  }
  
  Future<void> hardRefresh() async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Refresh operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const BooksOperation(
          type: BooksOperationType.refreshBooks,
          status: BooksOperationStatus.inProgress,
        ),
      ));
      
      _currentPage = 0;

      final result = await loadBooksUseCase.execute(LoadBooksParams(
        page: 0,
        pageSize: _pageSize,
        sortType: _currentSortType,
        category: _currentCategory == TestCategory.all ? null : _currentCategory,
        forceRefresh: true,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          
          _operationStopwatch.stop();
          debugPrint('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.books.length} books');
          
          emit(BooksState(
            books: loadResult.books,
            hasMore: loadResult.hasMore,
            currentOperation: const BooksOperation(
              type: BooksOperationType.refreshBooks,
              status: BooksOperationStatus.completed,
            ),
            currentSortType: _currentSortType,
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('hardRefresh failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const BooksOperation(
            type: BooksOperationType.refreshBooks,
            status: BooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error refreshing books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh books: $e', BooksOperationType.refreshBooks);
    }
  }

  CourseCategory get currentCategory => _currentCategory;
  TestSortType get currentSortType => _currentSortType;

  Future<void> loadBookById(String bookId) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load book operation already in progress, skipping...');
      return;
    }

    try {
      emit(state.copyWith(
        selectedBook: null,
        currentOperation: BooksOperation(
          type: BooksOperationType.loadBookById,
          status: BooksOperationStatus.inProgress,
          bookId: bookId,
        ),
      ));

      final result = await getBookByIdUseCase.execute(GetBookByIdParams(
        bookId: bookId,
        recordView: true,
      ));

      result.fold(
        onSuccess: (book) {
          emit(state.copyWith(
            selectedBook: book,
            currentOperation: BooksOperation(
              type: BooksOperationType.loadBookById,
              status: BooksOperationStatus.completed,
              bookId: bookId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
          ).copyWithOperation(BooksOperation(
            type: BooksOperationType.loadBookById,
            status: BooksOperationStatus.failed,
            bookId: bookId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _handleError('Failed to load book: $e', BooksOperationType.loadBookById, bookId);
    }
  }
  
  Future<bool> canUserEditBook(BookItem book) async {
    try {
      final result = await checkEditPermissionUseCase.execute(
        CheckBookPermissionParams(bookId: book.id, bookCreatorUid: book.creatorUid)
      );
      
      return result.fold(
        onSuccess: (permissionResult) => permissionResult.canEdit,
        onFailure: (message, type) {
          debugPrint('Failed to check edit permission: $message');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteBook(BookItem book) async {
    return canUserEditBook(book);
  }
  
  void _handleError(String message, BooksOperationType operationType, [String? bookId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(BooksOperation(
      type: operationType,
      status: BooksOperationStatus.failed,
      message: message,
      bookId: bookId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 2), () {
      if (!isClosed && state.currentOperation.status != BooksOperationStatus.none) {
        emit(state.copyWithOperation(
          const BooksOperation(status: BooksOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing BooksCubit...');
    _connectivitySubscription?.cancel();
    _loadMoreDebounceTimer?.cancel();
    return super.close();
  }
}