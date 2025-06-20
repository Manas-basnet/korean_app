import 'dart:async';
import 'dart:developer' as dev;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/enums/book_level.dart';
import 'package:korean_language_app/core/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';

part 'tests_state.dart';

class TestsCubit extends Cubit<TestsState> {
  final TestsRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  final NetworkInfo networkInfo;
  
  int _currentPage = 0;
  static const int _pageSize = 5;
  TestCategory _currentCategory = TestCategory.all;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final Stopwatch _operationStopwatch = Stopwatch();
  
  // Add debouncing for load more requests
  Timer? _loadMoreDebounceTimer;
  static const Duration _loadMoreDebounceDelay = Duration(milliseconds: 300);
  
  TestsCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
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
        currentOperation: const TestsOperation(
          type: TestsOperationType.loadTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));
      
      final result = await repository.getTests(page: 0, pageSize: _pageSize);
      
      await result.fold(
        onSuccess: (tests) async {
          final hasMoreResult = await repository.hasMoreTests(tests.length);

          _currentPage = tests.length ~/ _pageSize;
          final uniqueTests = _removeDuplicates(tests);
          
          _operationStopwatch.stop();
          dev.log('loadInitialTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueTests.length} tests');
          
          emit(TestsState(
            tests: uniqueTests,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadTests,
              status: TestsOperationStatus.completed,
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
        currentOperation: const TestsOperation(
          type: TestsOperationType.loadTests,
          status: TestsOperationStatus.inProgress,
        ),
      ));
      
      final result = await repository.getTestsByCategory(category, page: 0, pageSize: _pageSize);
      
      await result.fold(
        onSuccess: (tests) async {
          final hasMoreResult = await repository.hasMoreTestsByCategory(category, tests.length);
          final uniqueTests = _removeDuplicates(tests);
          
          _currentPage = uniqueTests.length ~/ _pageSize;
          
          _operationStopwatch.stop();
          dev.log('loadTestsByCategory completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueTests.length} tests');
          
          emit(TestsState(
            tests: uniqueTests,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
            currentOperation: const TestsOperation(
              type: TestsOperationType.loadTests,
              status: TestsOperationStatus.completed,
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
  
  void requestLoadMoreTests() {
    _loadMoreDebounceTimer?.cancel();
    _loadMoreDebounceTimer = Timer(_loadMoreDebounceDelay, () {
      _performLoadMoreTests();
    });
  }
  
  Future<void> _performLoadMoreTests() async {
    final currentState = state;
    
    if (!currentState.hasMore) {
      dev.log('loadMoreTests skipped - no more tests available');
      return;
    }
    
    if (currentState.currentOperation.isInProgress) {
      dev.log('loadMoreTests skipped - operation already in progress: ${currentState.currentOperation.type}');
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
      
      ApiResult<List<TestItem>> result;
      
      if (_currentCategory == TestCategory.all) {
        result = await repository.getTests(
          page: _currentPage,
          pageSize: _pageSize
        );
      } else {
        result = await repository.getTestsByCategory(
          _currentCategory,
          page: _currentPage,
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
              hasMoreResult = await repository.hasMoreTests(allTests.length);
            } else {
              hasMoreResult = await repository.hasMoreTestsByCategory(_currentCategory, allTests.length);
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
              currentOperation: const TestsOperation(
                type: TestsOperationType.loadMoreTests,
                status: TestsOperationStatus.completed,
              ),
            ));
          } else {
            _operationStopwatch.stop();
            dev.log('loadMoreTests completed in ${_operationStopwatch.elapsedMilliseconds}ms with no new tests');
            
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
      
      ApiResult<List<TestItem>> result;
      if (_currentCategory == TestCategory.all) {
        result = await repository.hardRefreshTests(pageSize: _pageSize);
      } else {
        result = await repository.hardRefreshTestsByCategory(_currentCategory, pageSize: _pageSize);
      }
      
      await result.fold(
        onSuccess: (tests) async {
          final uniqueTests = _removeDuplicates(tests);
          
          ApiResult<bool> hasMoreResult;
          if (_currentCategory == TestCategory.all) {
            hasMoreResult = await repository.hasMoreTests(uniqueTests.length);
          } else {
            hasMoreResult = await repository.hasMoreTestsByCategory(_currentCategory, uniqueTests.length);
          }
          
          _currentPage = uniqueTests.length ~/ _pageSize;
          
          _operationStopwatch.stop();
          dev.log('hardRefresh completed in ${_operationStopwatch.elapsedMilliseconds}ms with ${uniqueTests.length} tests');
          
          emit(TestsState(
            tests: uniqueTests,
            hasMore: hasMoreResult.fold(
              onSuccess: (hasMore) => hasMore,
              onFailure: (_, __) => false,
            ),
            currentOperation: const TestsOperation(
              type: TestsOperationType.refreshTests,
              status: TestsOperationStatus.completed,
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

      final result = await repository.getTestById(testId);

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