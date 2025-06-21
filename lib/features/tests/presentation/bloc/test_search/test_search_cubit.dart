import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';

part 'test_search_state.dart';

class TestSearchCubit extends Cubit<TestSearchState> {
  final TestsRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);
  String _lastSearchQuery = '';
  final Stopwatch _operationStopwatch = Stopwatch();
  
  TestSearchCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
  }) : super(const TestSearchInitial());

  void searchTests(String query) {
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
        currentOperation: const TestSearchOperation(
          type: TestSearchOperationType.clearSearch,
          status: TestSearchOperationStatus.completed,
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
        currentOperation: TestSearchOperation(
          type: TestSearchOperationType.search,
          status: TestSearchOperationStatus.inProgress,
          query: query,
        ),
      ));
      
      final result = await repository.searchTests(query);
      
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
            currentOperation: TestSearchOperation(
              type: TestSearchOperationType.search,
              status: TestSearchOperationStatus.completed,
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
          ).copyWithOperation(TestSearchOperation(
            type: TestSearchOperationType.search,
            status: TestSearchOperationStatus.failed,
            query: query,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error searching tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to search tests: $e', TestSearchOperationType.search, query);
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
      currentOperation: const TestSearchOperation(
        type: TestSearchOperationType.clearSearch,
        status: TestSearchOperationStatus.completed,
      ),
    ));
    _clearOperationAfterDelay();
  }

  Future<bool> canUserEditTest(String testId) async {
    try {
      final UserEntity? user = _getCurrentUser();
      if (user == null) {
        dev.log('No authenticated user for edit permission check');
        return false;
      }
      
      if (await adminService.isUserAdmin(user.uid)) {
        dev.log('User is admin, granting edit permission for test: $testId');
        return true;
      }
      
      final test = state.searchResults.firstWhere(
        (t) => t.id == testId,
        orElse: () => const TestItem(
          id: '', title: '', description: '', questions: [],
          level: BookLevel.beginner, category: TestCategory.practice,
        ),
      );
      
      final canEdit = test.id.isNotEmpty && test.creatorUid == user.uid;
      dev.log('Edit permission for test $testId: $canEdit (user: ${user.uid}, creator: ${test.creatorUid})');
      
      return canEdit;
    } catch (e) {
      dev.log('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteTest(String testId) async {
    return canUserEditTest(testId);
  }
  
  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }
  
  List<TestItem> _removeDuplicates(List<TestItem> tests) {
    final uniqueIds = <String>{};
    final uniqueTests = <TestItem>[];
    
    for (final test in tests) {
      if (uniqueIds.add(test.id)) {
        uniqueTests.add(test);
      }
    }
    
    return uniqueTests;
  }

  void _handleError(String message, TestSearchOperationType operationType, [String? query]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(TestSearchOperation(
      type: operationType,
      status: TestSearchOperationStatus.failed,
      message: message,
      query: query,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != TestSearchOperationStatus.none) {
        emit(state.copyWithOperation(
          const TestSearchOperation(status: TestSearchOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    dev.log('Closing TestSearchCubit...');
    _searchDebounceTimer?.cancel();
    return super.close();
  }
}