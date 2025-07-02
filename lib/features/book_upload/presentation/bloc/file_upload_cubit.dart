import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/create_book_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/create_book_with_chapters_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/delete_book_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/image_picker_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/pdf_picker_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/update_book_usecase.dart';
import 'package:korean_language_app/features/book_upload/domain/usecases/update_book_with_chapters_usecase.dart';
import 'package:korean_language_app/shared/enums/file_upload_type.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:file_picker/file_picker.dart';

part 'file_upload_state.dart';

class FileUploadCubit extends Cubit<FileUploadState> {
  FileUploadCubit({
    required this.pickPDFUseCase,
    required this.pickImageUseCase,
    required this.createBookUseCase,
    required this.createBookWithChaptersUseCase,
    required this.updateBookUseCase,
    required this.updateBookWithChaptersUseCase,
    required this.deleteBookUseCase,
  }) : super(FileUploadInitial());

  final PickPDFUseCase pickPDFUseCase;
  final PickImageUseCase pickImageUseCase;
  final CreateBookUseCase createBookUseCase;
  final CreateBookWithChaptersUseCase createBookWithChaptersUseCase;
  final UpdateBookUseCase updateBookUseCase;
  final UpdateBookWithChaptersUseCase updateBookWithChaptersUseCase;
  final DeleteBookUseCase deleteBookUseCase;

  Future<File?> pickPdfFile() async {
    emit(const FilePickerLoading(FileUploadType.pdf));
    
    try {
      final pickedFileResult = await pickPDFUseCase.execute(); 

      return pickedFileResult.fold(
        onSuccess: (pickedFile) {
          final file = pickedFile.pdfFile;
          emit(FilePickerSuccess(
            file: file, 
            fileName: file.path.split('/').last, 
            fileType: FileUploadType.pdf
          ));
          return file;
        }, 
        onFailure: (message, type) {
          emit(FilePickerError(message, FileUploadType.pdf));
          return null;
        }
      );
    } catch (e) {
      emit(FilePickerError('Could not select PDF file: $e', FileUploadType.pdf));
      return null;
    }
  }

  Future<File?> pickImageFile() async {
    emit(const FilePickerLoading(FileUploadType.image));
    
    try {
      final pickedFileResult = await pickImageUseCase.execute(); 
      
      return pickedFileResult.fold(
        onSuccess: (pickedFile) {
          final file = pickedFile.file;
          emit(FilePickerSuccess(
            file: file, 
            fileName: file.path.split('/').last, 
            fileType: FileUploadType.image
          ));
          return file;
        }, 
        onFailure: (message, type) {
          emit(FilePickerError(message, FileUploadType.image));
          return null;
        }
      );
    } catch (e) {
      emit(FilePickerError('Could not select image file: $e', FileUploadType.image));
      return null;
    }
  }

  Future<File?> pickAudioFile() async {
    emit(const FilePickerLoading(FileUploadType.audio));
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final file = File(result.files.first.path!);
        
        if (await _isAudioValid(file)) {
          emit(FilePickerSuccess(
            file: file,
            fileName: file.path.split('/').last,
            fileType: FileUploadType.audio,
          ));
          return file;
        } else {
          emit(const FilePickerError('The selected audio file is invalid or too large.', FileUploadType.audio));
          return null;
        }
      } else {
        emit(const FilePickerError('No audio file selected', FileUploadType.audio));
        return null;
      }
    } catch (e) {
      emit(FilePickerError('Could not select audio file: $e', FileUploadType.audio));
      return null;
    }
  }

  Future<bool> _isAudioValid(File audioFile) async {
    try {
      final fileSize = await audioFile.length();
      return fileSize <= 50 * 1024 * 1024 && fileSize >= 100;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> uploadBook(BookItem book, File pdfFile, File? imageFile, {List<AudioTrackUploadData>? audioTracks}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    try {
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final params = CreateBookParams(
        book: book,
        pdfFile: pdfFile,
        coverImageFile: imageFile,
        audioTracks: audioTracks,
      );
      
      emit(const FileUploading(0.5, FileUploadType.pdf));
      
      final result = await createBookUseCase.execute(params);
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to upload book', FileUploadType.pdf));
        return false;
      }
      
      final createdBook = result.data!;
      emit(const FileUploading(1.0, FileUploadType.pdf));
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
    
    try {
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final params = CreateBookWithChaptersParams(
        book: book,
        chapters: chapters,
        coverImageFile: imageFile,
      );
      
      emit(const FileUploading(0.3, FileUploadType.pdf));
      
      final result = await createBookWithChaptersUseCase.execute(params);
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to upload book with chapters', FileUploadType.pdf));
        return false;
      }
      
      final createdBook = result.data!;
      emit(const FileUploading(1.0, FileUploadType.pdf));
      emit(FileUploadSuccess(createdBook.id, FileUploadType.pdf, book: createdBook));
      return true;
    } catch (e) {
      emit(FileUploadError('Upload failed: $e', FileUploadType.pdf));
      return false;
    }
  }
  
  Future<bool> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? imageFile, List<AudioTrackUploadData>? audioTracks}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      emit(const FileUploadError('No internet connection', FileUploadType.pdf));
      return false;
    }
    
    try {
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final params = UpdateBookParams(
        bookId: bookId,
        updatedBook: updatedBook,
        pdfFile: pdfFile,
        coverImageFile: imageFile,
        audioTracks: audioTracks,
      );
      
      emit(const FileUploading(0.5, FileUploadType.pdf));
      
      final result = await updateBookUseCase.execute(params);
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to update book', FileUploadType.pdf));
        return false;
      }
      
      final finalBook = result.data!;
      emit(const FileUploading(1.0, FileUploadType.pdf));
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
      emit(const FileUploading(0.1, FileUploadType.pdf));
      
      final params = UpdateBookWithChaptersParams(
        bookId: bookId,
        updatedBook: updatedBook,
        chapters: chapters,
        coverImageFile: imageFile,
      );
      
      emit(const FileUploading(0.5, FileUploadType.pdf));
      
      final result = await updateBookWithChaptersUseCase.execute(params);
      
      if (result.isFailure) {
        emit(FileUploadError(result.error ?? 'Failed to update book with chapters', FileUploadType.pdf));
        return false;
      }
      
      final finalBook = result.data!;
      emit(const FileUploading(1.0, FileUploadType.pdf));
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
      emit(FileDeleting(bookId));
      
      final params = DeleteBookParams(bookId: bookId);
      final deleteResult = await deleteBookUseCase.execute(params);
      
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
  
  void resetState() {
    emit(FileUploadInitial());
  }
  
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}