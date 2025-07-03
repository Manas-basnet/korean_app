import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';

part 'book_upload_state.dart';

class BookUploadCubit extends Cubit<BookUploadState> {
  final BookUploadRepository repository;
  final AuthService authService;
  final AdminPermissionService adminService;
  
  final Stopwatch _operationStopwatch = Stopwatch();
  
  BookUploadCubit({
    required this.repository,
    required this.authService,
    required this.adminService,
  }) : super(const BookUploadInitial());

  /// Create book with optional image - atomic operation
  Future<void> createBook(BookItem book, {File? imageFile}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Create book operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: const BookUploadOperation(
          type: BookUploadOperationType.createBook,
          status: BookUploadOperationStatus.inProgress,
        ),
      ));

      final result = await repository.createBook(book, imageFile: imageFile);

      result.fold(
        onSuccess: (createdBook) {
          _operationStopwatch.stop();
          debugPrint('Book created successfully in ${_operationStopwatch.elapsedMilliseconds}ms: ${createdBook.title} with ID: ${createdBook.id}');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            createdBook: createdBook,
            currentOperation: const BookUploadOperation(
              type: BookUploadOperationType.createBook,
              status: BookUploadOperationStatus.completed,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Book creation failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(BookUploadOperation(
            type: BookUploadOperationType.createBook,
            status: BookUploadOperationStatus.failed,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error creating book after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to create book: $e', BookUploadOperationType.createBook);
    }
  }

  /// Update book with optional new image - atomic operation
  Future<void> updateBook(String bookId, BookItem updatedBook, {File? imageFile}) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Update book operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: BookUploadOperation(
          type: BookUploadOperationType.updateBook,
          status: BookUploadOperationStatus.inProgress,
          bookId: bookId,
        ),
      ));

      final result = await repository.updateBook(bookId, updatedBook, imageFile: imageFile);

      result.fold(
        onSuccess: (updatedBookResult) {
          _operationStopwatch.stop();
          debugPrint('Book updated successfully in ${_operationStopwatch.elapsedMilliseconds}ms: ${updatedBookResult.title}');
          
          emit(state.copyWith(
            isLoading: false,
            error: null,
            errorType: null,
            createdBook: updatedBookResult,
            currentOperation: BookUploadOperation(
              type: BookUploadOperationType.updateBook,
              status: BookUploadOperationStatus.completed,
              bookId: bookId,
            ),
          ));
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Book update failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(BookUploadOperation(
            type: BookUploadOperationType.updateBook,
            status: BookUploadOperationStatus.failed,
            bookId: bookId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error updating book after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to update book: $e', BookUploadOperationType.updateBook, bookId);
    }
  }

  /// Delete book and all associated files
  Future<void> deleteBook(String bookId) async {
    if (state.currentOperation.isInProgress) {
      debugPrint('Delete book operation already in progress, skipping...');
      return;
    }

    _operationStopwatch.reset();
    _operationStopwatch.start();

    try {
      emit(state.copyWith(
        isLoading: true,
        error: null,
        errorType: null,
        currentOperation: BookUploadOperation(
          type: BookUploadOperationType.deleteBook,
          status: BookUploadOperationStatus.inProgress,
          bookId: bookId,
        ),
      ));

      final result = await repository.deleteBook(bookId);

      result.fold(
        onSuccess: (success) {
          _operationStopwatch.stop();
          
          if (success) {
            debugPrint('Book deleted successfully in ${_operationStopwatch.elapsedMilliseconds}ms: $bookId');
            emit(state.copyWith(
              isLoading: false,
              error: null,
              errorType: null,
              currentOperation: BookUploadOperation(
                type: BookUploadOperationType.deleteBook,
                status: BookUploadOperationStatus.completed,
                bookId: bookId,
              ),
            ));
          } else {
            emit(state.copyWithBaseState(
              error: 'Failed to delete book',
              isLoading: false,
            ).copyWithOperation(BookUploadOperation(
              type: BookUploadOperationType.deleteBook,
              status: BookUploadOperationStatus.failed,
              bookId: bookId,
              message: 'Failed to delete book',
            )));
          }
          _clearOperationAfterDelay();
        },
        onFailure: (message, type) {
          _operationStopwatch.stop();
          debugPrint('Book deletion failed after ${_operationStopwatch.elapsedMilliseconds}ms: $message');
          
          emit(state.copyWithBaseState(
            error: message,
            errorType: type,
            isLoading: false,
          ).copyWithOperation(BookUploadOperation(
            type: BookUploadOperationType.deleteBook,
            status: BookUploadOperationStatus.failed,
            bookId: bookId,
            message: message,
          )));
          _clearOperationAfterDelay();
        },
      );
    } catch (e) {
      _operationStopwatch.stop();
      debugPrint('Error deleting book after ${_operationStopwatch.elapsedMilliseconds}ms: $e');
      _handleError('Failed to delete book: $e', BookUploadOperationType.deleteBook, bookId);
    }
  }

  // High-level helper methods for UI
  Future<bool> uploadNewBook(BookItem book, {File? imageFile}) async {
    try {
      await createBook(book, imageFile: imageFile);
      
      final currentState = state.currentOperation;
      if (currentState.status == BookUploadOperationStatus.completed && 
          currentState.type == BookUploadOperationType.createBook) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error uploading new book: $e');
      return false;
    }
  }

  Future<bool> updateExistingBook(String bookId, BookItem updatedBook, {File? imageFile}) async {
    try {
      await updateBook(bookId, updatedBook, imageFile: imageFile);
      
      final currentState = state.currentOperation;
      if (currentState.status == BookUploadOperationStatus.completed && 
          currentState.type == BookUploadOperationType.updateBook) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error updating existing book: $e');
      return false;
    }
  }

  Future<bool> deleteExistingBook(String bookId) async {
    try {
      await deleteBook(bookId);
      
      final currentState = state.currentOperation;
      if (currentState.status == BookUploadOperationStatus.completed && 
          currentState.type == BookUploadOperationType.deleteBook) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error deleting book: $e');
      return false;
    }
  }
  
  // Permission checking methods
  Future<bool> canUserEditBook(String bookId) async {
    try {
      final UserEntity? user = _getCurrentUser();
      if (user == null) {
        debugPrint('No authenticated user for edit permission check');
        return false;
      }
      
      final result = await repository.hasEditPermission(bookId, user.uid);
      return result.fold(
        onSuccess: (hasPermission) {
          debugPrint('Edit permission for book $bookId: $hasPermission (user: ${user.uid})');
          return hasPermission;
        },
        onFailure: (_, __) {
          debugPrint('Error checking edit permission for book $bookId');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Error checking edit permission: $e');
      return false;
    }
  }
  
  Future<bool> canUserDeleteBook(String bookId) async {
    return canUserEditBook(bookId);
  }
  
  // Helper methods
  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }

  void _handleError(String message, BookUploadOperationType operationType, [String? bookId]) {
    emit(state.copyWithBaseState(
      error: message,
      isLoading: false,
    ).copyWithOperation(BookUploadOperation(
      type: operationType,
      status: BookUploadOperationStatus.failed,
      message: message,
      bookId: bookId,
    )));
    
    _clearOperationAfterDelay();
  }

  void _clearOperationAfterDelay() {
    Timer(const Duration(seconds: 3), () {
      if (state.currentOperation.status != BookUploadOperationStatus.none) {
        emit(state.copyWithOperation(
          const BookUploadOperation(status: BookUploadOperationStatus.none)
        ));
      }
    });
  }

  @override
  Future<void> close() {
    debugPrint('Closing BookUploadCubit...');
    return super.close();
  }
}