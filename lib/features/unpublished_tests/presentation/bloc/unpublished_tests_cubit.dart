import 'dart:async';
import 'dart:developer' as dev;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/enums/book_level.dart';
import 'package:korean_language_app/core/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';
import 'package:korean_language_app/features/unpublished_tests/domain/repositories/unpublished_tests_repository.dart';

part 'unpublished_tests_state.dart';

class UnpublishedTestsCubit extends Cubit<UnpublishedTestsState> {
  final UnpublishedTestsRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  int _currentPage = 0;
  static const int _pageSize = 5;
  bool _isConnected = true;
  TestCategory _currentCategory = TestCategory.all;
  
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);
  String _lastSearchQuery = '';
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  
  UnpublishedTestsCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
  }) : super(const UnpublishedTestsInitial()) {
    _initializeConnectivityListener();
  }

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;
      
      if (!wasConnected && _isConnected && (state.tests.isEmpty || state.hasError)) {
        dev.log('Connection restored, reloading unpublished tests...');
        if (_currentCategory == TestCategory.all) {
          loadInitialTests();
        } else {
          loadTestsByCategory(_currentCategory);
        }
      }
    });
  }
  
  Future<void> loadInitialTests() async {
    if (state.currentOperation.isInProgress) {
      dev.log('Load operation already in progress, skipping...');
      return;
    }
    
    _currentCategory = TestCategory.all;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const UnpublishedTestsOperation(
          type: UnpublishedTestsOperationType.loadTests,
          status: UnpublishedTestsOperationStatus.inProgress,
        ),
      ));
      
      final result = await repository.getUnpublishedTests(page: 0, pageSize: _pageSize);
      
      await result.fold(
        onSuccess: (tests) async {
          final hasMoreResult = await repository.hasMoreUnpublishedTests(tests.length);

          _currentPage = tests.length ~/ _pageSize;
          final uniqueTests = _removeDuplicates(tests);
          
          _operationStopwatch.stop();
          dev.log('loadInitialTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueTests.length} tests');
          
          emit(UnpublishedTestsState(
            tests: uniqueTests,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
            currentOperation: const UnpublishedTestsOperation(
              type: UnpublishedTestsOperationType.loadTests,
              status: UnpublishedTestsOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          dev.log('loadInitialTests failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const UnpublishedTestsOperation(
            type: UnpublishedTestsOperationType.loadTests,
            status: UnpublishedTestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error loading initial tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load tests: $e', UnpublishedTestsOperationType.loadTests);
    }
  }

  Future<void> loadTestsByCategory(TestCategory category) async {
    if (state.currentOperation.isInProgress) {
      dev.log('Load operation already in progress, skipping...');
      return;
    }
    
    _currentCategory = category;
    _currentPage = 0;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const UnpublishedTestsOperation(
          type: UnpublishedTestsOperationType.loadTests,
          status: UnpublishedTestsOperationStatus.inProgress,
        ),
      ));
      
      final result = await repository.getUnpublishedTestsByCategory(category, page: 0, pageSize: _pageSize);
      
      await result.fold(
        onSuccess: (tests) async {
          final hasMoreResult = await repository.hasMoreUnpublishedTestsByCategory(category, tests.length);
          final uniqueTests = _removeDuplicates(tests);
          
          _currentPage = uniqueTests.length ~/ _pageSize;
          
          _operationStopwatch.stop();
          dev.log('loadTestsByCategory completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueTests.length} tests');
          
          emit(UnpublishedTestsState(
            tests: uniqueTests,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
            currentOperation: const UnpublishedTestsOperation(
              type: UnpublishedTestsOperationType.loadTests,
              status: UnpublishedTestsOperationStatus.completed,
            ),
          ));
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          dev.log('loadTestsByCategory failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const UnpublishedTestsOperation(
            type: UnpublishedTestsOperationType.loadTests,
            status: UnpublishedTestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error loading tests by category after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load tests: $e', UnpublishedTestsOperationType.loadTests);
    }
  }
  
  Future<void> loadMoreTests() async {    
    if (!state.hasMore || !_isConnected || state.currentOperation.isInProgress) {
      dev.log('loadMoreTests skipped - hasMore: ${state.hasMore}, connected: $_isConnected, inProgress: ${state.currentOperation.isInProgress}');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        currentOperation: const UnpublishedTestsOperation(
          type: UnpublishedTestsOperationType.loadMoreTests,
          status: UnpublishedTestsOperationStatus.inProgress,
        ),
      ));
      
      ApiResult<List<TestItem>> result;
      
      if (_currentCategory == TestCategory.all) {
        result = await repository.getUnpublishedTests(
          page: _currentPage + 1,
          pageSize: _pageSize
        );
      } else {
        result = await repository.getUnpublishedTestsByCategory(
          _currentCategory,
          page: _currentPage + 1,
          pageSize: _pageSize
        );
      }
      
      await result.fold(
        onSuccess: (moreTests) async {
          final existingIds = state.tests.map((test) => test.id).toSet();
          final uniqueNewTests = moreTests.where((test) => !existingIds.contains(test.id)).toList();
          
          if (uniqueNewTests.isNotEmpty) {
            final allTests = [...state.tests, ...uniqueNewTests];
            
            ApiResult<bool> hasMoreResult;
            if (_currentCategory == TestCategory.all) {
              hasMoreResult = await repository.hasMoreUnpublishedTests(allTests.length);
            } else {
              hasMoreResult = await repository.hasMoreUnpublishedTestsByCategory(_currentCategory, allTests.length);
            }
            
            _currentPage = allTests.length ~/ _pageSize;
            
            _operationStopwatch.stop();
            dev.log('loadMoreTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueNewTests.length} new tests');
            
            emit(state.copyWith(
              tests: allTests,
              hasMore: hasMoreResult.fold(
                onSuccess: (hasMore) => hasMore,
                onFailure: (_, __) => false,
              ),
              currentOperation: const UnpublishedTestsOperation(
                type: UnpublishedTestsOperationType.loadMoreTests,
                status: UnpublishedTestsOperationStatus.completed,
              ),
            ));
          } else {
            _operationStopwatch.stop();
            dev.log('loadMoreTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with no new tests');
            
            emit(state.copyWith(
              hasMore: false,
              currentOperation: const UnpublishedTestsOperation(
                type: UnpublishedTestsOperationType.loadMoreTests,
                status: UnpublishedTestsOperationStatus.completed,
              ),
            ));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          dev.log('loadMoreTests failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message, 
            errorType: type
          ).copyWithOperation(const UnpublishedTestsOperation(
            type: UnpublishedTestsOperationType.loadMoreTests,
            status: UnpublishedTestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error loading more tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load more tests: $e', UnpublishedTestsOperationType.loadMoreTests);
    }
  }
  
  Future<void> hardRefresh() async {
    if (state.currentOperation.isInProgress) {
      dev.log('Refresh operation already in progress, skipping...');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const UnpublishedTestsOperation(
          type: UnpublishedTestsOperationType.refreshTests,
          status: UnpublishedTestsOperationStatus.inProgress,
        ),
      ));
      
      _currentPage = 0;
      
      ApiResult<List<TestItem>> result;
      if (_currentCategory == TestCategory.all) {
        result = await repository.hardRefreshUnpublishedTests(pageSize: _pageSize);
      } else {
        result = await repository.hardRefreshUnpublishedTestsByCategory(_currentCategory, pageSize: _pageSize);
      }
      
      await result.fold(
        onSuccess: (tests) async {
          final uniqueTests = _removeDuplicates(tests);
          
          ApiResult<bool> hasMoreResult;
          if (_currentCategory == TestCategory.all) {
            hasMoreResult = await repository.hasMoreUnpublishedTests(uniqueTests.length);
          } else {
            hasMoreResult = await repository.hasMoreUnpublishedTestsByCategory(_currentCategory, uniqueTests.length);
          }
          
          _currentPage = uniqueTests.length ~/ _pageSize;
          
          _operationStopwatch.stop();
          dev.log('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueTests.length} tests');
          
          emit(UnpublishedTestsState(
            tests: uniqueTests,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
            currentOperation: const UnpublishedTestsOperation(
              type: UnpublishedTestsOperationType.refreshTests,
              status: UnpublishedTestsOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          dev.log('hardRefresh failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const UnpublishedTestsOperation(
            type: UnpublishedTestsOperationType.refreshTests,
            status: UnpublishedTestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error refreshing tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh tests: $e', UnpublishedTestsOperationType.refreshTests);
    }
  }

  TestCategory get currentCategory => _currentCategory;
  
  void searchTests(String query) {
    _searchDebounceTimer?.cancel();
    
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.length < 2) {
      dev.log('Search query too short, clearing search results');
      _lastSearchQuery = '';
      
      emit(state.copyWith(
        tests: [],
        hasMore: false,
        isLoading: false,
        error: null,
        errorType: null,
        currentOperation: const UnpublishedTestsOperation(
          type: UnpublishedTestsOperationType.searchTests,
          status: UnpublishedTestsOperationStatus.completed,
        ),
      ));
      _clearOperationAfterDelay();
      return;
    }
    
    if (trimmedQuery == _lastSearchQuery) {
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
        currentOperation: const UnpublishedTestsOperation(
          type: UnpublishedTestsOperationType.searchTests,
          status: UnpublishedTestsOperationStatus.inProgress,
        ),
      ));
      
      final result = await repository.searchUnpublishedTests(query);
      
      result.fold(
        onSuccess: (searchResults) {
          final uniqueSearchResults = _removeDuplicates(searchResults);
          
          _operationStopwatch.stop();
          dev.log('Search completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueSearchResults.length} results for query: "$query"');
          
          emit(state.copyWith(
            tests: uniqueSearchResults,
            hasMore: false,
            isLoading: false,
            error: null,
            errorType: null,
            currentOperation: const UnpublishedTestsOperation(
              type: UnpublishedTestsOperationType.searchTests,
              status: UnpublishedTestsOperationStatus.completed,
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
          ).copyWithOperation(const UnpublishedTestsOperation(
            type: UnpublishedTestsOperationType.searchTests,
            status: UnpublishedTestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error searching tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to search tests: $e', UnpublishedTestsOperationType.searchTests);
    }
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
      
      final test = state.tests.firstWhere(
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

  void _handleError(String message, UnpublishedTestsOperationType operationType, [String? testId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(UnpublishedTestsOperation(
      type: operationType,
      status: UnpublishedTestsOperationStatus.failed,
      message: message,
      testId: testId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != UnpublishedTestsOperationStatus.none) {
        emit(state.copyWithOperation(
          const UnpublishedTestsOperation(status: UnpublishedTestsOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    dev.log('Closing UnpublishedTestsCubit...');
    _searchDebounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}