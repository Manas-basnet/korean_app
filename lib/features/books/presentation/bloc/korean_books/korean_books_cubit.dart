import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/usecases/load_books_usecase.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/features/books/domain/usecases/check_book_edit_permission_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/get_book_pdf_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/get_chapter_pdf_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/load_more_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/refresh_books_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecases/regenerate_book_image_url_usecase.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

part 'korean_books_state.dart';

class KoreanBooksCubit extends Cubit<KoreanBooksState> {
  final LoadBooksUseCase loadBooksUseCase;
  final LoadMoreBooksUseCase loadMoreBooksUseCase;
  final RefreshBooksUseCase refreshBooksUseCase;
  final GetBookPdfUseCase getBookPdfUseCase;
  final GetChapterPdfUseCase getChapterPdfUseCase;
  final CheckBookEditPermissionUseCase checkBookEditPermissionUseCase;
  final RegenerateBookImageUrlUseCase regenerateBookImageUrlUseCase;
  
  static const int _pageSize = 5;
  bool _isConnected = true;
  final Set<String> _downloadsInProgress = {};
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  
  KoreanBooksCubit({
    required this.loadBooksUseCase,
    required this.loadMoreBooksUseCase,
    required this.refreshBooksUseCase,
    required this.getBookPdfUseCase,
    required this.getChapterPdfUseCase,
    required this.checkBookEditPermissionUseCase,
    required this.regenerateBookImageUrlUseCase,
  }) : super(const KoreanBooksInitial()) {
    _initializeConnectivityListener();
  }

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;
      
      if (!wasConnected && _isConnected && (state.books.isEmpty || state.hasError)) {
        debugPrint('Connection restored, reloading books...');
        loadInitialBooks();
      }
    });
  }
  
  Future<void> loadInitialBooks() async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const KoreanBooksOperation(
          type: KoreanBooksOperationType.loadBooks,
          status: KoreanBooksOperationStatus.inProgress,
        ),
      ));
      
      const params = LoadBooksParams(
        category: CourseCategory.korean,
        page: 0,
        pageSize: _pageSize,
      );
      
      final result = await loadBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (loadResult) {
          final uniqueBooks = _removeDuplicates(loadResult.books);
          
          _operationStopwatch.stop();
          debugPrint('loadInitialBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueBooks.length} books');
          
          emit(KoreanBooksState(
            books: uniqueBooks,
            hasMore: loadResult.hasMore,
            currentOperation: const KoreanBooksOperation(
              type: KoreanBooksOperationType.loadBooks,
              status: KoreanBooksOperationStatus.completed,
            ),
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
          ).copyWithOperation(const KoreanBooksOperation(
            type: KoreanBooksOperationType.loadBooks,
            status: KoreanBooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading initial books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load books: $e', KoreanBooksOperationType.loadBooks);
    }
  }
  
  Future<void> loadMoreBooks() async {
    if (!state.hasMore || !_isConnected || state.currentOperation.isInProgress) {
      debugPrint('loadMoreBooks skipped - hasMore: ${state.hasMore}, connected: $_isConnected, inProgress: ${state.currentOperation.isInProgress}');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        currentOperation: const KoreanBooksOperation(
          type: KoreanBooksOperationType.loadMoreBooks,
          status: KoreanBooksOperationStatus.inProgress,
        ),
      ));
      
      final params = LoadMoreBooksParams(
        category: CourseCategory.korean,
        existingBooks: state.books,
        pageSize: _pageSize,
      );
      
      final result = await loadMoreBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (loadResult) {
          _operationStopwatch.stop();
          
          if (loadResult.newBooks.isNotEmpty) {
            debugPrint('loadMoreBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.newBooks.length} new books');
            
            emit(state.copyWith(
              books: loadResult.allBooks,
              hasMore: loadResult.hasMore,
              currentOperation: const KoreanBooksOperation(
                type: KoreanBooksOperationType.loadMoreBooks,
                status: KoreanBooksOperationStatus.completed,
              ),
            ));
          } else {
            debugPrint('loadMoreBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with no new books');
            
            emit(state.copyWith(
              hasMore: false,
              currentOperation: const KoreanBooksOperation(
                type: KoreanBooksOperationType.loadMoreBooks,
                status: KoreanBooksOperationStatus.completed,
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
          ).copyWithOperation(const KoreanBooksOperation(
            type: KoreanBooksOperationType.loadMoreBooks,
            status: KoreanBooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading more books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load more books: $e', KoreanBooksOperationType.loadMoreBooks);
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
        currentOperation: const KoreanBooksOperation(
          type: KoreanBooksOperationType.refreshBooks,
          status: KoreanBooksOperationStatus.inProgress,
        ),
      ));
      
      const params = RefreshBooksParams(
        category: CourseCategory.korean,
        pageSize: _pageSize,
      );
      
      final result = await refreshBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (refreshResult) {
          final uniqueBooks = _removeDuplicates(refreshResult.books);
          
          _operationStopwatch.stop();
          debugPrint('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueBooks.length} books');
          
          emit(KoreanBooksState(
            books: uniqueBooks,
            hasMore: refreshResult.hasMore,
            currentOperation: const KoreanBooksOperation(
              type: KoreanBooksOperationType.refreshBooks,
              status: KoreanBooksOperationStatus.completed,
            ),
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
          ).copyWithOperation(const KoreanBooksOperation(
            type: KoreanBooksOperationType.refreshBooks,
            status: KoreanBooksOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error refreshing books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh books: $e', KoreanBooksOperationType.refreshBooks);
    }
  }
  
  Future<void> loadBookPdf(String bookId) async {
    if (_downloadsInProgress.contains(bookId)) {
      debugPrint('PDF download already in progress for book: $bookId');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      _downloadsInProgress.add(bookId);
      
      emit(state.copyWith(
        currentOperation: KoreanBooksOperation(
          type: KoreanBooksOperationType.loadPdf,
          status: KoreanBooksOperationStatus.inProgress,
          bookId: bookId,
        ),
      ));
      
      final params = GetBookPdfParams(bookId: bookId);
      final result = await getBookPdfUseCase.execute(params);
      
      result.fold(
        onSuccess: (pdfFile) {
          _operationStopwatch.stop();
          debugPrint('PDF loaded successfully in ${_operationStopwatch.elapsedMilliseconds}ms for book: $bookId');
          
          emit(state.copyWith(
            loadedPdfFile: pdfFile,
            loadedPdfBookId: bookId,
            currentOperation: KoreanBooksOperation(
              type: KoreanBooksOperationType.loadPdf,
              status: KoreanBooksOperationStatus.completed,
              bookId: bookId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('PDF load failed after ${_operationStopwatch.elapsedMilliseconds}ms for book $bookId: $message');
          
          emit(state.copyWith(
            currentOperation: KoreanBooksOperation(
              type: KoreanBooksOperationType.loadPdf,
              status: KoreanBooksOperationStatus.failed,
              bookId: bookId,
              message: message,
            ),
          ));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading PDF after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      
      emit(state.copyWith(
        currentOperation: KoreanBooksOperation(
          type: KoreanBooksOperationType.loadPdf,
          status: KoreanBooksOperationStatus.failed,
          bookId: bookId,
          message: 'Failed to load PDF: $e',
        ),
      ));
      _clearOperationAfterDelay();
    } finally {
      _downloadsInProgress.remove(bookId);
    }
  }

  Future<void> loadChapterPdf(String bookId, String chapterId) async {
    if (_downloadsInProgress.contains(chapterId)) {
      debugPrint('Chapter PDF download already in progress for chapter: $chapterId');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      _downloadsInProgress.add(chapterId);
      
      emit(state.copyWith(
        currentOperation: KoreanBooksOperation(
          type: KoreanBooksOperationType.loadPdf,
          status: KoreanBooksOperationStatus.inProgress,
          bookId: chapterId,
        ),
      ));
      
      final params = GetChapterPdfParams(bookId: bookId, chapterId: chapterId);
      final result = await getChapterPdfUseCase.execute(params);
      
      result.fold(
        onSuccess: (pdfFile) {
          _operationStopwatch.stop();
          debugPrint('Chapter PDF loaded successfully in ${_operationStopwatch.elapsedMilliseconds}ms for chapter: $chapterId');
          
          emit(state.copyWith(
            loadedPdfFile: pdfFile,
            loadedPdfBookId: chapterId,
            currentOperation: KoreanBooksOperation(
              type: KoreanBooksOperationType.loadPdf,
              status: KoreanBooksOperationStatus.completed,
              bookId: chapterId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Chapter PDF load failed after ${_operationStopwatch.elapsedMilliseconds}ms for chapter $chapterId: $message');
          
          emit(state.copyWith(
            currentOperation: KoreanBooksOperation(
              type: KoreanBooksOperationType.loadPdf,
              status: KoreanBooksOperationStatus.failed,
              bookId: chapterId,
              message: message,
            ),
          ));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading chapter PDF after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      
      emit(state.copyWith(
        currentOperation: KoreanBooksOperation(
          type: KoreanBooksOperationType.loadPdf,
          status: KoreanBooksOperationStatus.failed,
          bookId: chapterId,
          message: 'Failed to load chapter PDF: $e',
        ),
      ));
      _clearOperationAfterDelay();
    } finally {
      _downloadsInProgress.remove(chapterId);
    }
  }
  
  void addBookToState(BookItem book) {
    final updatedBooks = [book, ...state.books];
    final uniqueBooks = _removeDuplicates(updatedBooks);
    
    debugPrint('Added book to state: ${book.title}');
    emit(state.copyWith(books: uniqueBooks));
  }
  
  void updateBookInState(BookItem updatedBook) {
    final bookIndex = state.books.indexWhere((b) => b.id == updatedBook.id);
    
    if (bookIndex != -1) {
      final updatedBooks = List<BookItem>.from(state.books);
      updatedBooks[bookIndex] = updatedBook;
      
      debugPrint('Updated book in state: ${updatedBook.title}');
      emit(state.copyWith(books: updatedBooks));
    } else {
      debugPrint('Book not found in state for update: ${updatedBook.id}');
    }
  }

  void removeBookFromState(String bookId) {
    final updatedBooks = state.books.where((b) => b.id != bookId).toList();
    
    debugPrint('Removed book from state: $bookId');
    emit(state.copyWith(books: updatedBooks));
  }
  
  Future<bool> canUserEditBook(String bookId) async {
    try {
      final book = state.books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => const BookItem(
          id: '', title: '', description: '', 
          duration: '', chaptersCount: 0, icon: Icons.book,
          level: BookLevel.beginner, courseCategory: CourseCategory.korean,
          country: '', category: ''
        )
      );
      
      final params = CheckBookEditPermissionParams(
        bookId: bookId,
        book: book.id.isNotEmpty ? book : null,
      );
      
      final result = await checkBookEditPermissionUseCase.execute(params);
      
      return result.fold(
        onSuccess: (canEdit) => canEdit,
        onFailure: (_, __) => false,
      );
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteBook(String bookId) async {
    return canUserEditBook(bookId);
  }
  
  Future<void> regenerateBookImageUrl(BookItem book) async {
    try {
      debugPrint('Regenerating image URL for book: ${book.id}');
      
      final params = RegenerateBookImageUrlParams(book: book);
      final result = await regenerateBookImageUrlUseCase.execute(params);
      
      result.fold(
        onSuccess: (regenerateResult) {
          if (regenerateResult != null) {
            updateBookInState(regenerateResult.updatedBook);
            debugPrint('Successfully regenerated image URL for book: ${book.id}');
          } else {
            debugPrint('No new image URL generated for book: ${book.id}');
          }
        },
        onFailure: (message, type) {
          debugPrint('Failed to regenerate book image URL: $message');
        },
      );
    } catch (e) {
      debugPrint('Error regenerating book image URL: $e');
    }
  }
  
  List<BookItem> _removeDuplicates(List<BookItem> books) {
    final uniqueIds = <String>{};
    final uniqueBooks = <BookItem>[];
    
    for (final book in books) {
      if (uniqueIds.add(book.id)) {
        uniqueBooks.add(book);
      }
    }
    
    return uniqueBooks;
  }

  void _handleError(String message, KoreanBooksOperationType operationType) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(KoreanBooksOperation(
      type: operationType,
      status: KoreanBooksOperationStatus.failed,
      message: message,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != KoreanBooksOperationStatus.none) {
        emit(state.copyWithOperation(
          const KoreanBooksOperation(status: KoreanBooksOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing KoreanBooksCubit...');
    _connectivitySubscription?.cancel();
    return super.close();
  }
}