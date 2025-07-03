import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/usecase/check_book_permission_usecase.dart';
import 'package:korean_language_app/features/books/domain/usecase/search_books_usecase.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

part 'book_search_state.dart';

class BookSearchCubit extends Cubit<BookSearchState> {
  final SearchBooksUseCase searchBooksUseCase;
  final CheckBookEditPermissionUseCase checkEditPermissionUseCase;
  
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);
  String _lastSearchQuery = '';
  final Stopwatch _operationStopwatch = Stopwatch();
  
  BookSearchCubit({
    required this.searchBooksUseCase,
    required this.checkEditPermissionUseCase,
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
      
      final result = await searchBooksUseCase.execute(
        SearchBooksParams(query: query, limit: 20)
      );
      
      result.fold(
        onSuccess: (searchResult) {
          final uniqueSearchResults = _removeDuplicates(searchResult.books);
          
          _operationStopwatch.stop();
          debugPrint('Search completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueSearchResults.length} results for query: "$query"');
          
          emit(state.copyWith(
            searchResults: uniqueSearchResults,
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

  List<BookItem> _removeDuplicates(List<BookItem> books) {
    final Set<String> seenIds = <String>{};
    return books.where((book) => seenIds.add(book.id)).toList();
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
    Timer(const Duration(seconds: 2), () {
      if (!isClosed && state.currentOperation.status != BookSearchOperationStatus.none) {
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