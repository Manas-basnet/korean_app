import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_result.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/save_test_result_usecase.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/load_user_test_results_usecase.dart';
import 'package:korean_language_app/features/test_results/domain/usecases/get_user_latest_result_usecase.dart';

part 'test_results_state.dart';

class TestResultsCubit extends Cubit<TestResultsState> {
  final SaveTestResultUseCase saveTestResultUseCase;
  final LoadUserTestResultsUseCase loadUserTestResultsUseCase;
  final GetUserLatestResultUseCase getUserLatestResultUseCase;
  
  final Stopwatch _operationStopwatch = Stopwatch();
  
  TestResultsCubit({
    required this.saveTestResultUseCase,
    required this.loadUserTestResultsUseCase,
    required this.getUserLatestResultUseCase,
  }) : super(const TestResultsInitial());

  Future<void> saveTestResult(TestResult testResult) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Save result operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const TestResultsOperation(
          type: TestResultsOperationType.saveResult,
          status: TestResultsOperationStatus.inProgress,
        ),
      ));

      final result = await saveTestResultUseCase.execute(testResult);

      result.fold(
        onSuccess: (_) {
          _operationStopwatch.stop();
          debugPrint('Test result saved successfully in ${_operationStopwatch.elapsedMilliseconds}ms');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            currentOperation: const TestResultsOperation(
              type: TestResultsOperationType.saveResult,
              status: TestResultsOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Save result failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(TestResultsOperation(
            type: TestResultsOperationType.saveResult,
            status: TestResultsOperationStatus.failed,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error saving test result after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to save test result: $e', TestResultsOperationType.saveResult);
    }
  }

  Future<void> loadUserResults({int limit = 20}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Load results operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const TestResultsOperation(
          type: TestResultsOperationType.loadResults,
          status: TestResultsOperationStatus.inProgress,
        ),
      ));

      final result = await loadUserTestResultsUseCase.execute(
        LoadUserTestResultsParams(limit: limit)
      );

      result.fold(
        onSuccess: (results) {
          _operationStopwatch.stop();
          debugPrint('Loaded ${results.length} user results in ${_operationStopwatch.elapsedMilliseconds}ms');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            results: results,
            currentOperation: const TestResultsOperation(
              type: TestResultsOperationType.loadResults,
              status: TestResultsOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Load results failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(TestResultsOperation(
            type: TestResultsOperationType.loadResults,
            status: TestResultsOperationStatus.failed,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error loading user results after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to load user results: $e', TestResultsOperationType.loadResults);
    }
  }

  Future<void> loadUserLatestResult(String testId) async {
    try {
      final result = await getUserLatestResultUseCase.execute(
        GetUserLatestResultParams(testId: testId)
      );
      
      result.fold(
        onSuccess: (latestResult) {
          emit(state.copyWith(latestResult: latestResult));
        },
        onFailure: (message, type) {
          debugPrint('Failed to load latest result: $message');
        },
      );
    } catch (e) {
      debugPrint('Error loading latest result: $e');
    }
  }

  // High-level helper methods for UI (maintained for backwards compatibility)
  Future<List<TestResult>> getUserTestResultsWithHandling() async {
    try {
      final result = await loadUserTestResultsUseCase.execute(
        const LoadUserTestResultsParams()
      );
      
      return result.fold(
        onSuccess: (results) {
          debugPrint('Retrieved ${results.length} test results');
          return results;
        },
        onFailure: (message, type) {
          debugPrint('Failed to get user test results: $message');
          return [];
        },
      );
    } catch (e) {
      debugPrint('Error getting user test results: $e');
      return [];
    }
  }

  Future<List<TestResult>> getCachedUserResults() async {
    try {
      final result = await loadUserTestResultsUseCase.execute(
        const LoadUserTestResultsParams(cacheOnly: true)
      );
      
      return result.fold(
        onSuccess: (results) {
          debugPrint('Retrieved ${results.length} cached test results');
          return results;
        },
        onFailure: (message, type) {
          debugPrint('Failed to get cached user test results: $message');
          return [];
        },
      );
    } catch (e) {
      debugPrint('Error getting cached user test results: $e');
      return [];
    }
  }

  Future<List<TestResult>> getTestResultsWithHandling() async {
    try {
      final results = await getUserTestResultsWithHandling();
      if (results.isNotEmpty) {
        return results;
      }
      
      return await getCachedUserResults();
    } catch (e) {
      debugPrint('Error getting test results: $e');
      return [];
    }
  }

  void _handleError(String message, TestResultsOperationType operationType, [String? testId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(TestResultsOperation(
      type: operationType,
      status: TestResultsOperationStatus.failed,
      message: message,
      testId: testId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != TestResultsOperationStatus.none) {
        emit(state.copyWithOperation(
          const TestResultsOperation(status: TestResultsOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing TestResultsCubit...');
    return super.close();
  }
}