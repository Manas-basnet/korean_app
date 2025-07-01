import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/features/book_upload/data/models/chapter.dart';
import 'package:korean_language_app/features/book_upload/domain/entities/chapter_upload_data.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';
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
  Future<BookItem> uploadBook(BookItem book, File pdfFile, {File? coverImageFile, List<AudioTrackUploadData>? audioTracks}) async {
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
    List<String> uploadedAudioPaths = [];
    List<AudioTrack> processedAudioTracks = [];
    
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

      if (audioTracks != null && audioTracks.isNotEmpty) {
        try {
          for (int i = 0; i < audioTracks.length; i++) {
            final audioTrackData = audioTracks[i];
            final audioResult = await _uploadBookAudio(bookId, i + 1, audioTrackData.audioFile);
            uploadedAudioPaths.add(audioResult['storagePath']!);
            
            final audioTrack = AudioTrack(
              id: '${bookId}_audio_${i + 1}',
              name: audioTrackData.name,
              audioUrl: audioResult['url'],
              audioPath: audioResult['storagePath'],
              order: audioTrackData.order,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            processedAudioTracks.add(audioTrack);
          }
          
          finalBook = finalBook.copyWith(audioTracks: processedAudioTracks);
        } catch (e) {
          await _deleteFileByPath(uploadedPdfPath!);
          if (uploadedImagePath != null) {
            await _deleteFileByPath(uploadedImagePath);
          }
          for (final path in uploadedAudioPaths) {
            await _deleteFileByPath(path);
          }
          throw Exception('Failed to upload audio tracks: $e');
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
      for (final path in uploadedAudioPaths) {
        await _deleteFileByPath(path);
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
    List<String> uploadedAudioPaths = [];
    List<Chapter> processedChapters = [];
    
    try {
      if (coverImageFile != null) {
        final imageResult = await _uploadCoverImage(bookId, coverImageFile);
        uploadedImagePath = imageResult['storagePath'];
        finalBook = finalBook.copyWith(
          bookImage: imageResult['url'],
          bookImagePath: imageResult['storagePath'],
        );
      }
      
      for (int i = 0; i < chaptersData.length; i++) {
        final chapterData = chaptersData[i];
        try {
          final chapterResult = await _uploadChapterPdf(bookId, i + 1, chapterData.pdfFile!);
          uploadedChapterPaths.add(chapterResult['storagePath']!);
          
          List<AudioTrack> chapterAudioTracks = [];
          
          if (chapterData.audioTracks.isNotEmpty) {
            for (int j = 0; j < chapterData.audioTracks.length; j++) {
              final audioTrackData = chapterData.audioTracks[j];
              final audioResult = await _uploadChapterAudio(bookId, i + 1, j + 1, audioTrackData.audioFile);
              uploadedAudioPaths.add(audioResult['storagePath']!);
              
              final audioTrack = AudioTrack(
                id: '${bookId}_chapter_${i + 1}_audio_${j + 1}',
                name: audioTrackData.name,
                audioUrl: audioResult['url'],
                audioPath: audioResult['storagePath'],
                order: audioTrackData.order,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              chapterAudioTracks.add(audioTrack);
            }
          }
          
          final chapter = Chapter(
            id: '${bookId}_chapter_${i + 1}',
            title: chapterData.title,
            description: chapterData.description,
            pdfUrl: chapterResult['url'],
            pdfPath: chapterResult['storagePath'],
            audioTracks: chapterAudioTracks,
            order: chapterData.order,
            duration: chapterData.duration,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          processedChapters.add(chapter);
        } catch (e) {
          if (uploadedImagePath != null) {
            await _deleteFileByPath(uploadedImagePath);
          }
          for (final path in uploadedChapterPaths) {
            await _deleteFileByPath(path);
          }
          for (final path in uploadedAudioPaths) {
            await _deleteFileByPath(path);
          }
          throw Exception('Failed to upload chapter ${i + 1}: $e');
        }
      }
      
      finalBook = finalBook.copyWith(chapters: processedChapters);
      
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
      if (uploadedImagePath != null) {
        await _deleteFileByPath(uploadedImagePath);
      }
      for (final path in uploadedChapterPaths) {
        await _deleteFileByPath(path);
      }
      for (final path in uploadedAudioPaths) {
        await _deleteFileByPath(path);
      }
      
      if (kDebugMode) {
        print('Error uploading book with chapters: $e');
      }
      rethrow;
    }
  }

  @override
  Future<BookItem> updateBook(String bookId, BookItem updatedBook, {File? pdfFile, File? coverImageFile, List<AudioTrackUploadData>? audioTracks}) async {
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
      List<String> newAudioPaths = [];
      String? oldPdfPath = existingData['pdfPath'] as String?;
      String? oldImagePath = existingData['bookImagePath'] as String?;
      List<String> oldAudioPathsToDelete = [];
      List<AudioTrack> processedAudioTracks = List.from(updatedBook.audioTracks);
      
      try {
        // Handle PDF update
        if (pdfFile != null) {
          final pdfResult = await _uploadPdfFile(bookId, pdfFile);
          newPdfPath = pdfResult['storagePath'];
          finalBook = finalBook.copyWith(
            pdfUrl: pdfResult['url'],
            pdfPath: pdfResult['storagePath'],
          );
        }
        
        // Handle cover image update
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

        // Handle audio tracks update - only if explicitly provided
        if (audioTracks != null) {
          try {
            // Mark old audio tracks for deletion ONLY if we're replacing them
            if (existingData['audioTracks'] is List) {
              final existingAudioTracks = (existingData['audioTracks'] as List)
                  .map((trackJson) => AudioTrack.fromJson(trackJson))
                  .toList();
              for (final track in existingAudioTracks) {
                if (track.audioPath != null && track.audioPath!.isNotEmpty) {
                  oldAudioPathsToDelete.add(track.audioPath!);
                }
              }
            }
            
            processedAudioTracks.clear();
            
            for (int i = 0; i < audioTracks.length; i++) {
              final audioTrackData = audioTracks[i];
              final audioResult = await _uploadBookAudio(bookId, i + 1, audioTrackData.audioFile);
              newAudioPaths.add(audioResult['storagePath']!);
              
              final audioTrack = AudioTrack(
                id: '${bookId}_audio_${i + 1}',
                name: audioTrackData.name,
                audioUrl: audioResult['url'],
                audioPath: audioResult['storagePath'],
                order: audioTrackData.order,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              processedAudioTracks.add(audioTrack);
            }
            
            finalBook = finalBook.copyWith(audioTracks: processedAudioTracks);
          } catch (e) {
            // Clean up on audio upload failure
            if (newPdfPath != null) {
              await _deleteFileByPath(newPdfPath);
            }
            if (newImagePath != null) {
              await _deleteFileByPath(newImagePath);
            }
            for (final path in newAudioPaths) {
              await _deleteFileByPath(path);
            }
            throw Exception('Failed to upload new audio tracks: $e');
          }
        }
        
        // Update the document
        final updateData = finalBook.toJson();
        updateData['titleLowerCase'] = finalBook.title.toLowerCase();
        updateData['descriptionLowerCase'] = finalBook.description.toLowerCase();
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        
        await docRef.update(updateData);
        
        // Clean up old files ONLY after successful update
        if (newPdfPath != null && oldPdfPath != null && oldPdfPath != newPdfPath) {
          await _deleteFileByPath(oldPdfPath);
        }
        if (newImagePath != null && oldImagePath != null && oldImagePath != newImagePath) {
          await _deleteFileByPath(oldImagePath);
        }
        for (final oldPath in oldAudioPathsToDelete) {
          await _deleteFileByPath(oldPath);
        }
        
        return finalBook.copyWith(updatedAt: DateTime.now());
        
      } catch (e) {
        // Clean up any newly uploaded files on failure
        if (newPdfPath != null) {
          await _deleteFileByPath(newPdfPath);
        }
        if (newImagePath != null) {
          await _deleteFileByPath(newImagePath);
        }
        for (final path in newAudioPaths) {
          await _deleteFileByPath(path);
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
      List<String> newAudioPaths = [];
      List<String> oldPathsToDelete = [];
      List<Chapter> processedChapters = List.from(updatedBook.chapters);
      
      try {
        if (coverImageFile != null) {
          final imageResult = await _uploadCoverImage(bookId, coverImageFile);
          newImagePath = imageResult['storagePath'];
          finalBook = finalBook.copyWith(
            bookImage: imageResult['url'],
            bookImagePath: imageResult['storagePath'],
          );
        }
        
        if (chaptersData != null && chaptersData.isNotEmpty) {
          final existingChapters = existingData['chapters'] as List?;
          Map<String, Chapter> existingChapterMap = {};
          
          if (existingChapters != null) {
            for (var chapterJson in existingChapters) {
              final chapter = Chapter.fromJson(chapterJson);
              existingChapterMap[chapter.id] = chapter;
            }
          }
          
          processedChapters.clear();
          
          for (int i = 0; i < chaptersData.length; i++) {
            final chapterData = chaptersData[i];
            
            if (chapterData.isNewOrModified && chapterData.pdfFile != null && chapterData.pdfFile!.existsSync()) {
              try {
                final chapterResult = await _uploadChapterPdf(bookId, i + 1, chapterData.pdfFile!);
                newChapterPaths.add(chapterResult['storagePath']!);
                
                List<AudioTrack> chapterAudioTracks = [];
                
                if (chapterData.audioTracks.isNotEmpty) {
                  for (int j = 0; j < chapterData.audioTracks.length; j++) {
                    final audioTrackData = chapterData.audioTracks[j];
                    final audioResult = await _uploadChapterAudio(bookId, i + 1, j + 1, audioTrackData.audioFile);
                    newAudioPaths.add(audioResult['storagePath']!);
                    
                    final audioTrack = AudioTrack(
                      id: '${bookId}_chapter_${i + 1}_audio_${j + 1}',
                      name: audioTrackData.name,
                      audioUrl: audioResult['url'],
                      audioPath: audioResult['storagePath'],
                      order: audioTrackData.order,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    
                    chapterAudioTracks.add(audioTrack);
                  }
                  
                  if (chapterData.existingId != null && existingChapterMap.containsKey(chapterData.existingId)) {
                    final existingChapter = existingChapterMap[chapterData.existingId!];
                    for (final track in existingChapter?.audioTracks ?? []) {
                      if (track.audioPath != null && track.audioPath!.isNotEmpty) {
                        oldPathsToDelete.add(track.audioPath!);
                      }
                    }
                  }
                } else {
                  if (chapterData.existingId != null && existingChapterMap.containsKey(chapterData.existingId)) {
                    final existingChapter = existingChapterMap[chapterData.existingId!];
                    chapterAudioTracks = List.from(existingChapter?.audioTracks ?? []);
                  }
                }
                
                if (chapterData.existingId != null && existingChapterMap.containsKey(chapterData.existingId)) {
                  final existingChapter = existingChapterMap[chapterData.existingId!];
                  if (existingChapter?.pdfPath != null && existingChapter!.pdfPath!.isNotEmpty) {
                    oldPathsToDelete.add(existingChapter.pdfPath!);
                  }
                }
                
                final chapter = Chapter(
                  id: chapterData.existingId ?? '${bookId}_chapter_${i + 1}',
                  title: chapterData.title,
                  description: chapterData.description,
                  pdfUrl: chapterResult['url'],
                  pdfPath: chapterResult['storagePath'],
                  audioTracks: chapterAudioTracks,
                  order: chapterData.order,
                  duration: chapterData.duration,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                processedChapters.add(chapter);
              } catch (e) {
                if (newImagePath != null) {
                  await _deleteFileByPath(newImagePath);
                }
                for (final path in newChapterPaths) {
                  await _deleteFileByPath(path);
                }
                for (final path in newAudioPaths) {
                  await _deleteFileByPath(path);
                }
                throw Exception('Failed to upload chapter ${i + 1}: $e');
              }
            } else {
              Chapter existingChapter;
              
              if (chapterData.existingId != null && existingChapterMap.containsKey(chapterData.existingId)) {
                existingChapter = existingChapterMap[chapterData.existingId!]!;
              } else {
                existingChapter = existingChapterMap.values.firstWhere(
                  (ch) => ch.order == chapterData.order,
                  orElse: () {
                    final chapters = existingChapterMap.values.toList();
                    if (chapters.length > i) {
                      return chapters[i];
                    }
                    throw Exception('Could not find existing chapter to update. Chapter may have been deleted.');
                  },
                );
              }
              
              List<AudioTrack> updatedAudioTracks = List.from(existingChapter.audioTracks);
              
              if (chapterData.audioTracks.isNotEmpty) {
                try {
                  for (final track in existingChapter.audioTracks) {
                    if (track.audioPath != null && track.audioPath!.isNotEmpty) {
                      oldPathsToDelete.add(track.audioPath!);
                    }
                  }
                  
                  updatedAudioTracks.clear();
                  
                  for (int j = 0; j < chapterData.audioTracks.length; j++) {
                    final audioTrackData = chapterData.audioTracks[j];
                    final audioResult = await _uploadChapterAudio(bookId, i + 1, j + 1, audioTrackData.audioFile);
                    newAudioPaths.add(audioResult['storagePath']!);
                    
                    final audioTrack = AudioTrack(
                      id: '${bookId}_chapter_${i + 1}_audio_${j + 1}',
                      name: audioTrackData.name,
                      audioUrl: audioResult['url'],
                      audioPath: audioResult['storagePath'],
                      order: audioTrackData.order,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    
                    updatedAudioTracks.add(audioTrack);
                  }
                } catch (e) {
                  if (newImagePath != null) {
                    await _deleteFileByPath(newImagePath);
                  }
                  for (final path in newChapterPaths) {
                    await _deleteFileByPath(path);
                  }
                  for (final path in newAudioPaths) {
                    await _deleteFileByPath(path);
                  }
                  throw Exception('Failed to upload audio for chapter ${i + 1}: $e');
                }
              }
              
              final updatedChapter = existingChapter.copyWith(
                title: chapterData.title,
                description: chapterData.description,
                duration: chapterData.duration,
                order: chapterData.order,
                audioTracks: updatedAudioTracks,
                updatedAt: DateTime.now(),
              );
              
              processedChapters.add(updatedChapter);
            }
          }
          
          finalBook = finalBook.copyWith(
            chapters: processedChapters,
            chaptersCount: processedChapters.length,
          );
        }
        
        final updateData = finalBook.toJson();
        updateData['titleLowerCase'] = finalBook.title.toLowerCase();
        updateData['descriptionLowerCase'] = finalBook.description.toLowerCase();
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        
        await docRef.update(updateData);
        
        if (newImagePath != null && oldImagePath != null && oldImagePath != newImagePath) {
          await _deleteFileByPath(oldImagePath);
        }
        
        for (final oldPath in oldPathsToDelete) {
          await _deleteFileByPath(oldPath);
        }
        
        return finalBook.copyWith(updatedAt: DateTime.now());
        
      } catch (e) {
        if (newImagePath != null) {
          await _deleteFileByPath(newImagePath);
        }
        for (final path in newChapterPaths) {
          await _deleteFileByPath(path);
        }
        for (final path in newAudioPaths) {
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
      if (!pdfFile.existsSync()) {
        throw Exception('PDF file does not exist at path: ${pdfFile.path}');
      }
      
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

  Future<Map<String, String>> _uploadBookAudio(String bookId, int audioTrackIndex, File audioFile) async {
    try {
      if (!audioFile.existsSync()) {
        throw Exception('Audio file does not exist at path: ${audioFile.path}');
      }
      
      final extension = _getAudioExtension(audioFile.path);
      final storagePath = 'books/$bookId/audio_tracks/track_$audioTrackIndex$extension';
      final fileRef = storage.ref().child(storagePath);

      final uploadTask = await fileRef.putFile(
        audioFile,
        SettableMetadata(contentType: _getAudioContentType(extension))
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded audio');
      }
      
      return {
        'url': downloadUrl,
        'storagePath': storagePath
      };
    } catch (e) {
      throw Exception('Audio upload failed: $e');
    }
  }

  Future<Map<String, String>> _uploadChapterPdf(String bookId, int chapterNumber, File pdfFile) async {
    try {
      if (!pdfFile.existsSync()) {
        throw Exception('Chapter PDF file does not exist at path: ${pdfFile.path}');
      }
      
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

  Future<Map<String, String>> _uploadChapterAudio(String bookId, int chapterNumber, int audioTrackIndex, File audioFile) async {
    try {
      if (!audioFile.existsSync()) {
        throw Exception('Chapter audio file does not exist at path: ${audioFile.path}');
      }
      
      final extension = _getAudioExtension(audioFile.path);
      final storagePath = 'books/$bookId/chapters/chapter_${chapterNumber}_audio_$audioTrackIndex$extension';
      final fileRef = storage.ref().child(storagePath);

      final uploadTask = await fileRef.putFile(
        audioFile,
        SettableMetadata(contentType: _getAudioContentType(extension))
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded chapter audio');
      }
      
      return {
        'url': downloadUrl,
        'storagePath': storagePath
      };
    } catch (e) {
      throw Exception('Chapter audio upload failed: $e');
    }
  }
  
  Future<Map<String, String>> _uploadCoverImage(String bookId, File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        throw Exception('Image file does not exist at path: ${imageFile.path}');
      }
      
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

  String _getAudioExtension(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'm4a':
        return '.m4a';
      case 'mp3':
        return '.mp3';
      case 'wav':
        return '.wav';
      case 'aac':
        return '.aac';
      default:
        return '.m4a';
    }
  }

  String _getAudioContentType(String extension) {
    switch (extension) {
      case '.m4a':
        return 'audio/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.aac':
        return 'audio/aac';
      default:
        return 'audio/mp4';
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
    if (data.containsKey('pdfPath') && data['pdfPath'] != null) {
      await _deleteFileByPath(data['pdfPath'] as String);
    }
    
    if (data.containsKey('bookImagePath') && data['bookImagePath'] != null) {
      await _deleteFileByPath(data['bookImagePath'] as String);
    }
    
    // Delete multiple audio tracks
    if (data.containsKey('audioTracks') && data['audioTracks'] is List) {
      final audioTracks = (data['audioTracks'] as List)
          .map((trackJson) => AudioTrack.fromJson(trackJson))
          .toList();
      
      for (final track in audioTracks) {
        if (track.audioPath != null && track.audioPath!.isNotEmpty) {
          await _deleteFileByPath(track.audioPath!);
        }
      }
    }
    
    if (data.containsKey('chapters') && data['chapters'] is List) {
      final chapters = (data['chapters'] as List)
          .map((chapterJson) => Chapter.fromJson(chapterJson))
          .toList();
      
      for (final chapter in chapters) {
        if (chapter.pdfPath != null && chapter.pdfPath!.isNotEmpty) {
          await _deleteFileByPath(chapter.pdfPath!);
        }
        for (final track in chapter.audioTracks) {
          if (track.audioPath != null && track.audioPath!.isNotEmpty) {
            await _deleteFileByPath(track.audioPath!);
          }
        }
      }
    }
    
    // Legacy single audio deletion for backward compatibility
    if (data.containsKey('audioPath') && data['audioPath'] != null) {
      await _deleteFileByPath(data['audioPath'] as String);
    }
    
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