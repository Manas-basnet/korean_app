import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/image_picker_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/pdf_picker_usecase.dart';
import 'package:korean_language_app/shared/enums/file_upload_type.dart';
import 'package:korean_language_app/shared/models/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/features/auth/domain/entities/user.dart';
import 'package:korean_language_app/features/book_upload/domain/repositories/book_upload_repository.dart';

part 'file_upload_state.dart';

class FileUploadCubit extends Cubit<FileUploadState> {
  FileUploadCubit({
    required this.uploadRepository,
    required this.authService,
    required this.pickPDFUseCase,
    required this.pickImageUseCase
  }) : super(FileUploadInitial());

  final PickPDFUseCase pickPDFUseCase;
  final PickImageUseCase pickImageUseCase;
  final BookUploadRepository uploadRepository;
  final AuthService authService;
  
  
  Future<File?> pickPdfFile() async {
    emit(const FilePickerLoading(FileUploadType.pdf));
    
    try {
      final pickedFileResult = await pickPDFUseCase.execute(); 

      pickedFileResult.fold(
        onSuccess: (pickedFile) {
          var file = pickedFile.pdfFile;
          emit(FilePickerSuccess(
            file: file, 
            fileName: file.path.split('/').last, 
            fileType: FileUploadType.pdf
          ));
          return file;
        }, 
        onFailure: (message, type) {
          emit(FilePickerError(message, FileUploadType.pdf));
        }
      );

    } catch (e) {
      emit(FilePickerError('Could not select PDF file: $e', FileUploadType.pdf));
    }
    return null;
  }
  
  Future<File?> pickImageFile() async {
    emit(const FilePickerLoading(FileUploadType.image));
    
    try {

      final pickedFileResult = await pickImageUseCase.execute(); 
      pickedFileResult.fold(
        onSuccess: (pickedFile) {
          var file = pickedFile.file;
          emit(FilePickerSuccess(
            file: file, 
            fileName: file.path.split('/').last, 
            fileType: FileUploadType.image
          ));
          return file;
        }, 
        onFailure: (message, type) {
          emit(FilePickerError(message, FileUploadType.image));
        }
      );
    } catch (e) {
      emit(FilePickerError('Could not select image file: $e', FileUploadType.image));
    }
    return null;
  }
  
  Future<bool> uploadBook(BookItem book, File pdfFile, File? imageFile) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const FileUploadError('User not authenticated', FileUploadType.pdf));
        return false;
      }
      
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final String newBookId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final bookWithId = book.copyWith(
        id: newBookId,
        creatorUid: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      emit(const FileUploading(0.5, FileUploadType.pdf));
      
      final result = await uploadRepository.createBook(
        bookWithId, 
        pdfFile, 
        coverImageFile: imageFile,
      );
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to upload book', FileUploadType.pdf));
        return false;
      }
      
      final createdBook = result.data!;
      emit(FileUploadSuccess(createdBook.id, FileUploadType.pdf, book: createdBook));
      return true;
    } catch (e) {
      emit(FileUploadError('Upload failed: $e', FileUploadType.pdf));
      return false;
    }
  }

  Future<bool> uploadBookWithChapters(
    BookItem book, 
    List<ChapterUploadData> chapters, 
    File? imageFile
  ) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    if (chapters.isEmpty) {
      emit(const FileUploadError('No chapters provided', FileUploadType.pdf));
      return false;
    }
    
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const FileUploadError('User not authenticated', FileUploadType.pdf));
        return false;
      }
      
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final String newBookId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final bookWithId = book.copyWith(
        id: newBookId,
        creatorUid: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        chaptersCount: chapters.length,
      );
      
      emit(const FileUploading(0.3, FileUploadType.pdf));
      
      final result = await uploadRepository.createBookWithChapters(
        bookWithId,
        chapters,
        coverImageFile: imageFile,
      );
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to upload book with chapters', FileUploadType.pdf));
        return false;
      }
      
      final createdBook = result.data!;
      emit(FileUploadSuccess(createdBook.id, FileUploadType.pdf, book: createdBook));
      return true;
    } catch (e) {
      emit(FileUploadError('Upload failed: $e', FileUploadType.pdf));
      return false;
    }
  }
  
  Future<bool> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? imageFile}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const FileUploadError('User not authenticated', FileUploadType.pdf));
        return false;
      }
      
      final permissionResult = await uploadRepository.hasEditPermission(bookId, user.uid);
      if (permissionResult.isFailure || !(permissionResult.data ?? false)) {
        emit(const FileUploadError('You do not have permission to edit this book', FileUploadType.pdf));
        return false;
      }
      
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final updatedBookWithMeta = updatedBook.copyWith(
        updatedAt: DateTime.now(),
      );
      
      emit(const FileUploading(0.5, FileUploadType.pdf));
      
      final result = await uploadRepository.updateBook(
        bookId, 
        updatedBookWithMeta,
        pdfFile: pdfFile,
        coverImageFile: imageFile,
      );
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to update book', FileUploadType.pdf));
        return false;
      }
      
      final finalBook = result.data!;
      emit(FileUploadSuccess(bookId, FileUploadType.pdf, book: finalBook));
      return true;
    } catch (e) {
      emit(FileUploadError('Update failed: $e', FileUploadType.pdf));
      return false;
    }
  }

  Future<bool> updateBookWithChapters(
    String bookId, 
    BookItem updatedBook, 
    List<ChapterUploadData>? chapters, 
    {File? imageFile}
  ) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const FileUploadError('User not authenticated', FileUploadType.pdf));
        return false;
      }
      
      final permissionResult = await uploadRepository.hasEditPermission(bookId, user.uid);
      if (permissionResult.isFailure || !(permissionResult.data ?? false)) {
        emit(const FileUploadError('You do not have permission to edit this book', FileUploadType.pdf));
        return false;
      }
      
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final updatedBookWithMeta = updatedBook.copyWith(
        updatedAt: DateTime.now(),
        chaptersCount: chapters?.length ?? updatedBook.chaptersCount,
      );
      
      emit(const FileUploading(0.5, FileUploadType.pdf));
      
      final result = await uploadRepository.updateBookWithChapters(
        bookId,
        updatedBookWithMeta,
        chapters,
        coverImageFile: imageFile,
      );
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to update book with chapters', FileUploadType.pdf));
        return false;
      }
      
      final finalBook = result.data!;
      emit(FileUploadSuccess(bookId, FileUploadType.pdf, book: finalBook));
      return true;
    } catch (e) {
      emit(FileUploadError('Update failed: $e', FileUploadType.pdf));
      return false;
    }
  }
  
  Future<bool> deleteBook(String bookId) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    try {
      final user = _getCurrentUser();
      if (user == null) {
        emit(const FileUploadError('User not authenticated', FileUploadType.pdf));
        return false;
      }
      
      final permissionResult = await uploadRepository.hasDeletePermission(bookId, user.uid);
      if (permissionResult.isFailure || !(permissionResult.data ?? false)) {
        emit(const FileUploadError('You do not have permission to delete this book', FileUploadType.pdf));
        return false;
      }
      
      emit(FileDeleting(bookId));
      final deleteResult = await uploadRepository.deleteBook(bookId);
      
      if (deleteResult.isFailure) {
        emit(FileDeletionError(deleteResult.error ?? 'Failed to delete book', bookId));
        return false;
      }
      
      emit(FileDeletionSuccess(bookId));
      return true;
    } catch (e) {
      emit(FileDeletionError('Delete failed: $e', bookId));
      return false;
    }
  }
  
  UserEntity? _getCurrentUser() {
    return authService.getCurrentUser();
  }
  
  void resetState() {
    emit(FileUploadInitial());
  }
  
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}