import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/features/books/domain/usecases/search_books_usecase.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/usecases/check_book_edit_permission_usecase.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

part 'book_search_state.dart';

class BookSearchCubit extends Cubit<BookSearchState> {
  final SearchBooksUseCase searchBooksUseCase;
  final CheckBookEditPermissionUseCase checkBookEditPermissionUseCase;
  
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);
  String _lastSearchQuery = '';
  final Stopwatch _operationStopwatch = Stopwatch();
  
  BookSearchCubit({
    required this.searchBooksUseCase,
    required this.checkBookEditPermissionUseCase,
  }) : super(const BookSearchInitial());

  void searchBooks(String query) {
    _searchDebounceTimer?.cancel();
    
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.length < 2) {
      debugPrint('Search query too short, clearing search results');
      _lastSearchQuery = '';
      
      emit(state.copyWith(
        searchResults: [],
        currentQuery: '',
        isSearching: false,
        isLoading: false,
        error: null,
        errorType: null,
        currentOperation: const BookSearchOperation(
          type: BookSearchOperationType.clearSearch,
          status: BookSearchOperationStatus.completed,
        ),
      ));
      _clearOperationAfterDelay();
      return;
    }
    
    if (trimmedQuery == _lastSearchQuery && state.searchResults.isNotEmpty) {
      debugPrint('Duplicate search query, skipping');
      return;
    }
    
    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      _performSearch(trimmedQuery);
    });
  }
  
  Future<void> _performSearch(String query) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Search operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    _lastSearchQuery = query;
    
    try {
      emit(state.copyWith(
        isLoading: true,
        isSearching: true,
        currentQuery: query,
        error: null,
        errorType: null,
        currentOperation: BookSearchOperation(
          type: BookSearchOperationType.search,
          status: BookSearchOperationStatus.inProgress,
          query: query,
        ),
      ));
      
      final params = SearchBooksParams(
        category: CourseCategory.korean,
        query: query,
      );
      
      final result = await searchBooksUseCase.execute(params);
      
      result.fold(
        onSuccess: (searchResults) {
          _operationStopwatch.stop();
          debugPrint('Search completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${searchResults.length} results for query: "$query"');
          
          emit(state.copyWith(
            searchResults: searchResults,
            currentQuery: query,
            isSearching: true,
            isLoading: false,
            error: null,
            errorType: null,
            currentOperation: BookSearchOperation(
              type: BookSearchOperationType.search,
              status: BookSearchOperationStatus.completed,
              query: query,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Search failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(BookSearchOperation(
            type: BookSearchOperationType.search,
            status: BookSearchOperationStatus.failed,
            query: query,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error searching books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to search books: $e', BookSearchOperationType.search, query);
    }
  }

  void clearSearch() {
    debugPrint('Clearing search results');
    _searchDebounceTimer?.cancel();
    _lastSearchQuery = '';
    
    emit(state.copyWith(
      searchResults: [],
      currentQuery: '',
      isSearching: false,
      isLoading: false,
      error: null,
      errorType: null,
      currentOperation: const BookSearchOperation(
        type: BookSearchOperationType.clearSearch,
        status: BookSearchOperationStatus.completed,
      ),
    ));
    _clearOperationAfterDelay();
  }

  Future<bool> canUserEditBook(String bookId) async {
    try {
      final book = state.searchResults.firstWhere(
        (b) => b.id == bookId,
        orElse: () => const BookItem(
          id: '',
          title: '',
          description: '',
          duration: '',
          chaptersCount: 0,
          icon: Icons.book,
          level: BookLevel.beginner,
          courseCategory: CourseCategory.korean,
          country: '', 
          category: '',
        ),
      );
      
      final params = CheckBookEditPermissionParams(
        bookId: bookId,
        book: book.id.isNotEmpty ? book : null,
      );
      
      final result = await checkBookEditPermissionUseCase.execute(params);
      
      return result.fold(
        onSuccess: (canEdit) {
          debugPrint('Edit permission for book $bookId: $canEdit');
          return canEdit;
        },
        onFailure: (_, __) {
          debugPrint('Error checking edit permission for book $bookId');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteBook(String bookId) async {
    return canUserEditBook(bookId);
  }

  void _handleError(String message, BookSearchOperationType operationType, [String? query]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(BookSearchOperation(
      type: operationType,
      status: BookSearchOperationStatus.failed,
      message: message,
      query: query,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != BookSearchOperationStatus.none) {
        emit(state.copyWithOperation(
          const BookSearchOperation(status: BookSearchOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing BookSearchCubit...');
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}