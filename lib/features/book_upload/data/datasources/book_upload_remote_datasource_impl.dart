import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/book_upload/data/datasources/book_upload_remote_datasource.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class FirestoreBookUploadDataSourceImpl implements BookUploadRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final String booksCollection = 'books';
  
  static const String _booksStorageRoot = 'books';
  static const String _coverImageFilename = 'cover_image.jpg';
  static const String _chapterImageFilename = 'chapter_image.jpg';
  static const String _chapterPdfFilename = 'chapter.pdf';
  static const String _chaptersFolder = 'chapters';
  static const String _audioFolder = 'audio';

  FirestoreBookUploadDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  String _getCoverImagePath(String bookId) {
    return '$_booksStorageRoot/$bookId/$_coverImageFilename';
  }

  String _getChapterImagePath(String bookId, String chapterId) {
    return '$_booksStorageRoot/$bookId/$_chaptersFolder/$chapterId/$_chapterImageFilename';
  }

  String _getChapterPdfPath(String bookId, String chapterId) {
    return '$_booksStorageRoot/$bookId/$_chaptersFolder/$chapterId/$_chapterPdfFilename';
  }

  String _getAudioTrackPath(String bookId, String chapterId, String audioId, String extension) {
    return '$_booksStorageRoot/$bookId/$_chaptersFolder/$chapterId/$_audioFolder/$audioId$extension';
  }

  @override
  Future<BookItem> uploadBook(BookItem book, {File? imageFile}) async {
    if (book.title.isEmpty || book.description.isEmpty || book.chapters.isEmpty) {
      throw ArgumentError('Book title, description, and chapters cannot be empty');
    }

    final batch = firestore.batch();
    final docRef = book.id.isEmpty 
        ? firestore.collection(booksCollection).doc() 
        : firestore.collection(booksCollection).doc(book.id);
    
    final bookId = docRef.id;
    var finalBook = book.copyWith(id: bookId);
    final uploadedPaths = <String>[];

    try {
      // Upload cover image if provided
      if (imageFile != null) {
        final storagePath = _getCoverImagePath(bookId);
        final fileRef = storage.ref().child(storagePath);
        
        final uploadTask = await fileRef.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg')
        );
        
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        
        if (downloadUrl.isEmpty) {
          throw Exception('Failed to get download URL for uploaded cover image');
        }
        
        uploadedPaths.add(storagePath);
        finalBook = finalBook.copyWith(
          imageUrl: downloadUrl,
          imagePath: storagePath,
        );
      }
      
      // Process chapters
      final updatedChapters = <BookChapter>[];
      for (final chapter in finalBook.chapters) {
        final updatedChapter = await _processChapterFiles(bookId, chapter, uploadedPaths);
        updatedChapters.add(updatedChapter);
      }
      
      finalBook = finalBook.copyWith(chapters: updatedChapters);
      
      // Save to Firestore
      final bookData = finalBook.toJson();
      bookData['titleLowerCase'] = finalBook.title.toLowerCase();
      bookData['descriptionLowerCase'] = finalBook.description.toLowerCase();
      bookData['createdAt'] = FieldValue.serverTimestamp();
      bookData['updatedAt'] = FieldValue.serverTimestamp();
      
      batch.set(docRef, bookData);
      await batch.commit();
      
      return finalBook.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
    } on FirebaseException catch (e) {
      await _cleanupFiles(uploadedPaths);
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      await _cleanupFiles(uploadedPaths);
      throw Exception('Failed to upload book: $e');
    }
  }

  Future<BookChapter> _processChapterFiles(String bookId, BookChapter chapter, List<String> uploadedPaths) async {
    var updatedChapter = chapter;
    
    // Upload chapter image if it's a local file
    if (chapter.imagePath != null && 
        chapter.imagePath!.startsWith('/') && 
        File(chapter.imagePath!).existsSync()) {
      
      final chapterImageFile = File(chapter.imagePath!);
      final chapterStoragePath = _getChapterImagePath(bookId, chapter.id);
      final chapterFileRef = storage.ref().child(chapterStoragePath);
      
      final chapterUploadTask = await chapterFileRef.putFile(
        chapterImageFile,
        SettableMetadata(contentType: 'image/jpeg')
      );
      
      final chapterDownloadUrl = await chapterUploadTask.ref.getDownloadURL();
      
      if (chapterDownloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for chapter image');
      }
      
      uploadedPaths.add(chapterStoragePath);
      updatedChapter = updatedChapter.copyWith(
        imageUrl: chapterDownloadUrl,
        imagePath: chapterStoragePath,
      );
    }

    // Upload PDF if it's a local file
    if (chapter.pdfPath != null && 
        chapter.pdfPath!.startsWith('/') && 
        File(chapter.pdfPath!).existsSync()) {
      
      final pdfFile = File(chapter.pdfPath!);
      final pdfStoragePath = _getChapterPdfPath(bookId, chapter.id);
      final pdfFileRef = storage.ref().child(pdfStoragePath);
      
      final pdfUploadTask = await pdfFileRef.putFile(
        pdfFile,
        SettableMetadata(contentType: 'application/pdf')
      );
      
      final pdfDownloadUrl = await pdfUploadTask.ref.getDownloadURL();
      
      if (pdfDownloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for chapter PDF');
      }
      
      uploadedPaths.add(pdfStoragePath);
      updatedChapter = updatedChapter.copyWith(
        pdfUrl: pdfDownloadUrl,
        pdfPath: pdfStoragePath,
      );
    }

    // Upload audio tracks
    final updatedAudioTracks = <AudioTrack>[];
    for (final audioTrack in chapter.audioTracks) {
      if (audioTrack.audioPath != null && 
          audioTrack.audioPath!.startsWith('/') && 
          File(audioTrack.audioPath!).existsSync()) {
        
        final audioFile = File(audioTrack.audioPath!);
        final extension = _getAudioExtension(audioTrack.audioPath!);
        final audioStoragePath = _getAudioTrackPath(bookId, chapter.id, audioTrack.id, extension);
        final audioFileRef = storage.ref().child(audioStoragePath);
        
        final audioUploadTask = await audioFileRef.putFile(
          audioFile,
          SettableMetadata(contentType: _getAudioContentType(extension))
        );
        
        final audioDownloadUrl = await audioUploadTask.ref.getDownloadURL();
        
        if (audioDownloadUrl.isEmpty) {
          throw Exception('Failed to get download URL for audio track');
        }
        
        uploadedPaths.add(audioStoragePath);
        updatedAudioTracks.add(audioTrack.copyWith(
          audioUrl: audioDownloadUrl,
          audioPath: audioStoragePath,
        ));
      } else {
        updatedAudioTracks.add(audioTrack);
      }
    }
    
    updatedChapter = updatedChapter.copyWith(audioTracks: updatedAudioTracks);
    return updatedChapter;
  }

  @override
  Future<BookItem> updateBook(String bookId, BookItem updatedBook, {File? imageFile}) async {
    final batch = firestore.batch();
    final docRef = firestore.collection(booksCollection).doc(bookId);
    
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Book not found');
    }
    
    final existingData = docSnapshot.data() as Map<String, dynamic>;
    final existingBook = BookItem.fromJson({...existingData, 'id': bookId});
    
    var finalBook = updatedBook;
    final newUploadedPaths = <String>[];
    final pathsToDelete = <String>[];
    
    try {
      // Handle cover image update
      finalBook = await _handleCoverImageUpdate(
        bookId, finalBook, existingBook, imageFile, newUploadedPaths, pathsToDelete
      );
      
      // Handle chapters update
      final updatedChapters = await _handleChaptersUpdate(
        bookId, finalBook, existingBook, newUploadedPaths, pathsToDelete
      );
      
      finalBook = finalBook.copyWith(chapters: updatedChapters);
      
      // Save updated book
      await _saveUpdatedBook(batch, docRef, finalBook);
      
      // Cleanup old files
      if (pathsToDelete.isNotEmpty) {
        await _cleanupFiles(pathsToDelete);
      }
      
      return finalBook.copyWith(updatedAt: DateTime.now());
      
    } on FirebaseException catch (e) {
      await _cleanupFiles(newUploadedPaths);
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      await _cleanupFiles(newUploadedPaths);
      throw Exception('Failed to update book: $e');
    }
  }

  Future<BookItem> _handleCoverImageUpdate(
    String bookId,
    BookItem finalBook,
    BookItem existingBook,
    File? imageFile,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (imageFile != null) {
      if (await imageFile.exists()) {
        try {
          final storagePath = _getCoverImagePath(bookId);
          final fileRef = storage.ref().child(storagePath);
          
          final uploadTask = await fileRef.putFile(
            imageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          
          if (downloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for uploaded cover image');
          }
          
          if (existingBook.imagePath != null && 
              existingBook.imagePath!.isNotEmpty &&
              existingBook.imagePath != storagePath) {
            pathsToDelete.add(existingBook.imagePath!);
          }
          
          newUploadedPaths.add(storagePath);
          return finalBook.copyWith(
            imageUrl: downloadUrl,
            imagePath: storagePath,
          );
        } catch (e) {
          return finalBook.copyWith(
            imageUrl: existingBook.imageUrl,
            imagePath: existingBook.imagePath,
          );
        }
      } else {
        return finalBook.copyWith(
          imageUrl: existingBook.imageUrl,
          imagePath: existingBook.imagePath,
        );
      }
    } else if ((finalBook.imageUrl == null || finalBook.imageUrl!.isEmpty) &&
              (finalBook.imagePath == null || finalBook.imagePath!.isEmpty)) {
      if (existingBook.imagePath != null && existingBook.imagePath!.isNotEmpty) {
        pathsToDelete.add(existingBook.imagePath!);
      }
      return finalBook;
    } else {
      return finalBook.copyWith(
        imageUrl: existingBook.imageUrl,
        imagePath: existingBook.imagePath,
      );
    }
  }

  Future<List<BookChapter>> _handleChaptersUpdate(
    String bookId,
    BookItem finalBook,
    BookItem existingBook,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingChaptersMap = <String, BookChapter>{};
    for (final c in existingBook.chapters) {
      existingChaptersMap[c.id] = c;
    }
    
    final updatedChapters = <BookChapter>[];
    final currentChapterIds = <String>{};
    
    for (final chapter in finalBook.chapters) {
      currentChapterIds.add(chapter.id);
      final existingChapter = existingChaptersMap[chapter.id];
      
      final updatedChapter = await _handleSingleChapterUpdate(
        bookId, chapter, existingChapter, newUploadedPaths, pathsToDelete
      );
      
      updatedChapters.add(updatedChapter);
    }
    
    _handleRemovedChapters(existingBook, currentChapterIds, pathsToDelete);
    
    return updatedChapters;
  }

  Future<BookChapter> _handleSingleChapterUpdate(
    String bookId,
    BookChapter chapter,
    BookChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    var updatedChapter = chapter;
    
    // Handle chapter image update
    updatedChapter = await _handleChapterImageUpdate(
      bookId, updatedChapter, existingChapter, newUploadedPaths, pathsToDelete
    );
    
    // Handle PDF update
    updatedChapter = await _handleChapterPdfUpdate(
      bookId, updatedChapter, existingChapter, newUploadedPaths, pathsToDelete
    );
    
    // Handle audio tracks update
    final updatedAudioTracks = await _handleAudioTracksUpdate(
      bookId, chapter, existingChapter, newUploadedPaths, pathsToDelete
    );
    
    return updatedChapter.copyWith(audioTracks: updatedAudioTracks);
  }

  Future<BookChapter> _handleChapterImageUpdate(
    String bookId,
    BookChapter chapter,
    BookChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewImage = _isNewFile(
      currentPath: chapter.imagePath,
      currentUrl: chapter.imageUrl,
      existingPath: existingChapter?.imagePath,
      existingUrl: existingChapter?.imageUrl,
    );
    
    if (isNewImage) {
      if (chapter.imagePath != null && 
          chapter.imagePath!.startsWith('/') &&
          !_isFirebaseStoragePath(chapter.imagePath!) &&
          !_isCachedFile(chapter.imagePath!)) {
        
        final imageFile = File(chapter.imagePath!);
        if (await imageFile.exists()) {
          try {
            final storagePath = _getChapterImagePath(bookId, chapter.id);
            final fileRef = storage.ref().child(storagePath);
            
            final uploadTask = await fileRef.putFile(
              imageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final downloadUrl = await uploadTask.ref.getDownloadURL();
            
            if (downloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for chapter image');
            }
            
            if (existingChapter?.imagePath != null && 
                existingChapter!.imagePath!.isNotEmpty &&
                existingChapter.imagePath != storagePath) {
              pathsToDelete.add(existingChapter.imagePath!);
            }
            
            newUploadedPaths.add(storagePath);
            return chapter.copyWith(
              imageUrl: downloadUrl,
              imagePath: storagePath,
            );
          } catch (e) {
            return chapter.copyWith(
              imageUrl: existingChapter?.imageUrl,
              imagePath: existingChapter?.imagePath,
            );
          }
        } else {
          return chapter.copyWith(
            imageUrl: existingChapter?.imageUrl,
            imagePath: existingChapter?.imagePath,
          );
        }
      }
      return chapter;
    } else if ((chapter.imageUrl == null || chapter.imageUrl!.isEmpty) &&
              (chapter.imagePath == null || chapter.imagePath!.isEmpty) &&
              existingChapter?.imagePath != null && 
              existingChapter!.imagePath!.isNotEmpty) {
      pathsToDelete.add(existingChapter.imagePath!);
      return chapter;
    } else {
      return chapter.copyWith(
        imageUrl: existingChapter?.imageUrl,
        imagePath: existingChapter?.imagePath,
      );
    }
  }

  Future<BookChapter> _handleChapterPdfUpdate(
    String bookId,
    BookChapter chapter,
    BookChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewPdf = _isNewFile(
      currentPath: chapter.pdfPath,
      currentUrl: chapter.pdfUrl,
      existingPath: existingChapter?.pdfPath,
      existingUrl: existingChapter?.pdfUrl,
    );
    
    if (isNewPdf) {
      if (chapter.pdfPath != null && 
          chapter.pdfPath!.startsWith('/') &&
          !_isFirebaseStoragePath(chapter.pdfPath!) &&
          !_isCachedFile(chapter.pdfPath!)) {
        
        final pdfFile = File(chapter.pdfPath!);
        if (await pdfFile.exists()) {
          try {
            final storagePath = _getChapterPdfPath(bookId, chapter.id);
            final fileRef = storage.ref().child(storagePath);
            
            final uploadTask = await fileRef.putFile(
              pdfFile,
              SettableMetadata(contentType: 'application/pdf')
            );
            
            final downloadUrl = await uploadTask.ref.getDownloadURL();
            
            if (downloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for chapter PDF');
            }
            
            if (existingChapter?.pdfPath != null && 
                existingChapter!.pdfPath!.isNotEmpty &&
                existingChapter.pdfPath != storagePath) {
              pathsToDelete.add(existingChapter.pdfPath!);
            }
            
            newUploadedPaths.add(storagePath);
            return chapter.copyWith(
              pdfUrl: downloadUrl,
              pdfPath: storagePath,
            );
          } catch (e) {
            return chapter.copyWith(
              pdfUrl: existingChapter?.pdfUrl,
              pdfPath: existingChapter?.pdfPath,
            );
          }
        } else {
          return chapter.copyWith(
            pdfUrl: existingChapter?.pdfUrl,
            pdfPath: existingChapter?.pdfPath,
          );
        }
      }
      return chapter;
    } else if ((chapter.pdfUrl == null || chapter.pdfUrl!.isEmpty) &&
              (chapter.pdfPath == null || chapter.pdfPath!.isEmpty) &&
              existingChapter?.pdfPath != null && 
              existingChapter!.pdfPath!.isNotEmpty) {
      pathsToDelete.add(existingChapter.pdfPath!);
      return chapter;
    } else {
      return chapter.copyWith(
        pdfUrl: existingChapter?.pdfUrl,
        pdfPath: existingChapter?.pdfPath,
      );
    }
  }

  Future<List<AudioTrack>> _handleAudioTracksUpdate(
    String bookId,
    BookChapter chapter,
    BookChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingAudioMap = <String, AudioTrack>{};
    if (existingChapter != null) {
      for (final audio in existingChapter.audioTracks) {
        existingAudioMap[audio.id] = audio;
      }
    }
    
    final updatedAudioTracks = <AudioTrack>[];
    final currentAudioIds = <String>{};
    
    for (final audioTrack in chapter.audioTracks) {
      currentAudioIds.add(audioTrack.id);
      final existingAudio = existingAudioMap[audioTrack.id];
      
      final updatedAudio = await _handleSingleAudioUpdate(
        bookId, chapter.id, audioTrack, existingAudio, newUploadedPaths, pathsToDelete
      );
      
      updatedAudioTracks.add(updatedAudio);
    }
    
    // Handle removed audio tracks
    if (existingChapter != null) {
      for (final existingAudio in existingChapter.audioTracks) {
        if (!currentAudioIds.contains(existingAudio.id)) {
          if (existingAudio.audioPath != null && existingAudio.audioPath!.isNotEmpty) {
            pathsToDelete.add(existingAudio.audioPath!);
          }
        }
      }
    }
    
    return updatedAudioTracks;
  }

  Future<AudioTrack> _handleSingleAudioUpdate(
    String bookId,
    String chapterId,
    AudioTrack audioTrack,
    AudioTrack? existingAudio,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewAudio = _isNewFile(
      currentPath: audioTrack.audioPath,
      currentUrl: audioTrack.audioUrl,
      existingPath: existingAudio?.audioPath,
      existingUrl: existingAudio?.audioUrl,
    );
    
    if (isNewAudio) {
      if (audioTrack.audioPath != null && 
          audioTrack.audioPath!.startsWith('/') &&
          !_isFirebaseStoragePath(audioTrack.audioPath!) &&
          !_isCachedFile(audioTrack.audioPath!)) {
        
        final audioFile = File(audioTrack.audioPath!);
        if (await audioFile.exists()) {
          try {
            final extension = _getAudioExtension(audioTrack.audioPath!);
            final storagePath = _getAudioTrackPath(bookId, chapterId, audioTrack.id, extension);
            final fileRef = storage.ref().child(storagePath);
            
            final uploadTask = await fileRef.putFile(
              audioFile,
              SettableMetadata(contentType: _getAudioContentType(extension))
            );
            
            final downloadUrl = await uploadTask.ref.getDownloadURL();
            
            if (downloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for audio track');
            }
            
            if (existingAudio?.audioPath != null && 
                existingAudio!.audioPath!.isNotEmpty &&
                existingAudio.audioPath != storagePath) {
              pathsToDelete.add(existingAudio.audioPath!);
            }
            
            newUploadedPaths.add(storagePath);
            return audioTrack.copyWith(
              audioUrl: downloadUrl,
              audioPath: storagePath,
            );
          } catch (e) {
            return audioTrack.copyWith(
              audioUrl: existingAudio?.audioUrl,
              audioPath: existingAudio?.audioPath,
            );
          }
        } else {
          return audioTrack.copyWith(
            audioUrl: existingAudio?.audioUrl,
            audioPath: existingAudio?.audioPath,
          );
        }
      }
      return audioTrack;
    } else if ((audioTrack.audioUrl == null || audioTrack.audioUrl!.isEmpty) &&
              (audioTrack.audioPath == null || audioTrack.audioPath!.isEmpty) &&
              existingAudio?.audioPath != null && 
              existingAudio!.audioPath!.isNotEmpty) {
      pathsToDelete.add(existingAudio.audioPath!);
      return audioTrack;
    } else {
      return audioTrack.copyWith(
        audioUrl: existingAudio?.audioUrl,
        audioPath: existingAudio?.audioPath,
      );
    }
  }

  void _handleRemovedChapters(
    BookItem existingBook,
    Set<String> currentChapterIds,
    List<String> pathsToDelete,
  ) {
    for (final existingChapter in existingBook.chapters) {
      if (!currentChapterIds.contains(existingChapter.id)) {
        if (existingChapter.imagePath != null && 
            existingChapter.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingChapter.imagePath!);
        }
        if (existingChapter.pdfPath != null && 
            existingChapter.pdfPath!.isNotEmpty) {
          pathsToDelete.add(existingChapter.pdfPath!);
        }
        
        for (final audioTrack in existingChapter.audioTracks) {
          if (audioTrack.audioPath != null && audioTrack.audioPath!.isNotEmpty) {
            pathsToDelete.add(audioTrack.audioPath!);
          }
        }
      }
    }
  }

  Future<void> _saveUpdatedBook(
    WriteBatch batch,
    DocumentReference docRef,
    BookItem finalBook,
  ) async {
    final updateData = finalBook.toJson();
    updateData['titleLowerCase'] = finalBook.title.toLowerCase();
    updateData['descriptionLowerCase'] = finalBook.description.toLowerCase();
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    batch.update(docRef, updateData);
    await batch.commit();
  }

  bool _isNewFile({
    required String? currentPath,
    required String? currentUrl,
    required String? existingPath,
    required String? existingUrl,
  }) {
    if ((currentPath == null || currentPath.isEmpty) &&
        (currentUrl == null || currentUrl.isEmpty)) {
      return false;
    }

    if ((existingPath == null || existingPath.isEmpty) &&
        (existingUrl == null || existingUrl.isEmpty)) {
      return true;
    }

    if (currentPath != null && 
        currentPath.startsWith('/') && 
        !_isFirebaseStoragePath(currentPath) &&
        !_isCachedFile(currentPath)) {
      if (currentPath != existingPath) {
        try {
          final file = File(currentPath);
          if (file.existsSync()) {
            if (kDebugMode) {
              print('Detected new local file: $currentPath');
            }
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error checking file existence for $currentPath: $e');
          }
          return false;
        }
      }
    }

    if (currentUrl == existingUrl && currentPath == existingPath) {
      return false;
    }

    if ((currentUrl == null || currentUrl.isEmpty) && 
        (currentPath == null || currentPath.isEmpty) &&
        ((existingUrl != null && existingUrl.isNotEmpty) || 
        (existingPath != null && existingPath.isNotEmpty))) {
      return true;
    }
    
    return false;
  }

  @override
  Future<bool> deleteBook(String bookId) async {
    final batch = firestore.batch();
    final docRef = firestore.collection(booksCollection).doc(bookId);
    
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Book not found');
    }
    
    final data = docSnapshot.data() as Map<String, dynamic>;
    final pathsToDelete = <String>[];
    
    try {
      if (data.containsKey('imagePath') && data['imagePath'] != null) {
        pathsToDelete.add(data['imagePath'] as String);
      }
      
      if (data.containsKey('chapters') && data['chapters'] is List) {
        final chapters = data['chapters'] as List;
        for (final chapterData in chapters) {
          if (chapterData is Map<String, dynamic>) {
            if (chapterData.containsKey('imagePath') && chapterData['imagePath'] != null) {
              pathsToDelete.add(chapterData['imagePath'] as String);
            }
            if (chapterData.containsKey('pdfPath') && chapterData['pdfPath'] != null) {
              pathsToDelete.add(chapterData['pdfPath'] as String);
            }
            
            if (chapterData.containsKey('audioTracks') && chapterData['audioTracks'] is List) {
              final audioTracks = chapterData['audioTracks'] as List;
              for (final audioTrack in audioTracks) {
                if (audioTrack is Map<String, dynamic>) {
                  if (audioTrack.containsKey('audioPath') && audioTrack['audioPath'] != null) {
                    pathsToDelete.add(audioTrack['audioPath'] as String);
                  }
                }
              }
            }
          }
        }
      }
      
      await _cleanupFiles(pathsToDelete);
      
      if (data.containsKey('imageUrl') && data['imageUrl'] != null) {
        try {
          final imageRef = storage.refFromURL(data['imageUrl'] as String);
          await imageRef.delete();
        } catch (e) {
          if (kDebugMode) {
            print('Failed to delete cover image by URL: $e');
          }
        }
      }
      
      batch.delete(docRef);
      await batch.commit();
      
      return true;
      
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to delete book: $e');
    }
  }

  @override
  Future<DateTime?> getBookLastUpdated(String bookId) async {
    try {
      final docSnapshot = await firestore.collection(booksCollection).doc(bookId).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      
      if (data.containsKey('updatedAt') && data['updatedAt'] != null) {
        return (data['updatedAt'] as Timestamp).toDate();
      }
      
      return null;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to get book last updated: $e');
    }
  }

  @override
  Future<String?> regenerateUrlFromPath(String storagePath) async {
    try {
      if (storagePath.isEmpty) {
        return null;
      }
      
      final fileRef = storage.ref().child(storagePath);
      final downloadUrl = await fileRef.getDownloadURL();
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to regenerate URL: $e');
    }
  }

  @override
  Future<bool> verifyUrlIsWorking(String url) async {
    try {
      if (url.startsWith('https://firebasestorage.googleapis.com')) {
        try {
          final storageRef = storage.refFromURL(url);
          await storageRef.getMetadata();
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('Storage URL validation failed: $e');
          }
          return false;
        }
      } else {
        final httpClient = HttpClient();
        final request = await httpClient.headUrl(Uri.parse(url));
        final response = await request.close();
        return response.statusCode >= 200 && response.statusCode < 300;
      }
    } catch (e) {
      return false;
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

  Future<void> _cleanupFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        if (path.isNotEmpty) {
          final fileRef = storage.ref().child(path);
          await fileRef.delete();
          if (kDebugMode) {
            print('Successfully deleted file: $path');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to delete file at $path: $e');
        }
      }
    }
  }

  bool _isCachedFile(String path) {
    return path.startsWith('/') && 
          (path.contains('books_files_cache'));
  }

  bool _isFirebaseStoragePath(String path) {
    return path.startsWith('$_booksStorageRoot/') && 
          (path.contains('.jpg') || 
            path.contains('.jpeg') ||
            path.contains('.png') ||
            path.contains('.pdf') ||
            path.contains('.m4a') ||
            path.contains('.mp3') ||
            path.contains('.wav') ||
            path.contains('.aac'));
  }
}