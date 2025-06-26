import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/features/book_upload/data/models/chapter.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/enums/book_upload_type.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource.dart';
import 'package:korean_language_app/shared/models/book_item.dart';

class FirestoreBookUploadDataSource implements BookUploadRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final Map<CourseCategory, String> collectionMap = {
    CourseCategory.korean: 'korean_books',
    CourseCategory.nepali: 'nepali_books',
    CourseCategory.test: 'test_books',
    CourseCategory.global: 'global_books',
  };
  
  FirestoreBookUploadDataSource({
    required this.firestore,
    required this.storage,
  });

  String _getCollectionForCategory(CourseCategory category) {
    return collectionMap[category] ?? 'korean_books';
  }

  @override
  Future<BookItem> uploadBook(BookItem book, File pdfFile, {File? coverImageFile}) async {
    if (book.title.isEmpty || book.description.isEmpty) {
      throw Exception('Book title and description cannot be empty');
    }
    
    final collection = _getCollectionForCategory(book.courseCategory);
    final docRef = book.id.isEmpty 
        ? firestore.collection(collection).doc() 
        : firestore.collection(collection).doc(book.id);
    
    final bookId = docRef.id;
    var finalBook = book.copyWith(id: bookId);
    
    String? uploadedPdfPath;
    String? uploadedImagePath;
    
    try {
      final pdfResult = await _uploadPdfFile(bookId, pdfFile);
      uploadedPdfPath = pdfResult['storagePath'];
      finalBook = finalBook.copyWith(
        pdfUrl: pdfResult['url'],
        pdfPath: pdfResult['storagePath'],
      );
      
      if (coverImageFile != null) {
        try {
          final imageResult = await _uploadCoverImage(bookId, coverImageFile);
          uploadedImagePath = imageResult['storagePath'];
          finalBook = finalBook.copyWith(
            bookImage: imageResult['url'],
            bookImagePath: imageResult['storagePath'],
          );
        } catch (e) {
          await _deleteFileByPath(uploadedPdfPath!);
          throw Exception('Failed to upload cover image: $e');
        }
      }
      
      final bookData = finalBook.toJson();
      bookData['titleLowerCase'] = finalBook.title.toLowerCase();
      bookData['descriptionLowerCase'] = finalBook.description.toLowerCase();
      bookData['createdAt'] = FieldValue.serverTimestamp();
      bookData['updatedAt'] = FieldValue.serverTimestamp();
      
      await docRef.set(bookData);
      
      return finalBook.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
    } catch (e) {
      if (uploadedPdfPath != null) {
        await _deleteFileByPath(uploadedPdfPath);
      }
      if (uploadedImagePath != null) {
        await _deleteFileByPath(uploadedImagePath);
      }
      
      if (kDebugMode) {
        print('Error uploading book: $e');
      }
      rethrow;
    }
  }

  @override
  Future<BookItem> uploadBookWithChapters(
    BookItem book, 
    List<ChapterUploadData> chaptersData, 
    {File? coverImageFile}
  ) async {
    if (book.title.isEmpty || book.description.isEmpty) {
      throw Exception('Book title and description cannot be empty');
    }
    
    if (chaptersData.isEmpty) {
      throw Exception('At least one chapter is required');
    }
    
    final collection = _getCollectionForCategory(book.courseCategory);
    final docRef = book.id.isEmpty 
        ? firestore.collection(collection).doc() 
        : firestore.collection(collection).doc(book.id);
    
    final bookId = docRef.id;
    var finalBook = book.copyWith(
      id: bookId,
      uploadType: BookUploadType.chapterWise,
      chaptersCount: chaptersData.length,
    );
    
    String? uploadedImagePath;
    List<String> uploadedChapterPaths = [];
    List<Chapter> processedChapters = [];
    
    try {
      // Upload cover image if provided
      if (coverImageFile != null) {
        final imageResult = await _uploadCoverImage(bookId, coverImageFile);
        uploadedImagePath = imageResult['storagePath'];
        finalBook = finalBook.copyWith(
          bookImage: imageResult['url'],
          bookImagePath: imageResult['storagePath'],
        );
      }
      
      // Upload all chapter PDFs
      for (int i = 0; i < chaptersData.length; i++) {
        final chapterData = chaptersData[i];
        try {
          final chapterResult = await _uploadChapterPdf(bookId, i + 1, chapterData.pdfFile);
          uploadedChapterPaths.add(chapterResult['storagePath']!);
          
          final chapter = Chapter(
            id: '${bookId}_chapter_${i + 1}',
            title: chapterData.title,
            description: chapterData.description,
            pdfUrl: chapterResult['url'],
            pdfPath: chapterResult['storagePath'],
            order: chapterData.order,
            duration: chapterData.duration,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          processedChapters.add(chapter);
        } catch (e) {
          // Clean up uploaded files on failure
          if (uploadedImagePath != null) {
            await _deleteFileByPath(uploadedImagePath);
          }
          for (final path in uploadedChapterPaths) {
            await _deleteFileByPath(path);
          }
          throw Exception('Failed to upload chapter ${i + 1}: $e');
        }
      }
      
      // Update book with chapters
      finalBook = finalBook.copyWith(chapters: processedChapters);
      
      // Save to Firestore
      final bookData = finalBook.toJson();
      bookData['titleLowerCase'] = finalBook.title.toLowerCase();
      bookData['descriptionLowerCase'] = finalBook.description.toLowerCase();
      bookData['createdAt'] = FieldValue.serverTimestamp();
      bookData['updatedAt'] = FieldValue.serverTimestamp();
      
      await docRef.set(bookData);
      
      return finalBook.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
    } catch (e) {
      // Clean up all uploaded files on failure
      if (uploadedImagePath != null) {
        await _deleteFileByPath(uploadedImagePath);
      }
      for (final path in uploadedChapterPaths) {
        await _deleteFileByPath(path);
      }
      
      if (kDebugMode) {
        print('Error uploading book with chapters: $e');
      }
      rethrow;
    }
  }

  @override
  Future<BookItem> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? coverImageFile}) async {
    try {
      final collection = _getCollectionForCategory(updatedBook.courseCategory);
      final docRef = firestore.collection(collection).doc(bookId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Book not found');
      }
      
      final existingData = docSnapshot.data() as Map<String, dynamic>;
      var finalBook = updatedBook;
      
      String? newPdfPath;
      String? newImagePath;
      String? oldPdfPath = existingData['pdfPath'] as String?;
      String? oldImagePath = existingData['bookImagePath'] as String?;
      
      try {
        if (pdfFile != null) {
          final pdfResult = await _uploadPdfFile(bookId, pdfFile);
          newPdfPath = pdfResult['storagePath'];
          finalBook = finalBook.copyWith(
            pdfUrl: pdfResult['url'],
            pdfPath: pdfResult['storagePath'],
          );
        }
        
        if (coverImageFile != null) {
          try {
            final imageResult = await _uploadCoverImage(bookId, coverImageFile);
            newImagePath = imageResult['storagePath'];
            finalBook = finalBook.copyWith(
              bookImage: imageResult['url'],
              bookImagePath: imageResult['storagePath'],
            );
          } catch (e) {
            if (newPdfPath != null) {
              await _deleteFileByPath(newPdfPath);
            }
            throw Exception('Failed to upload new cover image: $e');
          }
        }
        
        final updateData = finalBook.toJson();
        updateData['titleLowerCase'] = finalBook.title.toLowerCase();
        updateData['descriptionLowerCase'] = finalBook.description.toLowerCase();
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        
        await docRef.update(updateData);
        
        if (newPdfPath != null && oldPdfPath != null && oldPdfPath != newPdfPath) {
          await _deleteFileByPath(oldPdfPath);
        }
        if (newImagePath != null && oldImagePath != null && oldImagePath != newImagePath) {
          await _deleteFileByPath(oldImagePath);
        }
        
        return finalBook.copyWith(updatedAt: DateTime.now());
        
      } catch (e) {
        if (newPdfPath != null) {
          await _deleteFileByPath(newPdfPath);
        }
        if (newImagePath != null) {
          await _deleteFileByPath(newImagePath);
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating book: $e');
      }
      rethrow;
    }
  }

  @override
  Future<BookItem> updateBookWithChapters(
    String bookId, 
    BookItem updatedBook, 
    List<ChapterUploadData>? chaptersData, 
    {File? coverImageFile}
  ) async {
    try {
      final collection = _getCollectionForCategory(updatedBook.courseCategory);
      final docRef = firestore.collection(collection).doc(bookId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Book not found');
      }
      
      final existingData = docSnapshot.data() as Map<String, dynamic>;
      var finalBook = updatedBook;
      
      String? newImagePath;
      String? oldImagePath = existingData['bookImagePath'] as String?;
      List<String> newChapterPaths = [];
      List<String> oldChapterPaths = [];
      List<Chapter> processedChapters = List.from(updatedBook.chapters);
      
      // Extract old chapter paths for cleanup
      if (existingData['chapters'] is List) {
        final oldChapters = (existingData['chapters'] as List)
            .map((chapterJson) => Chapter.fromJson(chapterJson))
            .toList();
        oldChapterPaths = oldChapters
            .where((chapter) => chapter.pdfPath != null)
            .map((chapter) => chapter.pdfPath!)
            .toList();
      }
      
      try {
        // Upload new cover image if provided
        if (coverImageFile != null) {
          final imageResult = await _uploadCoverImage(bookId, coverImageFile);
          newImagePath = imageResult['storagePath'];
          finalBook = finalBook.copyWith(
            bookImage: imageResult['url'],
            bookImagePath: imageResult['storagePath'],
          );
        }
        
        // Upload new chapters if provided
        if (chaptersData != null && chaptersData.isNotEmpty) {
          processedChapters.clear();
          
          for (int i = 0; i < chaptersData.length; i++) {
            final chapterData = chaptersData[i];
            try {
              final chapterResult = await _uploadChapterPdf(bookId, i + 1, chapterData.pdfFile);
              newChapterPaths.add(chapterResult['storagePath']!);
              
              final chapter = Chapter(
                id: '${bookId}_chapter_${i + 1}',
                title: chapterData.title,
                description: chapterData.description,
                pdfUrl: chapterResult['url'],
                pdfPath: chapterResult['storagePath'],
                order: chapterData.order,
                duration: chapterData.duration,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              processedChapters.add(chapter);
            } catch (e) {
              // Clean up uploaded files on failure
              if (newImagePath != null) {
                await _deleteFileByPath(newImagePath);
              }
              for (final path in newChapterPaths) {
                await _deleteFileByPath(path);
              }
              throw Exception('Failed to upload chapter ${i + 1}: $e');
            }
          }
          
          finalBook = finalBook.copyWith(
            chapters: processedChapters,
            chaptersCount: processedChapters.length,
          );
        }
        
        // Update document
        final updateData = finalBook.toJson();
        updateData['titleLowerCase'] = finalBook.title.toLowerCase();
        updateData['descriptionLowerCase'] = finalBook.description.toLowerCase();
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        
        await docRef.update(updateData);
        
        // Clean up old files after successful update
        if (newImagePath != null && oldImagePath != null && oldImagePath != newImagePath) {
          await _deleteFileByPath(oldImagePath);
        }
        
        if (newChapterPaths.isNotEmpty) {
          for (final oldPath in oldChapterPaths) {
            await _deleteFileByPath(oldPath);
          }
        }
        
        return finalBook.copyWith(updatedAt: DateTime.now());
        
      } catch (e) {
        // Clean up newly uploaded files on failure
        if (newImagePath != null) {
          await _deleteFileByPath(newImagePath);
        }
        for (final path in newChapterPaths) {
          await _deleteFileByPath(path);
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating book with chapters: $e');
      }
      rethrow;
    }
  }

  @override
  Future<bool> deleteBook(String bookId) async {
    try {
      for (var collection in collectionMap.values) {
        final docRef = firestore.collection(collection).doc(bookId);
        final docSnapshot = await docRef.get();
        
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          
          await _deleteAssociatedFiles(data);
          
          await docRef.delete();
          return true;
        }
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting book: $e');
      }
      return false;
    }
  }

  @override
  Future<List<BookItem>> searchBookById(String bookId) async {
    try {
      final results = <BookItem>[];
      
      for (var entry in collectionMap.entries) {
        final category = entry.key;
        final collection = entry.value;
        
        final docSnapshot = await firestore.collection(collection).doc(bookId).get();
        
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          data['id'] = docSnapshot.id;
          data['courseCategory'] = category.toString().split('.').last;
          
          results.add(BookItem.fromJson(data));
        }
      }
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        print('Error searching book by ID: $e');
      }
      return [];
    }
  }

  @override
  Future<BookItem?> getBookById(String bookId) async {
    try {
      final books = await searchBookById(bookId);
      return books.isNotEmpty ? books.first : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting book by ID: $e');
      }
      return null;
    }
  }

  Future<Map<String, String>> _uploadPdfFile(String bookId, File pdfFile) async {
    try {
      final storagePath = 'books/$bookId/book_pdf.pdf';
      final fileRef = storage.ref().child(storagePath);

      final uploadTask = await fileRef.putFile(
        pdfFile,
        SettableMetadata(contentType: 'application/pdf')
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded PDF');
      }
      
      return {
        'url': downloadUrl,
        'storagePath': storagePath
      };
    } catch (e) {
      throw Exception('PDF upload failed: $e');
    }
  }

  Future<Map<String, String>> _uploadChapterPdf(String bookId, int chapterNumber, File pdfFile) async {
    try {
      final storagePath = 'books/$bookId/chapters/chapter_$chapterNumber.pdf';
      final fileRef = storage.ref().child(storagePath);

      final uploadTask = await fileRef.putFile(
        pdfFile,
        SettableMetadata(contentType: 'application/pdf')
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded chapter PDF');
      }
      
      return {
        'url': downloadUrl,
        'storagePath': storagePath
      };
    } catch (e) {
      throw Exception('Chapter PDF upload failed: $e');
    }
  }
  
  Future<Map<String, String>> _uploadCoverImage(String bookId, File imageFile) async {
    try {
      final storagePath = 'books/$bookId/cover_image.jpg';
      final fileRef = storage.ref().child(storagePath);
      
      final uploadTask = await fileRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg')
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded cover image');
      }
      
      return {
        'url': downloadUrl,
        'storagePath': storagePath
      };
    } catch (e) {
      throw Exception('Cover image upload failed: $e');
    }
  }

  Future<void> _deleteFileByPath(String storagePath) async {
    try {
      if (storagePath.isNotEmpty) {
        final fileRef = storage.ref().child(storagePath);
        await fileRef.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to delete file at $storagePath: $e');
      }
    }
  }

  Future<void> _deleteAssociatedFiles(Map<String, dynamic> data) async {
    // Delete PDF by path if exists
    if (data.containsKey('pdfPath') && data['pdfPath'] != null) {
      await _deleteFileByPath(data['pdfPath'] as String);
    }
    
    // Delete cover image by path if exists
    if (data.containsKey('bookImagePath') && data['bookImagePath'] != null) {
      await _deleteFileByPath(data['bookImagePath'] as String);
    }
    
    // Delete chapter PDFs if exists
    if (data.containsKey('chapters') && data['chapters'] is List) {
      final chapters = (data['chapters'] as List)
          .map((chapterJson) => Chapter.fromJson(chapterJson))
          .toList();
      
      for (final chapter in chapters) {
        if (chapter.pdfPath != null && chapter.pdfPath!.isNotEmpty) {
          await _deleteFileByPath(chapter.pdfPath!);
        }
      }
    }
    
    // Fallback: delete by URL
    if (data.containsKey('pdfUrl') && data['pdfUrl'] != null) {
      try {
        final pdfRef = storage.refFromURL(data['pdfUrl'] as String);
        await pdfRef.delete();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to delete PDF by URL: $e');
        }
      }
    }
    
    if (data.containsKey('bookImage') && data['bookImage'] != null) {
      try {
        final imageRef = storage.refFromURL(data['bookImage'] as String);
        await imageRef.delete();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to delete cover image by URL: $e');
        }
      }
    }
  }
}