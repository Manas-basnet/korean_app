import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/enums/book_level.dart';
import 'package:korean_language_app/core/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/features/books/data/models/book_item.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';

part 'book_search_state.dart';

class BookSearchCubit extends Cubit<BookSearchState> {
  final KoreanBookRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);
  String _lastSearchQuery = '';
  final Stopwatch _operationStopwatch = Stopwatch();
  
  BookSearchCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
  }) : super(const BookSearchInitial());

  void searchBooks(String query) {
    _searchDebounceTimer?.cancel();
    
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.length < 2) {
      dev.log('Search query too short, clearing search results');
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
      dev.log('Duplicate search query, skipping');
      return;
    }
    
    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      _performSearch(trimmedQuery);
    });
  }
  
  Future<void> _performSearch(String query) async {
    if (state.currentOperation.isInProgress) {
      dev.log('Search operation already in progress, skipping...');
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
      
      final result = await repository.searchBooks(CourseCategory.korean, query);
      
      result.fold(
        onSuccess: (searchResults) {
          final uniqueSearchResults = _removeDuplicates(searchResults);
          
          _operationStopwatch.stop();
          dev.log('Search completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueSearchResults.length} results for query: "$query"');
          
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
          dev.log('Search failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
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
      dev.log('Error searching books after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to search books: $e', BookSearchOperationType.search, query);
    }
  }

  void clearSearch() {
    dev.log('Clearing search results');
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
      final UserEntity? user = _getCurrentUser();
      if (user == null) {
        dev.log('No authenticated user for edit permission check');
        return false;
      }
      
      if (await adminService.isUserAdmin(user.uid)) {
        dev.log('User is admin, granting edit permission for book: $bookId');
        return true;
      }
      
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
      
      final canEdit = book.id.isNotEmpty && book.creatorUid == user.uid;
      dev.log('Edit permission for book $bookId: $canEdit (user: ${user.uid}, creator: ${book.creatorUid})');
      
      return canEdit;
    } catch (e) {
      dev.log('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteBook(String bookId) async {
    return canUserEditBook(bookId);
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
    dev.log('Closing BookSearchCubit...');
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}