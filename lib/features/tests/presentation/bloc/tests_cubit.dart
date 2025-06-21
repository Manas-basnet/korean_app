import 'dart:async';
import 'dart:developer' as dev;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/test_item.dart';

// Use Cases
import 'package:korean_language_app/features/tests/domain/usecases/load_tests_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/check_test_edit_permission_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/rate_test_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/search_tests_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/get_test_by_id_usecase.dart';
import 'package:korean_language_app/features/tests/domain/usecases/start_test_session_usecase.dart';

// Use Case Parameters
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';

part 'tests_state.dart';

class TestsCubit extends Cubit<TestsState> {
  // Use Cases - Clean dependency injection
  final LoadTestsUseCase loadTestsUseCase;
  final CheckTestEditPermissionSimpleUseCase checkEditPermissionUseCase;
  final RateTestUseCase rateTestUseCase;
  final SearchTestsUseCase searchTestsUseCase;
  final GetTestByIdUseCase getTestByIdUseCase;
  final StartTestSessionUseCase startTestSessionUseCase;
  final NetworkInfo networkInfo;
  
  // State management variables - much simpler now
  int _currentPage = 0;
  static const int _pageSize = 5;
  TestCategory _currentCategory = TestCategory.all;
  TestSortType _currentSortType = TestSortType.recent;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  Timer? _loadMoreDebounceTimer;
  static const Duration _loadMoreDebounceDelay = Duration(milliseconds: 300);
  
  TestsCubit({
    required this.loadTestsUseCase,
    required this.checkEditPermissionUseCase,
    required this.rateTestUseCase,
    required this.searchTestsUseCase,
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
        dev.log('Connection restored, reloading tests...');
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
      dev.log('Load operation already in progress, skipping...');
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
          dev.log('loadInitialTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} tests');
          
          emit(TestsState(
            tests: loadResult.tests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadTests,
              status: TestsOperationStatus.completed,
            ),
            currentSortType: sortType,
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
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.loadTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error loading initial tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load tests: $e', TestsOperationType.loadTests);
    }
  }

  Future<void> loadTestsByCategory(TestCategory category, {TestSortType sortType = TestSortType.recent}) async {
    if (state.currentOperation.isInProgress) {
      dev.log('Load operation already in progress, skipping...');
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
      
      // SINGLE LINE - Use case handles all business logic
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
          dev.log('loadTestsByCategory completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} tests');
          
          emit(TestsState(
            tests: loadResult.tests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadTests,
              status: TestsOperationStatus.completed,
            ),
            currentSortType: sortType,
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
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.loadTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error loading tests by category after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
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
      dev.log('loadMoreTests skipped - not connected');
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
      
      final result = await loadTestsUseCase.execute(LoadTestsParams(
        page: _currentPage,
        pageSize: _pageSize,
        sortType: _currentSortType,
        category: _currentCategory == TestCategory.all ? null : _currentCategory,
        loadMore: true,
      ));
      
      result.fold(
        onSuccess: (loadResult) {
          final allTests = [...state.tests, ...loadResult.tests];
          _currentPage = loadResult.currentPage;
          
          _operationStopwatch.stop();
          dev.log('loadMoreTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} new tests');
          
          emit(state.copyWith(
            tests: allTests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadMoreTests,
              status: TestsOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          dev.log('loadMoreTests failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
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
      dev.log('Error loading more tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load more tests: $e', TestsOperationType.loadMoreTests);
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
        currentOperation: const TestsOperation(
          type: TestsOperationType.refreshTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));
      
      _currentPage = 0;
      
      // SINGLE LINE - Use case handles all business logic
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
          dev.log('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${loadResult.tests.length} tests');
          
          emit(TestsState(
            tests: loadResult.tests,
            hasMore: loadResult.hasMore,
            currentOperation: const TestsOperation(
              type: TestsOperationType.refreshTests,
              status: TestsOperationStatus.completed,
            ),
            currentSortType: _currentSortType,
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
          ).copyWithOperation(const TestsOperation(
            type: TestsOperationType.refreshTests,
            status: TestsOperationStatus.failed,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      dev.log('Error refreshing tests after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to refresh tests: $e', TestsOperationType.refreshTests);
    }
  }

  TestCategory get currentCategory => _currentCategory;
  TestSortType get currentSortType => _currentSortType;

  Future<void> loadTestById(String testId) async {
    if (state.currentOperation.isInProgress) {
      dev.log('Load test operation already in progress, skipping...');
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

      // SINGLE LINE - Use case handles all business logic
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

  Future<void> rateTest(String testId, double rating) async {
    try {
      // SINGLE LINE - Use case handles all business logic
      final result = await rateTestUseCase.execute(RateTestParams(
        testId: testId,
        rating: rating,
      ));
      
      result.fold(
        onSuccess: (_) {
          // Update local state
          if (state.selectedTest?.id == testId) {
            final updatedTest = state.selectedTest!.copyWith(
              rating: rating,
              ratingCount: state.selectedTest!.ratingCount + 1,
            );
            emit(state.copyWith(selectedTest: updatedTest));
          }
          
          final testIndex = state.tests.indexWhere((test) => test.id == testId);
          if (testIndex != -1) {
            final updatedTests = List<TestItem>.from(state.tests);
            updatedTests[testIndex] = updatedTests[testIndex].copyWith(
              rating: rating,
              ratingCount: updatedTests[testIndex].ratingCount + 1,
            );
            emit(state.copyWith(tests: updatedTests));
          }
        },
        onFailure: (message, type) {
          dev.log('Error rating test: $message');
        },
      );
    } catch (e) {
      dev.log('Error rating test: $e');
    }
  }
  
  Future<bool> canUserEditTest(String testId) async {
    try {
      final test = state.tests.firstWhere(
        (t) => t.id == testId,
        orElse: () => const TestItem(
          id: '', title: '', description: '', questions: [],
          level: BookLevel.beginner, category: TestCategory.practice,
        ),
      );
      
      if (test.id.isEmpty) return false;
      
      // SINGLE LINE - Use case handles all business logic
      return await checkEditPermissionUseCase.execute(testId, test.creatorUid);
    } catch (e) {
      dev.log('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteTest(String testId) async {
    return canUserEditTest(testId);
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
    dev.log('Closing TestsCubit...');
    _connectivitySubscription?.cancel();
    _loadMoreDebounceTimer?.cancel();
    return super.close();
  }
}