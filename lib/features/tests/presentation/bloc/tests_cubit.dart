import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/features/tests/domain/usecases/load_tests_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/check_test_edit_permission_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/get_test_by_id_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/start_test_session_usecase.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';

part 'tests_state.dart';

class TestsCubit extends Cubit<TestsState> {
  final LoadTestsUseCase loadTestsUseCase;
  final CheckTestEditPermissionUseCase checkEditPermissionUseCase;
  final GetTestByIdUseCase getTestByIdUseCase;
  final StartTestSessionUseCase startTestSessionUseCase;
  final NetworkInfo networkInfo;
  
  int _currentPage = 0;
  static const int _pageSize = 5;
  TestCategory _currentCategory = TestCategory.all;
  TestSortType _currentSortType = TestSortType.recent;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  Timer? _loadMoreDebounceTimer;
  static const Duration _loadMoreDebounceDelay = Duration(milliseconds: 300);
  
  // ✅ Permission cache for synchronous access
  final Map<String, bool> _permissionCache = {};
  final Map<String, DateTime> _permissionCacheTimestamps = {};
  static const Duration _permissionCacheTimeout = Duration(minutes: 5);
  
  TestsCubit({
    required this.loadTestsUseCase,
    required this.checkEditPermissionUseCase,
    required this.getTestByIdUseCase,
    required this.startTestSessionUseCase,
    required this.networkInfo,
  }) : super(const TestsInitial()) {
    _initializeConnectivityListener();
  }

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      
      if (isConnected && (state.tests.isEmpty || state.hasError)) {
        debugPrint('Connection restored, reloading tests...');
        if (_currentCategory == TestCategory.all) {
          loadInitialTests(sortType: _currentSortType);
        } else {
          loadTestsByCategory(_currentCategory, sortType: _currentSortType);
        }
      }
    });
  }
  
  Future<void> loadInitialTests({TestSortType sortType = TestSortType.recent}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load operation already in progress, skipping...');
      return;
    }
    
    _currentCategory = TestCategory.all;
    _currentSortType = sortType;
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const TestsOperation(
          type: TestsOperationType.loadTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));
      
      final result = await loadTestsUseCase.execute(LoadTestsParams(
        page: 0,
        pageSize: _pageSize,
        sortType: sortType,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadInitialTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} tests');
          
          emit(TestsState(
            tests: loadResult.tests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadTests,
              status: TestsOperationStatus.completed,
            ),
            currentSortType: sortType,
          ));
          
          // ✅ Precompute permissions for loaded tests
          _precomputePermissionsInBackground(loadResult.tests);
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadInitialTests failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.loadTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading initial tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load tests: $e', TestsOperationType.loadTests);
    }
  }

  Future<void> loadTestsByCategory(TestCategory category, {TestSortType sortType = TestSortType.recent}) async {
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
        currentOperation: const TestsOperation(
          type: TestsOperationType.loadTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));

      final result = await loadTestsUseCase.execute(LoadTestsParams(
        page: 0,
        pageSize: _pageSize,
        sortType: sortType,
        category: category,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          _currentPage = loadResult.currentPage;
          _operationStopwatch.stop();
          debugPrint('loadTestsByCategory completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} tests');
          
          emit(TestsState(
            tests: loadResult.tests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadTests,
              status: TestsOperationStatus.completed,
            ),
            currentSortType: sortType,
          ));
          
          // ✅ Precompute permissions for loaded tests
          _precomputePermissionsInBackground(loadResult.tests);
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadTestsByCategory failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.loadTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading tests by category after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load tests: $e', TestsOperationType.loadTests);
    }
  }

  void changeSortType(TestSortType sortType) {
    if (_currentSortType == sortType) return;
    
    _currentSortType = sortType;
    if (_currentCategory == TestCategory.all) {
      loadInitialTests(sortType: sortType);
    } else {
      loadTestsByCategory(_currentCategory, sortType: sortType);
    }
  }
  
  void requestLoadMoreTests() {
    _loadMoreDebounceTimer?.cancel();
    _loadMoreDebounceTimer = Timer(_loadMoreDebounceDelay, () {
      _performLoadMoreTests();
    });
  }
  

  Future<void> _performLoadMoreTests() async {
    final currentState = state;
    
    if (!currentState.hasMore || currentState.currentOperation.isInProgress) {
      return;
    }
    
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      debugPrint('loadMoreTests skipped - not connected');
      return;
    }
    
    _operationStopwatch.reset();
    _operationStopwatch.start();
    
    try {
      emit(currentState.copyWith(
        currentOperation: const TestsOperation(
          type: TestsOperationType.loadMoreTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));
      
      final nextPage = _currentPage + 1;
      
      final result = await loadTestsUseCase.execute(LoadTestsParams(
        page: nextPage,
        pageSize: _pageSize,
        sortType: _currentSortType,
        category: _currentCategory == TestCategory.all ? null : _currentCategory,
        loadMore: true,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          if (loadResult.tests.isNotEmpty) {
            final allTests = [...state.tests, ...loadResult.tests];
            _currentPage = nextPage;
            
            _operationStopwatch.stop();
            debugPrint('loadMoreTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} new tests');
            
            emit(state.copyWith(
              tests: allTests,
              hasMore: loadResult.hasMore,
              currentOperation: const TestsOperation(
                type: TestsOperationType.loadMoreTests,
                status: TestsOperationStatus.completed,
              ),
            ));

            // ✅ Precompute permissions for new tests
            _precomputePermissionsInBackground(loadResult.tests);
          } else {
            emit(state.copyWith(
              hasMore: false,
              currentOperation: const TestsOperation(
                type: TestsOperationType.loadMoreTests,
                status: TestsOperationStatus.completed,
              ),
            ));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('loadMoreTests failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message, 
            errorType: type
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.loadMoreTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading more tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load more tests: $e', TestsOperationType.loadMoreTests);
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
        currentOperation: const TestsOperation(
          type: TestsOperationType.refreshTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));
      
      _currentPage = 0;
      // ✅ Clear permission cache on refresh
      _clearPermissionCache();

      final result = await loadTestsUseCase.execute(LoadTestsParams(
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
          debugPrint('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} tests');
          
          emit(TestsState(
            tests: loadResult.tests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.refreshTests,
              status: TestsOperationStatus.completed,
            ),
            currentSortType: _currentSortType,
          ));

          // ✅ Precompute permissions for refreshed tests
          _precomputePermissionsInBackground(loadResult.tests);
          
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('hardRefresh failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.refreshTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error refreshing tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh tests: $e', TestsOperationType.refreshTests);
    }
  }

  TestCategory get currentCategory => _currentCategory;
  TestSortType get currentSortType => _currentSortType;

  Future<void> loadTestById(String testId) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load test operation already in progress, skipping...');
      return;
    }

    try {
      emit(state.copyWith(
        selectedTest: null,
        currentOperation: TestsOperation(
          type: TestsOperationType.loadTestById,
          status: TestsOperationStatus.inProgress,
          testId: testId,
        ),
      ));

      final result = await getTestByIdUseCase.execute(GetTestByIdParams(
        testId: testId,
        recordView: true,
      ));

      result.fold(
        onSuccess: (test) {
          emit(state.copyWith(
            selectedTest: test,
            currentOperation: TestsOperation(
              type: TestsOperationType.loadTestById,
              status: TestsOperationStatus.completed,
              testId: testId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
          ).copyWithOperation(TestsOperation(
            type: TestsOperationType.loadTestById,
            status: TestsOperationStatus.failed,
            testId: testId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _handleError('Failed to load test: $e', TestsOperationType.loadTestById, testId);
    }
  }
  
  // ✅ Async method for initial permission checking
  Future<bool> canUserEditTest(TestItem test) async {
    try {
      // Check cache first
      if (_isPermissionCached(test.id)) {
        return _permissionCache[test.id]!;
      }
      
      final result = await checkEditPermissionUseCase.execute(
        CheckTestPermissionParams(testId: test.id, testCreatorUid: test.creatorUid)
      );
      
      final canEdit = result.fold(
        onSuccess: (permissionResult) => permissionResult.canEdit,
        onFailure: (message, type) {
          debugPrint('Failed to check edit permission: $message');
          return false;
        },
      );
      
      // Cache the result
      _cachePermission(test.id, canEdit);
      return canEdit;
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }

  // ✅ Synchronous method for UI rendering (no async operations!)
  bool canUserEditTestSync(TestItem test) {
    // Only return cached results, never perform async operations
    if (_isPermissionCached(test.id)) {
      return _permissionCache[test.id]!;
    }
    
    // Return false as default if not cached yet
    // This will be updated once permissions are precomputed
    return false;
  }
  
  Future<bool> canUserDeleteTest(TestItem test) async {
    return canUserEditTest(test);
  }

  // ✅ Permission caching methods
  void _cachePermission(String testId, bool canEdit) {
    _permissionCache[testId] = canEdit;
    _permissionCacheTimestamps[testId] = DateTime.now();
  }

  bool _isPermissionCached(String testId) {
    if (!_permissionCache.containsKey(testId)) return false;
    
    final timestamp = _permissionCacheTimestamps[testId];
    if (timestamp == null) return false;
    
    final isExpired = DateTime.now().difference(timestamp) > _permissionCacheTimeout;
    if (isExpired) {
      _permissionCache.remove(testId);
      _permissionCacheTimestamps.remove(testId);
      return false;
    }
    
    return true;
  }

  void _clearPermissionCache() {
    _permissionCache.clear();
    _permissionCacheTimestamps.clear();
    debugPrint('Permission cache cleared');
  }

  // ✅ Background permission precomputation
  void _precomputePermissionsInBackground(List<TestItem> tests) {
    if (tests.isEmpty) return;
    
    // Use microtask to avoid blocking UI
    Future.microtask(() async {
      try {
        debugPrint('Precomputing permissions for ${tests.length} tests...');
        
        // Process in small batches to avoid blocking
        const batchSize = 5;
        for (int i = 0; i < tests.length; i += batchSize) {
          final batch = tests.skip(i).take(batchSize);
          
          await Future.wait(batch.map((test) async {
            if (!_isPermissionCached(test.id)) {
              final canEdit = await canUserEditTest(test);
              debugPrint('Cached permission for ${test.id}: $canEdit');
            }
          }));
          
          // Small delay between batches to keep UI responsive
          if (i + batchSize < tests.length) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
        
        debugPrint('Permission precomputation completed');
      } catch (e) {
        debugPrint('Error precomputing permissions: $e');
      }
    });
  }
  
  void _handleError(String message, TestsOperationType operationType, [String? testId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(TestsOperation(
      type: operationType,
      status: TestsOperationStatus.failed,
      message: message,
      testId: testId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 2), () {
      if (!isClosed && state.currentOperation.status != TestsOperationStatus.none) {
        emit(state.copyWithOperation(
          const TestsOperation(status: TestsOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing TestsCubit...');
    _connectivitySubscription?.cancel();
    _loadMoreDebounceTimer?.cancel();
    _clearPermissionCache();
    return super.close();
  }
}