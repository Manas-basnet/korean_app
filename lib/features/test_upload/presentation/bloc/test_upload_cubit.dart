import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/features/test_upload/domain/test_upload_repository.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

part 'test_upload_state.dart';

class TestUploadCubit extends Cubit<TestUploadState> {
  final TestUploadRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  final Stopwatch _operationStopwatch = Stopwatch();
  
  TestUploadCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
  }) : super(const TestUploadInitial());

  /// Create test with optional image - atomic operation
  Future<void> createTest(TestItem test, {File? imageFile}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Create test operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const TestUploadOperation(
          type: TestUploadOperationType.createTest,
          status: TestUploadOperationStatus.inProgress,
        ),
      ));

      final result = await repository.createTest(test, imageFile: imageFile);

      result.fold(
        onSuccess: (createdTest) {
          _operationStopwatch.stop();
          debugPrint('Test created successfully in ${_operationStopwatch.elapsedMilliseconds}ms: ${createdTest.title} with ID: ${createdTest.id}');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            createdTest: createdTest,
            currentOperation: const TestUploadOperation(
              type: TestUploadOperationType.createTest,
              status: TestUploadOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Test creation failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(TestUploadOperation(
            type: TestUploadOperationType.createTest,
            status: TestUploadOperationStatus.failed,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error creating test after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to create test: $e', TestUploadOperationType.createTest);
    }
  }

  /// Update test with optional new image - atomic operation
  Future<void> updateTest(String testId, TestItem updatedTest, {File? imageFile}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Update test operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: TestUploadOperation(
          type: TestUploadOperationType.updateTest,
          status: TestUploadOperationStatus.inProgress,
          testId: testId,
        ),
      ));

      final result = await repository.updateTest(testId, updatedTest, imageFile: imageFile);

      result.fold(
        onSuccess: (updatedTestResult) {
          _operationStopwatch.stop();
          debugPrint('Test updated successfully in ${_operationStopwatch.elapsedMilliseconds}ms: ${updatedTestResult.title}');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            createdTest: updatedTestResult, // Store the updated test
            currentOperation: TestUploadOperation(
              type: TestUploadOperationType.updateTest,
              status: TestUploadOperationStatus.completed,
              testId: testId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Test update failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(TestUploadOperation(
            type: TestUploadOperationType.updateTest,
            status: TestUploadOperationStatus.failed,
            testId: testId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error updating test after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to update test: $e', TestUploadOperationType.updateTest, testId);
    }
  }

  /// Delete test and all associated files
  Future<void> deleteTest(String testId) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Delete test operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: TestUploadOperation(
          type: TestUploadOperationType.deleteTest,
          status: TestUploadOperationStatus.inProgress,
          testId: testId,
        ),
      ));

      final result = await repository.deleteTest(testId);

      result.fold(
        onSuccess: (success) {
          _operationStopwatch.stop();
          
          if (success) {
            debugPrint('Test deleted successfully in ${_operationStopwatch.elapsedMilliseconds}ms: $testId');
            emit(state.copyWith(
              isLoading: false,
              error: null,
              errorType: null,
              currentOperation: TestUploadOperation(
                type: TestUploadOperationType.deleteTest,
                status: TestUploadOperationStatus.completed,
                testId: testId,
              ),
            ));
          } else {
            emit(state.copyWithBaseState(
              error: 'Failed to delete test',
              isLoading: false,
            ).copyWithOperation(TestUploadOperation(
              type: TestUploadOperationType.deleteTest,
              status: TestUploadOperationStatus.failed,
              testId: testId,
              message: 'Failed to delete test',
            )));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Test deletion failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(TestUploadOperation(
            type: TestUploadOperationType.deleteTest,
            status: TestUploadOperationStatus.failed,
            testId: testId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error deleting test after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to delete test: $e', TestUploadOperationType.deleteTest, testId);
    }
  }

  // High-level helper methods for UI
  Future<bool> uploadNewTest(TestItem test, {File? imageFile}) async {
    try {
      await createTest(test, imageFile: imageFile);
      
      final currentState = state.currentOperation;
      if (currentState.status == TestUploadOperationStatus.completed && 
          currentState.type == TestUploadOperationType.createTest) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error uploading new test: $e');
      return false;
    }
  }

  Future<bool> updateExistingTest(String testId, TestItem updatedTest, {File? imageFile}) async {
    try {
      await updateTest(testId, updatedTest, imageFile: imageFile);
      
      final currentState = state.currentOperation;
      if (currentState.status == TestUploadOperationStatus.completed && 
          currentState.type == TestUploadOperationType.updateTest) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error updating existing test: $e');
      return false;
    }
  }

  Future<bool> deleteExistingTest(String testId) async {
    try {
      await deleteTest(testId);
      
      final currentState = state.currentOperation;
      if (currentState.status == TestUploadOperationStatus.completed && 
          currentState.type == TestUploadOperationType.deleteTest) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error deleting test: $e');
      return false;
    }
  }
  
  // Permission checking methods
  Future<bool> canUserEditTest(String testId) async {
    try {
      final UserEntity? user = _getCurrentUser();
      if (user == null) {
        debugPrint('No authenticated user for edit permission check');
        return false;
      }
      
      final result = await repository.hasEditPermission(testId, user.uid);
      return result.fold(
        onSuccess: (hasPermission) {
          debugPrint('Edit permission for test $testId: $hasPermission (user: ${user.uid})');
          return hasPermission;
        },
        onFailure: (_, __) {
          debugPrint('Error checking edit permission for test $testId');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteTest(String testId) async {
    return canUserEditTest(testId);
  }
  
  // Helper methods
  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }

  void _handleError(String message, TestUploadOperationType operationType, [String? testId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(TestUploadOperation(
      type: operationType,
      status: TestUploadOperationStatus.failed,
      message: message,
      testId: testId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != TestUploadOperationStatus.none) {
        emit(state.copyWithOperation(
          const TestUploadOperation(status: TestUploadOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing TestUploadCubit...');
    return super.close();
  }
}