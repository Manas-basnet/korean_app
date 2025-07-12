import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabulary_upload/domain/repositories/vocabulary_upload_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

part 'vocabulary_upload_state.dart';

class VocabularyUploadCubit extends Cubit<VocabularyUploadState> {
  final VocabularyUploadRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  final Stopwatch _operationStopwatch = Stopwatch();
  
  VocabularyUploadCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
  }) : super(const VocabularyUploadInitial());

  Future<void> createVocabulary(VocabularyItem vocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Create vocabulary operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const VocabularyUploadOperation(
          type: VocabularyUploadOperationType.createVocabulary,
          status: VocabularyUploadOperationStatus.inProgress,
        ),
      ));

      final result = await repository.createVocabulary(vocabulary, imageFile: imageFile, pdfFiles: pdfFiles);

      result.fold(
        onSuccess: (createdVocabulary) {
          _operationStopwatch.stop();
          debugPrint('Vocabulary created successfully in ${_operationStopwatch.elapsedMilliseconds}ms: ${createdVocabulary.title} with ID: ${createdVocabulary.id}');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            createdVocabulary: createdVocabulary,
            currentOperation: const VocabularyUploadOperation(
              type: VocabularyUploadOperationType.createVocabulary,
              status: VocabularyUploadOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Vocabulary creation failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(VocabularyUploadOperation(
            type: VocabularyUploadOperationType.createVocabulary,
            status: VocabularyUploadOperationStatus.failed,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error creating vocabulary after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to create vocabulary: $e', VocabularyUploadOperationType.createVocabulary);
    }
  }

  Future<void> updateVocabulary(String vocabularyId, VocabularyItem updatedVocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Update vocabulary operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: VocabularyUploadOperation(
          type: VocabularyUploadOperationType.updateVocabulary,
          status: VocabularyUploadOperationStatus.inProgress,
          vocabularyId: vocabularyId,
        ),
      ));

      final result = await repository.updateVocabulary(vocabularyId, updatedVocabulary, imageFile: imageFile, pdfFiles: pdfFiles);

      result.fold(
        onSuccess: (updatedVocabularyResult) {
          _operationStopwatch.stop();
          debugPrint('Vocabulary updated successfully in ${_operationStopwatch.elapsedMilliseconds}ms: ${updatedVocabularyResult.title}');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            createdVocabulary: updatedVocabularyResult,
            currentOperation: VocabularyUploadOperation(
              type: VocabularyUploadOperationType.updateVocabulary,
              status: VocabularyUploadOperationStatus.completed,
              vocabularyId: vocabularyId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Vocabulary update failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(VocabularyUploadOperation(
            type: VocabularyUploadOperationType.updateVocabulary,
            status: VocabularyUploadOperationStatus.failed,
            vocabularyId: vocabularyId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error updating vocabulary after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to update vocabulary: $e', VocabularyUploadOperationType.updateVocabulary, vocabularyId);
    }
  }

  Future<void> deleteVocabulary(String vocabularyId) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Delete vocabulary operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: VocabularyUploadOperation(
          type: VocabularyUploadOperationType.deleteVocabulary,
          status: VocabularyUploadOperationStatus.inProgress,
          vocabularyId: vocabularyId,
        ),
      ));

      final result = await repository.deleteVocabulary(vocabularyId);

      result.fold(
        onSuccess: (success) {
          _operationStopwatch.stop();
          
          if (success) {
            debugPrint('Vocabulary deleted successfully in ${_operationStopwatch.elapsedMilliseconds}ms: $vocabularyId');
            emit(state.copyWith(
              isLoading: false,
              error: null,
              errorType: null,
              currentOperation: VocabularyUploadOperation(
                type: VocabularyUploadOperationType.deleteVocabulary,
                status: VocabularyUploadOperationStatus.completed,
                vocabularyId: vocabularyId,
              ),
            ));
          } else {
            emit(state.copyWithBaseState(
              error: 'Failed to delete vocabulary',
              isLoading: false,
            ).copyWithOperation(VocabularyUploadOperation(
              type: VocabularyUploadOperationType.deleteVocabulary,
              status: VocabularyUploadOperationStatus.failed,
              vocabularyId: vocabularyId,
              message: 'Failed to delete vocabulary',
            )));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Vocabulary deletion failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(VocabularyUploadOperation(
            type: VocabularyUploadOperationType.deleteVocabulary,
            status: VocabularyUploadOperationStatus.failed,
            vocabularyId: vocabularyId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error deleting vocabulary after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to delete vocabulary: $e', VocabularyUploadOperationType.deleteVocabulary, vocabularyId);
    }
  }

  Future<bool> uploadNewVocabulary(VocabularyItem vocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    try {
      await createVocabulary(vocabulary, imageFile: imageFile, pdfFiles: pdfFiles);
      
      final currentState = state.currentOperation;
      if (currentState.status == VocabularyUploadOperationStatus.completed && 
          currentState.type == VocabularyUploadOperationType.createVocabulary) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error uploading new vocabulary: $e');
      return false;
    }
  }

  Future<bool> updateExistingVocabulary(String vocabularyId, VocabularyItem updatedVocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    try {
      await updateVocabulary(vocabularyId, updatedVocabulary, imageFile: imageFile, pdfFiles: pdfFiles);
      
      final currentState = state.currentOperation;
      if (currentState.status == VocabularyUploadOperationStatus.completed && 
          currentState.type == VocabularyUploadOperationType.updateVocabulary) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error updating existing vocabulary: $e');
      return false;
    }
  }

  Future<bool> deleteExistingVocabulary(String vocabularyId) async {
    try {
      await deleteVocabulary(vocabularyId);
      
      final currentState = state.currentOperation;
      if (currentState.status == VocabularyUploadOperationStatus.completed && 
          currentState.type == VocabularyUploadOperationType.deleteVocabulary) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error deleting vocabulary: $e');
      return false;
    }
  }
  
  Future<bool> canUserEditVocabulary(String vocabularyId) async {
    try {
      final UserEntity? user = _getCurrentUser();
      if (user == null) {
        debugPrint('No authenticated user for edit permission check');
        return false;
      }
      
      final result = await repository.hasEditPermission(vocabularyId, user.uid);
      return result.fold(
        onSuccess: (hasPermission) {
          debugPrint('Edit permission for vocabulary $vocabularyId: $hasPermission (user: ${user.uid})');
          return hasPermission;
        },
        onFailure: (_, __) {
          debugPrint('Error checking edit permission for vocabulary $vocabularyId');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteVocabulary(String vocabularyId) async {
    return canUserEditVocabulary(vocabularyId);
  }
  
  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }

  void _handleError(String message, VocabularyUploadOperationType operationType, [String? vocabularyId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(VocabularyUploadOperation(
      type: operationType,
      status: VocabularyUploadOperationStatus.failed,
      message: message,
      vocabularyId: vocabularyId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != VocabularyUploadOperationStatus.none) {
        emit(state.copyWithOperation(
          const VocabularyUploadOperation(status: VocabularyUploadOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing VocabularyUploadCubit...');
    return super.close();
  }
}