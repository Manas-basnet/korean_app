import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

part 'korean_books_state.dart';

class KoreanBooksCubit extends Cubit<KoreanBooksState> {
  final KoreanBookRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  static const int _pageSize = 5;
  bool _isConnected = true;
  final Set<String> _downloadsInProgress = {};
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  
  KoreanBooksCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
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
      
      final result = await repository.getBooks(
        CourseCategory.korean,
        page: 0,
        pageSize: _pageSize
      );
      
      await result.fold(
        onSuccess: (books) async {
          final hasMoreResult = await repository.hasMoreBooks(
            CourseCategory.korean,
            books.length
          );

          final uniqueBooks = _removeDuplicates(books);
          
          _operationStopwatch.stop();
          debugPrint('loadInitialBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueBooks.length} books');
          
          emit(KoreanBooksState(
            books: uniqueBooks,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
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
    
    final currentPage = (state.books.length / _pageSize).ceil();
    
    try {
      emit(state.copyWith(
        currentOperation: const KoreanBooksOperation(
          type: KoreanBooksOperationType.loadMoreBooks,
          status: KoreanBooksOperationStatus.inProgress,
        ),
      ));
      
      final result = await repository.getBooks(
        CourseCategory.korean,
        page: currentPage,
        pageSize: _pageSize,
      );
      
      await result.fold(
        onSuccess: (moreBooks) async {
          final existingIds = state.books.map((book) => book.id).toSet();
          final uniqueNewBooks = moreBooks.where((book) => !existingIds.contains(book.id)).toList();
          
          if (uniqueNewBooks.isNotEmpty) {
            final allBooks = [...state.books, ...uniqueNewBooks];
            final hasMoreResult = await repository.hasMoreBooks(CourseCategory.korean, allBooks.length);
            
            _operationStopwatch.stop();
            debugPrint('loadMoreBooks completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueNewBooks.length} new books');
            
            emit(state.copyWith(
              books: allBooks,
              hasMore: hasMoreResult.fold(
                onSuccess: (hasMore) => hasMore,
                onFailure: (_, __) => false,
              ),
              currentOperation: const KoreanBooksOperation(
                type: KoreanBooksOperationType.loadMoreBooks,
                status: KoreanBooksOperationStatus.completed,
              ),
            ));
          } else {
            _operationStopwatch.stop();
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
      
      final result = await repository.hardRefreshBooks(
        CourseCategory.korean,
        pageSize: _pageSize
      );
      
      await result.fold(
        onSuccess: (books) async {
          final uniqueBooks = _removeDuplicates(books);
          final hasMoreResult = await repository.hasMoreBooks(CourseCategory.korean, uniqueBooks.length);
          
          _operationStopwatch.stop();
          debugPrint('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueBooks.length} books');
          
          emit(KoreanBooksState(
            books: uniqueBooks,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
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
      
      final result = await repository.getBookPdf(bookId);
      
      result.fold(
        onSuccess: (pdfFile) {
          _operationStopwatch.stop();
          
          if (pdfFile != null) {
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
          } else {
            debugPrint('PDF file is null after ${_operationStopwatch.elapsedMilliseconds}ms for book: $bookId');
            
            emit(state.copyWith(
              currentOperation: KoreanBooksOperation(
                type: KoreanBooksOperationType.loadPdf,
                status: KoreanBooksOperationStatus.failed,
                bookId: bookId,
                message: 'PDF file is empty or corrupted',
              ),
            ));
          }
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
          bookId: chapterId, // Using chapterId as bookId for the operation
        ),
      ));
      
      final result = await repository.getChapterPdf(bookId, chapterId);
      
      result.fold(
        onSuccess: (pdfFile) {
          _operationStopwatch.stop();
          
          if (pdfFile != null) {
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
          } else {
            debugPrint('Chapter PDF file is null after ${_operationStopwatch.elapsedMilliseconds}ms for chapter: $chapterId');
            
            emit(state.copyWith(
              currentOperation: KoreanBooksOperation(
                type: KoreanBooksOperationType.loadPdf,
                status: KoreanBooksOperationStatus.failed,
                bookId: chapterId,
                message: 'Chapter PDF file is empty or corrupted',
              ),
            ));
          }
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
      final UserEntity? user = _getCurrentUser();
      if (user == null) {
        debugPrint('No authenticated user for edit permission check');
        return false;
      }
      
      if (await adminService.isUserAdmin(user.uid)) {
        debugPrint('User is admin, granting edit permission for book: $bookId');
        return true;
      }
      
      final book = state.books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => const BookItem(
          id: '', title: '', description: '', 
          duration: '', chaptersCount: 0, icon: Icons.book,
          level: BookLevel.beginner, courseCategory: CourseCategory.korean,
          country: '', category: ''
        )
      );
      
      final canEdit = book.id.isNotEmpty && book.creatorUid == user.uid;
      debugPrint('Edit permission for book $bookId: $canEdit (user: ${user.uid}, creator: ${book.creatorUid})');
      
      return canEdit;
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteBook(String bookId) async {
    return canUserEditBook(bookId);
  }
  
  Future<void> regenerateBookImageUrl(BookItem book) async {
    if (book.bookImagePath == null || book.bookImagePath!.isEmpty) {
      debugPrint('No image path to regenerate for book: ${book.id}');
      return;
    }
    
    try {
      debugPrint('Regenerating image URL for book: ${book.id}');
      final result = await repository.regenerateImageUrl(book);
      
      result.fold(
        onSuccess: (newImageUrl) {
          if (newImageUrl != null) {
            final updatedBook = book.copyWith(bookImage: newImageUrl);
            updateBookInState(updatedBook);
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
  
  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
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