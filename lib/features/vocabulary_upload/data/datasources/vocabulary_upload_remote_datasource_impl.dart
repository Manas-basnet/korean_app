import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/vocabulary_upload/data/datasources/vocabulary_upload_remote_datasource.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';

class FirestoreVocabularyUploadDataSourceImpl implements VocabularyUploadRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final String vocabulariesCollection = 'vocabularies';
  
  static const String _vocabulariesStorageRoot = 'vocabularies';
  static const String _coverImageFilename = 'cover_image.jpg';
  static const String _chapterImageFilename = 'chapter_image.jpg';
  static const String _wordImageFilename = 'word_image.jpg';
  static const String _wordAudioFilename = 'word_audio';
  static const String _meaningImageFilename = 'meaning_image.jpg';
  static const String _meaningAudioFilename = 'meaning_audio';
  static const String _exampleImageFilename = 'example_image.jpg';
  static const String _exampleAudioFilename = 'example_audio';
  static const String _chaptersFolder = 'chapters';
  static const String _wordsFolder = 'words';
  static const String _meaningsFolder = 'meanings';
  static const String _examplesFolder = 'examples';
  static const String _pdfsFolder = 'pdfs';

  FirestoreVocabularyUploadDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  String _getCoverImagePath(String vocabularyId) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_coverImageFilename';
  }

  String _getChapterImagePath(String vocabularyId, String chapterId) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_chapterImageFilename';
  }

  String _getWordImagePath(String vocabularyId, String chapterId, String wordId) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_wordsFolder/$wordId/$_wordImageFilename';
  }

  String _getWordAudioPath(String vocabularyId, String chapterId, String wordId, String extension) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_wordsFolder/$wordId/$_wordAudioFilename$extension';
  }

  String _getMeaningImagePath(String vocabularyId, String chapterId, String wordId, String meaningId) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_wordsFolder/$wordId/$_meaningsFolder/$meaningId/$_meaningImageFilename';
  }

  String _getMeaningAudioPath(String vocabularyId, String chapterId, String wordId, String meaningId, String extension) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_wordsFolder/$wordId/$_meaningsFolder/$meaningId/$_meaningAudioFilename$extension';
  }

  String _getExampleImagePath(String vocabularyId, String chapterId, String wordId, String exampleId) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_wordsFolder/$wordId/$_examplesFolder/$exampleId/$_exampleImageFilename';
  }

  String _getExampleAudioPath(String vocabularyId, String chapterId, String wordId, String exampleId, String extension) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_chaptersFolder/$chapterId/$_wordsFolder/$wordId/$_examplesFolder/$exampleId/$_exampleAudioFilename$extension';
  }

  String _getPdfPath(String vocabularyId, int pdfIndex, String filename) {
    return '$_vocabulariesStorageRoot/$vocabularyId/$_pdfsFolder/$pdfIndex-$filename';
  }

  @override
  Future<VocabularyItem> uploadVocabulary(VocabularyItem vocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    if (vocabulary.title.isEmpty || vocabulary.description.isEmpty) {
      throw ArgumentError('Vocabulary title and description cannot be empty');
    }

    final batch = firestore.batch();
    final docRef = vocabulary.id.isEmpty 
        ? firestore.collection(vocabulariesCollection).doc() 
        : firestore.collection(vocabulariesCollection).doc(vocabulary.id);
    
    final vocabularyId = docRef.id;
    var finalVocabulary = vocabulary.copyWith(id: vocabularyId);
    final uploadedPaths = <String>[];

    try {
      if (imageFile != null) {
        final storagePath = _getCoverImagePath(vocabularyId);
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
        finalVocabulary = finalVocabulary.copyWith(
          imageUrl: downloadUrl,
          imagePath: storagePath,
        );
      }

      final updatedPdfUrls = <String>[];
      final updatedPdfPaths = <String>[];
      
      if (pdfFiles != null && pdfFiles.isNotEmpty) {
        for (int i = 0; i < pdfFiles.length; i++) {
          final pdfFile = pdfFiles[i];
          final filename = pdfFile.path.split('/').last;
          final pdfStoragePath = _getPdfPath(vocabularyId, i, filename);
          final pdfFileRef = storage.ref().child(pdfStoragePath);
          
          final pdfUploadTask = await pdfFileRef.putFile(
            pdfFile,
            SettableMetadata(contentType: 'application/pdf')
          );
          
          final pdfDownloadUrl = await pdfUploadTask.ref.getDownloadURL();
          
          if (pdfDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for uploaded PDF');
          }
          
          uploadedPaths.add(pdfStoragePath);
          updatedPdfUrls.add(pdfDownloadUrl);
          updatedPdfPaths.add(pdfStoragePath);
        }
      }
      
      finalVocabulary = finalVocabulary.copyWith(
        pdfUrls: updatedPdfUrls,
        pdfPaths: updatedPdfPaths,
      );
      
      final updatedChapters = <VocabularyChapter>[];
      for (final chapter in finalVocabulary.chapters) {
        var updatedChapter = chapter;
        
        if (chapter.imagePath != null && 
            chapter.imagePath!.startsWith('/') && 
            File(chapter.imagePath!).existsSync()) {
          
          final chapterImageFile = File(chapter.imagePath!);
          final chapterStoragePath = _getChapterImagePath(vocabularyId, chapter.id);
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
        
        final updatedWords = <VocabularyWord>[];
        for (final word in chapter.words) {
          var updatedWord = word;
          
          if (word.imagePath != null && 
              word.imagePath!.startsWith('/') && 
              File(word.imagePath!).existsSync()) {
            
            final wordImageFile = File(word.imagePath!);
            final wordStoragePath = _getWordImagePath(vocabularyId, chapter.id, word.id);
            final wordFileRef = storage.ref().child(wordStoragePath);
            
            final wordUploadTask = await wordFileRef.putFile(
              wordImageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final wordDownloadUrl = await wordUploadTask.ref.getDownloadURL();
            
            if (wordDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for word image');
            }
            
            uploadedPaths.add(wordStoragePath);
            updatedWord = updatedWord.copyWith(
              imageUrl: wordDownloadUrl,
              imagePath: wordStoragePath,
            );
          }

          if (word.audioPath != null && 
              word.audioPath!.startsWith('/') && 
              File(word.audioPath!).existsSync()) {
            
            final wordAudioFile = File(word.audioPath!);
            final extension = _getAudioExtension(word.audioPath!);
            final wordStoragePath = _getWordAudioPath(vocabularyId, chapter.id, word.id, extension);
            final wordFileRef = storage.ref().child(wordStoragePath);
            
            final wordUploadTask = await wordFileRef.putFile(
              wordAudioFile,
              SettableMetadata(contentType: _getAudioContentType(extension))
            );
            
            final wordDownloadUrl = await wordUploadTask.ref.getDownloadURL();
            
            if (wordDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for word audio');
            }
            
            uploadedPaths.add(wordStoragePath);
            updatedWord = updatedWord.copyWith(
              audioUrl: wordDownloadUrl,
              audioPath: wordStoragePath,
            );
          }
          
          final updatedMeanings = <WordMeaning>[];
          for (final meaning in word.meanings) {
            var updatedMeaning = meaning;
            
            if (meaning.imagePath != null && 
                meaning.imagePath!.startsWith('/') && 
                File(meaning.imagePath!).existsSync()) {
              
              final meaningImageFile = File(meaning.imagePath!);
              final meaningStoragePath = _getMeaningImagePath(vocabularyId, chapter.id, word.id, meaning.id);
              final meaningFileRef = storage.ref().child(meaningStoragePath);
              
              final meaningUploadTask = await meaningFileRef.putFile(
                meaningImageFile,
                SettableMetadata(contentType: 'image/jpeg')
              );
              
              final meaningDownloadUrl = await meaningUploadTask.ref.getDownloadURL();
              
              if (meaningDownloadUrl.isEmpty) {
                throw Exception('Failed to get download URL for meaning image');
              }
              
              uploadedPaths.add(meaningStoragePath);
              updatedMeaning = updatedMeaning.copyWith(
                imageUrl: meaningDownloadUrl,
                imagePath: meaningStoragePath,
              );
            }

            if (meaning.audioPath != null && 
                meaning.audioPath!.startsWith('/') && 
                File(meaning.audioPath!).existsSync()) {
              
              final meaningAudioFile = File(meaning.audioPath!);
              final extension = _getAudioExtension(meaning.audioPath!);
              final meaningStoragePath = _getMeaningAudioPath(vocabularyId, chapter.id, word.id, meaning.id, extension);
              final meaningFileRef = storage.ref().child(meaningStoragePath);
              
              final meaningUploadTask = await meaningFileRef.putFile(
                meaningAudioFile,
                SettableMetadata(contentType: _getAudioContentType(extension))
              );
              
              final meaningDownloadUrl = await meaningUploadTask.ref.getDownloadURL();
              
              if (meaningDownloadUrl.isEmpty) {
                throw Exception('Failed to get download URL for meaning audio');
              }
              
              uploadedPaths.add(meaningStoragePath);
              updatedMeaning = updatedMeaning.copyWith(
                audioUrl: meaningDownloadUrl,
                audioPath: meaningStoragePath,
              );
            }
            
            updatedMeanings.add(updatedMeaning);
          }
          
          final updatedExamples = <WordExample>[];
          for (final example in word.examples) {
            var updatedExample = example;
            
            if (example.imagePath != null && 
                example.imagePath!.startsWith('/') && 
                File(example.imagePath!).existsSync()) {
              
              final exampleImageFile = File(example.imagePath!);
              final exampleStoragePath = _getExampleImagePath(vocabularyId, chapter.id, word.id, example.id);
              final exampleFileRef = storage.ref().child(exampleStoragePath);
              
              final exampleUploadTask = await exampleFileRef.putFile(
                exampleImageFile,
                SettableMetadata(contentType: 'image/jpeg')
              );
              
              final exampleDownloadUrl = await exampleUploadTask.ref.getDownloadURL();
              
              if (exampleDownloadUrl.isEmpty) {
                throw Exception('Failed to get download URL for example image');
              }
              
              uploadedPaths.add(exampleStoragePath);
              updatedExample = updatedExample.copyWith(
                imageUrl: exampleDownloadUrl,
                imagePath: exampleStoragePath,
              );
            }

            if (example.audioPath != null && 
                example.audioPath!.startsWith('/') && 
                File(example.audioPath!).existsSync()) {
              
              final exampleAudioFile = File(example.audioPath!);
              final extension = _getAudioExtension(example.audioPath!);
              final exampleStoragePath = _getExampleAudioPath(vocabularyId, chapter.id, word.id, example.id, extension);
              final exampleFileRef = storage.ref().child(exampleStoragePath);
              
              final exampleUploadTask = await exampleFileRef.putFile(
                exampleAudioFile,
                SettableMetadata(contentType: _getAudioContentType(extension))
              );
              
              final exampleDownloadUrl = await exampleUploadTask.ref.getDownloadURL();
              
              if (exampleDownloadUrl.isEmpty) {
                throw Exception('Failed to get download URL for example audio');
              }
              
              uploadedPaths.add(exampleStoragePath);
              updatedExample = updatedExample.copyWith(
                audioUrl: exampleDownloadUrl,
                audioPath: exampleStoragePath,
              );
            }
            
            updatedExamples.add(updatedExample);
          }
          
          updatedWord = updatedWord.copyWith(
            meanings: updatedMeanings,
            examples: updatedExamples,
          );
          updatedWords.add(updatedWord);
        }
        
        updatedChapter = updatedChapter.copyWith(words: updatedWords);
        updatedChapters.add(updatedChapter);
      }
      
      finalVocabulary = finalVocabulary.copyWith(chapters: updatedChapters);
      
      final vocabularyData = finalVocabulary.toJson();
      vocabularyData['titleLowerCase'] = finalVocabulary.title.toLowerCase();
      vocabularyData['descriptionLowerCase'] = finalVocabulary.description.toLowerCase();
      vocabularyData['createdAt'] = FieldValue.serverTimestamp();
      vocabularyData['updatedAt'] = FieldValue.serverTimestamp();
      
      batch.set(docRef, vocabularyData);
      await batch.commit();
      
      return finalVocabulary.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
    } on FirebaseException catch (e) {
      await _cleanupFiles(uploadedPaths);
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      await _cleanupFiles(uploadedPaths);
      throw Exception('Failed to upload vocabulary: $e');
    }
  }

  @override
  Future<VocabularyItem> updateVocabulary(String vocabularyId, VocabularyItem updatedVocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    final batch = firestore.batch();
    final docRef = firestore.collection(vocabulariesCollection).doc(vocabularyId);
    
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Vocabulary not found');
    }
    
    final existingData = docSnapshot.data() as Map<String, dynamic>;
    final existingVocabulary = VocabularyItem.fromJson({...existingData, 'id': vocabularyId});
    
    var finalVocabulary = updatedVocabulary;
    final newUploadedPaths = <String>[];
    final pathsToDelete = <String>[];
    
    try {
      finalVocabulary = await _handleCoverImageUpdate(
        vocabularyId, finalVocabulary, existingVocabulary, imageFile, newUploadedPaths, pathsToDelete
      );
      
      finalVocabulary = await _handlePdfsUpdate(
        vocabularyId, finalVocabulary, existingVocabulary, pdfFiles, newUploadedPaths, pathsToDelete
      );
      
      final updatedChapters = await _handleChaptersUpdate(
        vocabularyId, finalVocabulary, existingVocabulary, newUploadedPaths, pathsToDelete
      );
      
      finalVocabulary = finalVocabulary.copyWith(chapters: updatedChapters);
      
      await _saveUpdatedVocabulary(batch, docRef, finalVocabulary);
      
      if (pathsToDelete.isNotEmpty) {
        await _cleanupFiles(pathsToDelete);
      }
      
      return finalVocabulary.copyWith(updatedAt: DateTime.now());
      
    } on FirebaseException catch (e) {
      await _cleanupFiles(newUploadedPaths);
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      await _cleanupFiles(newUploadedPaths);
      throw Exception('Failed to update vocabulary: $e');
    }
  }

  Future<VocabularyItem> _handleCoverImageUpdate(
    String vocabularyId,
    VocabularyItem finalVocabulary,
    VocabularyItem existingVocabulary,
    File? imageFile,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (imageFile != null) {
      if (await imageFile.exists()) {
        try {
          final storagePath = _getCoverImagePath(vocabularyId);
          final fileRef = storage.ref().child(storagePath);
          
          final uploadTask = await fileRef.putFile(
            imageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          
          if (downloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for uploaded cover image');
          }
          
          if (existingVocabulary.imagePath != null && 
              existingVocabulary.imagePath!.isNotEmpty &&
              existingVocabulary.imagePath != storagePath) {
            pathsToDelete.add(existingVocabulary.imagePath!);
          }
          
          newUploadedPaths.add(storagePath);
          return finalVocabulary.copyWith(
            imageUrl: downloadUrl,
            imagePath: storagePath,
          );
        } catch (e) {
          return finalVocabulary.copyWith(
            imageUrl: existingVocabulary.imageUrl,
            imagePath: existingVocabulary.imagePath,
          );
        }
      } else {
        return finalVocabulary.copyWith(
          imageUrl: existingVocabulary.imageUrl,
          imagePath: existingVocabulary.imagePath,
        );
      }
    } else if ((finalVocabulary.imageUrl == null || finalVocabulary.imageUrl!.isEmpty) &&
              (finalVocabulary.imagePath == null || finalVocabulary.imagePath!.isEmpty)) {
      if (existingVocabulary.imagePath != null && existingVocabulary.imagePath!.isNotEmpty) {
        pathsToDelete.add(existingVocabulary.imagePath!);
      }
      return finalVocabulary;
    } else {
      return finalVocabulary.copyWith(
        imageUrl: existingVocabulary.imageUrl,
        imagePath: existingVocabulary.imagePath,
      );
    }
  }

  Future<VocabularyItem> _handlePdfsUpdate(
    String vocabularyId,
    VocabularyItem finalVocabulary,
    VocabularyItem existingVocabulary,
    List<File>? pdfFiles,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final updatedPdfUrls = <String>[];
    final updatedPdfPaths = <String>[];
    
    if (pdfFiles != null && pdfFiles.isNotEmpty) {
      for (final existingPath in existingVocabulary.pdfPaths) {
        if (existingPath.isNotEmpty) {
          pathsToDelete.add(existingPath);
        }
      }
      
      for (int i = 0; i < pdfFiles.length; i++) {
        final pdfFile = pdfFiles[i];
        if (await pdfFile.exists()) {
          try {
            final filename = pdfFile.path.split('/').last;
            final pdfStoragePath = _getPdfPath(vocabularyId, i, filename);
            final pdfFileRef = storage.ref().child(pdfStoragePath);
            
            final pdfUploadTask = await pdfFileRef.putFile(
              pdfFile,
              SettableMetadata(contentType: 'application/pdf')
            );
            
            final pdfDownloadUrl = await pdfUploadTask.ref.getDownloadURL();
            
            if (pdfDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for uploaded PDF');
            }
            
            newUploadedPaths.add(pdfStoragePath);
            updatedPdfUrls.add(pdfDownloadUrl);
            updatedPdfPaths.add(pdfStoragePath);
          } catch (e) {
          }
        }
      }
    } else {
      updatedPdfUrls.addAll(existingVocabulary.pdfUrls);
      updatedPdfPaths.addAll(existingVocabulary.pdfPaths);
    }
    
    return finalVocabulary.copyWith(
      pdfUrls: updatedPdfUrls,
      pdfPaths: updatedPdfPaths,
    );
  }

  Future<List<VocabularyChapter>> _handleChaptersUpdate(
    String vocabularyId,
    VocabularyItem finalVocabulary,
    VocabularyItem existingVocabulary,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingChaptersMap = <String, VocabularyChapter>{};
    for (final c in existingVocabulary.chapters) {
      existingChaptersMap[c.id] = c;
    }
    
    final updatedChapters = <VocabularyChapter>[];
    final currentChapterIds = <String>{};
    
    for (final chapter in finalVocabulary.chapters) {
      currentChapterIds.add(chapter.id);
      final existingChapter = existingChaptersMap[chapter.id];
      
      final updatedChapter = await _handleSingleChapterUpdate(
        vocabularyId, chapter, existingChapter, newUploadedPaths, pathsToDelete
      );
      
      updatedChapters.add(updatedChapter);
    }
    
    _handleRemovedChapters(existingVocabulary, currentChapterIds, pathsToDelete);
    
    return updatedChapters;
  }

  Future<VocabularyChapter> _handleSingleChapterUpdate(
    String vocabularyId,
    VocabularyChapter chapter,
    VocabularyChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    var updatedChapter = chapter;
    
    updatedChapter = await _handleChapterImageUpdate(
      vocabularyId, updatedChapter, existingChapter, newUploadedPaths, pathsToDelete
    );
    
    final updatedWords = await _handleWordsUpdate(
      vocabularyId, chapter, existingChapter, newUploadedPaths, pathsToDelete
    );
    
    return updatedChapter.copyWith(words: updatedWords);
  }

  Future<VocabularyChapter> _handleChapterImageUpdate(
    String vocabularyId,
    VocabularyChapter chapter,
    VocabularyChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewChapterImage = _isNewMedia(
      currentImagePath: chapter.imagePath,
      currentImageUrl: chapter.imageUrl,
      existingImagePath: existingChapter?.imagePath,
      existingImageUrl: existingChapter?.imageUrl,
    );
    
    if (isNewChapterImage) {
      if (chapter.imagePath != null && 
          chapter.imagePath!.startsWith('/') &&
          !_isFirebaseStoragePath(chapter.imagePath!) &&
          !_isCachedFile(chapter.imagePath!)) {
        
        final chapterImageFile = File(chapter.imagePath!);
        if (await chapterImageFile.exists()) {
          try {
            final chapterStoragePath = _getChapterImagePath(vocabularyId, chapter.id);
            final chapterFileRef = storage.ref().child(chapterStoragePath);
            
            final chapterUploadTask = await chapterFileRef.putFile(
              chapterImageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final chapterDownloadUrl = await chapterUploadTask.ref.getDownloadURL();
            
            if (chapterDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for chapter image');
            }
            
            if (existingChapter?.imagePath != null && 
                existingChapter!.imagePath!.isNotEmpty &&
                existingChapter.imagePath != chapterStoragePath) {
              pathsToDelete.add(existingChapter.imagePath!);
            }
            
            newUploadedPaths.add(chapterStoragePath);
            return chapter.copyWith(
              imageUrl: chapterDownloadUrl,
              imagePath: chapterStoragePath,
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

  Future<List<VocabularyWord>> _handleWordsUpdate(
    String vocabularyId,
    VocabularyChapter chapter,
    VocabularyChapter? existingChapter,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingWordsMap = <String, VocabularyWord>{};
    if (existingChapter != null) {
      for (final w in existingChapter.words) {
        existingWordsMap[w.id] = w;
      }
    }
    
    final updatedWords = <VocabularyWord>[];
    final currentWordIds = <String>{};
    
    for (final word in chapter.words) {
      currentWordIds.add(word.id);
      final existingWord = existingWordsMap[word.id];
      
      final updatedWord = await _handleSingleWordUpdate(
        vocabularyId, chapter.id, word, existingWord, newUploadedPaths, pathsToDelete
      );
      
      updatedWords.add(updatedWord);
    }
    
    if (existingChapter != null) {
      _handleRemovedWords(vocabularyId, chapter.id, existingChapter, currentWordIds, pathsToDelete);
    }
    
    return updatedWords;
  }

  Future<VocabularyWord> _handleSingleWordUpdate(
    String vocabularyId,
    String chapterId,
    VocabularyWord word,
    VocabularyWord? existingWord,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    var updatedWord = word;
    
    updatedWord = await _handleWordImageUpdate(
      vocabularyId, chapterId, updatedWord, existingWord, newUploadedPaths, pathsToDelete
    );
    
    updatedWord = await _handleWordAudioUpdate(
      vocabularyId, chapterId, updatedWord, existingWord, newUploadedPaths, pathsToDelete
    );
    
    final updatedMeanings = await _handleMeaningsUpdate(
      vocabularyId, chapterId, word, existingWord, newUploadedPaths, pathsToDelete
    );
    
    final updatedExamples = await _handleExamplesUpdate(
      vocabularyId, chapterId, word, existingWord, newUploadedPaths, pathsToDelete
    );
    
    return updatedWord.copyWith(
      meanings: updatedMeanings,
      examples: updatedExamples,
    );
  }

  Future<VocabularyWord> _handleWordImageUpdate(
    String vocabularyId,
    String chapterId,
    VocabularyWord word,
    VocabularyWord? existingWord,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewWordImage = _isNewMedia(
      currentImagePath: word.imagePath,
      currentImageUrl: word.imageUrl,
      existingImagePath: existingWord?.imagePath,
      existingImageUrl: existingWord?.imageUrl,
    );
    
    if (isNewWordImage) {
      if (word.imagePath != null && 
          word.imagePath!.startsWith('/') &&
          !_isFirebaseStoragePath(word.imagePath!) &&
          !_isCachedFile(word.imagePath!)) {
        
        final wordImageFile = File(word.imagePath!);
        if (await wordImageFile.exists()) {
          try {
            final wordStoragePath = _getWordImagePath(vocabularyId, chapterId, word.id);
            final wordFileRef = storage.ref().child(wordStoragePath);
            
            final wordUploadTask = await wordFileRef.putFile(
              wordImageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final wordDownloadUrl = await wordUploadTask.ref.getDownloadURL();
            
            if (wordDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for word image');
            }
            
            if (existingWord?.imagePath != null && 
                existingWord!.imagePath!.isNotEmpty &&
                existingWord.imagePath != wordStoragePath) {
              pathsToDelete.add(existingWord.imagePath!);
            }
            
            newUploadedPaths.add(wordStoragePath);
            return word.copyWith(
              imageUrl: wordDownloadUrl,
              imagePath: wordStoragePath,
            );
          } catch (e) {
            return word.copyWith(
              imageUrl: existingWord?.imageUrl,
              imagePath: existingWord?.imagePath,
            );
          }
        } else {
          return word.copyWith(
            imageUrl: existingWord?.imageUrl,
            imagePath: existingWord?.imagePath,
          );
        }
      }
      return word;
    } else if ((word.imageUrl == null || word.imageUrl!.isEmpty) &&
              (word.imagePath == null || word.imagePath!.isEmpty) &&
              existingWord?.imagePath != null && 
              existingWord!.imagePath!.isNotEmpty) {
      pathsToDelete.add(existingWord.imagePath!);
      return word;
    } else {
      return word.copyWith(
        imageUrl: existingWord?.imageUrl,
        imagePath: existingWord?.imagePath,
      );
    }
  }

  Future<VocabularyWord> _handleWordAudioUpdate(
    String vocabularyId,
    String chapterId,
    VocabularyWord word,
    VocabularyWord? existingWord,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewWordAudio = _isNewMedia(
      currentImagePath: word.audioPath,
      currentImageUrl: word.audioUrl,
      existingImagePath: existingWord?.audioPath,
      existingImageUrl: existingWord?.audioUrl,
    );
    
    if (isNewWordAudio) {
      if (word.audioPath != null && 
          word.audioPath!.startsWith('/') &&
          !_isFirebaseStoragePath(word.audioPath!) &&
          !_isCachedFile(word.audioPath!)) {
        
        final wordAudioFile = File(word.audioPath!);
        if (await wordAudioFile.exists()) {
          try {
            final extension = _getAudioExtension(word.audioPath!);
            final wordStoragePath = _getWordAudioPath(vocabularyId, chapterId, word.id, extension);
            final wordFileRef = storage.ref().child(wordStoragePath);
            
            final wordUploadTask = await wordFileRef.putFile(
              wordAudioFile,
              SettableMetadata(contentType: _getAudioContentType(extension))
            );
            
            final wordDownloadUrl = await wordUploadTask.ref.getDownloadURL();
            
            if (wordDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for word audio');
            }
            
            if (existingWord?.audioPath != null && 
                existingWord!.audioPath!.isNotEmpty &&
                existingWord.audioPath != wordStoragePath) {
              pathsToDelete.add(existingWord.audioPath!);
            }
            
            newUploadedPaths.add(wordStoragePath);
            return word.copyWith(
              audioUrl: wordDownloadUrl,
              audioPath: wordStoragePath,
            );
          } catch (e) {
            return word.copyWith(
              audioUrl: existingWord?.audioUrl,
              audioPath: existingWord?.audioPath,
            );
          }
        } else {
          return word.copyWith(
            audioUrl: existingWord?.audioUrl,
            audioPath: existingWord?.audioPath,
          );
        }
      }
      return word;
    } else if ((word.audioUrl == null || word.audioUrl!.isEmpty) &&
              (word.audioPath == null || word.audioPath!.isEmpty) &&
              existingWord?.audioPath != null && 
              existingWord!.audioPath!.isNotEmpty) {
      pathsToDelete.add(existingWord.audioPath!);
      return word;
    } else {
      return word.copyWith(
        audioUrl: existingWord?.audioUrl,
        audioPath: existingWord?.audioPath,
      );
    }
  }

  Future<List<WordMeaning>> _handleMeaningsUpdate(
    String vocabularyId,
    String chapterId,
    VocabularyWord word,
    VocabularyWord? existingWord,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingMeaningsMap = <String, WordMeaning>{};
    if (existingWord != null) {
      for (final m in existingWord.meanings) {
        existingMeaningsMap[m.id] = m;
      }
    }
    
    final updatedMeanings = <WordMeaning>[];
    final currentMeaningIds = <String>{};
    
    for (final meaning in word.meanings) {
      currentMeaningIds.add(meaning.id);
      final existingMeaning = existingMeaningsMap[meaning.id];
      
      final updatedMeaning = await _handleSingleMeaningUpdate(
        vocabularyId, chapterId, word.id, meaning, existingMeaning, newUploadedPaths, pathsToDelete
      );
      
      updatedMeanings.add(updatedMeaning);
    }
    
    if (existingWord != null) {
      _handleRemovedMeanings(vocabularyId, chapterId, word.id, existingWord, currentMeaningIds, pathsToDelete);
    }
    
    return updatedMeanings;
  }

  Future<List<WordExample>> _handleExamplesUpdate(
    String vocabularyId,
    String chapterId,
    VocabularyWord word,
    VocabularyWord? existingWord,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingExamplesMap = <String, WordExample>{};
    if (existingWord != null) {
      for (final e in existingWord.examples) {
        existingExamplesMap[e.id] = e;
      }
    }
    
    final updatedExamples = <WordExample>[];
    final currentExampleIds = <String>{};
    
    for (final example in word.examples) {
      currentExampleIds.add(example.id);
      final existingExample = existingExamplesMap[example.id];
      
      final updatedExample = await _handleSingleExampleUpdate(
        vocabularyId, chapterId, word.id, example, existingExample, newUploadedPaths, pathsToDelete
      );
      
      updatedExamples.add(updatedExample);
    }
    
    if (existingWord != null) {
      _handleRemovedExamples(vocabularyId, chapterId, word.id, existingWord, currentExampleIds, pathsToDelete);
    }
    
    return updatedExamples;
  }

  Future<WordMeaning> _handleSingleMeaningUpdate(
    String vocabularyId,
    String chapterId,
    String wordId,
    WordMeaning meaning,
    WordMeaning? existingMeaning,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    var updatedMeaning = meaning;
    
    final isNewMeaningImage = _isNewMedia(
      currentImagePath: meaning.imagePath,
      currentImageUrl: meaning.imageUrl,
      existingImagePath: existingMeaning?.imagePath,
      existingImageUrl: existingMeaning?.imageUrl,
    );

    final isNewMeaningAudio = _isNewMedia(
      currentImagePath: meaning.audioPath,
      currentImageUrl: meaning.audioUrl,
      existingImagePath: existingMeaning?.audioPath,
      existingImageUrl: existingMeaning?.audioUrl,
    );
    
    if (isNewMeaningImage) {
      updatedMeaning = await _handleMeaningImageUpload(
        vocabularyId, chapterId, wordId, updatedMeaning, existingMeaning, newUploadedPaths, pathsToDelete
      );
    } else if (isNewMeaningAudio) {
      updatedMeaning = await _handleMeaningAudioUpload(
        vocabularyId, chapterId, wordId, updatedMeaning, existingMeaning, newUploadedPaths, pathsToDelete
      );
    } else if ((meaning.imageUrl == null || meaning.imageUrl!.isEmpty) &&
              (meaning.imagePath == null || meaning.imagePath!.isEmpty) &&
              (meaning.audioUrl == null || meaning.audioUrl!.isEmpty) &&
              (meaning.audioPath == null || meaning.audioPath!.isEmpty)) {
      if (existingMeaning?.imagePath != null && existingMeaning!.imagePath!.isNotEmpty) {
        pathsToDelete.add(existingMeaning.imagePath!);
      }
      if (existingMeaning?.audioPath != null && existingMeaning!.audioPath!.isNotEmpty) {
        pathsToDelete.add(existingMeaning.audioPath!);
      }
    } else {
      updatedMeaning = meaning.copyWith(
        imageUrl: existingMeaning?.imageUrl ?? meaning.imageUrl,
        imagePath: existingMeaning?.imagePath ?? meaning.imagePath,
        audioUrl: existingMeaning?.audioUrl ?? meaning.audioUrl,
        audioPath: existingMeaning?.audioPath ?? meaning.audioPath,
      );
    }
    
    return updatedMeaning;
  }

  Future<WordExample> _handleSingleExampleUpdate(
    String vocabularyId,
    String chapterId,
    String wordId,
    WordExample example,
    WordExample? existingExample,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    var updatedExample = example;
    
    final isNewExampleImage = _isNewMedia(
      currentImagePath: example.imagePath,
      currentImageUrl: example.imageUrl,
      existingImagePath: existingExample?.imagePath,
      existingImageUrl: existingExample?.imageUrl,
    );

    final isNewExampleAudio = _isNewMedia(
      currentImagePath: example.audioPath,
      currentImageUrl: example.audioUrl,
      existingImagePath: existingExample?.audioPath,
      existingImageUrl: existingExample?.audioUrl,
    );
    
    if (isNewExampleImage) {
      updatedExample = await _handleExampleImageUpload(
        vocabularyId, chapterId, wordId, updatedExample, existingExample, newUploadedPaths, pathsToDelete
      );
    } else if (isNewExampleAudio) {
      updatedExample = await _handleExampleAudioUpload(
        vocabularyId, chapterId, wordId, updatedExample, existingExample, newUploadedPaths, pathsToDelete
      );
    } else if ((example.imageUrl == null || example.imageUrl!.isEmpty) &&
              (example.imagePath == null || example.imagePath!.isEmpty) &&
              (example.audioUrl == null || example.audioUrl!.isEmpty) &&
              (example.audioPath == null || example.audioPath!.isEmpty)) {
      if (existingExample?.imagePath != null && existingExample!.imagePath!.isNotEmpty) {
        pathsToDelete.add(existingExample.imagePath!);
      }
      if (existingExample?.audioPath != null && existingExample!.audioPath!.isNotEmpty) {
        pathsToDelete.add(existingExample.audioPath!);
      }
    } else {
      updatedExample = example.copyWith(
        imageUrl: existingExample?.imageUrl ?? example.imageUrl,
        imagePath: existingExample?.imagePath ?? example.imagePath,
        audioUrl: existingExample?.audioUrl ?? example.audioUrl,
        audioPath: existingExample?.audioPath ?? example.audioPath,
      );
    }
    
    return updatedExample;
  }

  Future<WordMeaning> _handleMeaningImageUpload(
    String vocabularyId,
    String chapterId,
    String wordId,
    WordMeaning meaning,
    WordMeaning? existingMeaning,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (meaning.imagePath != null && 
        meaning.imagePath!.startsWith('/') &&
        !_isFirebaseStoragePath(meaning.imagePath!) &&
        !_isCachedFile(meaning.imagePath!)) {
      
      final meaningImageFile = File(meaning.imagePath!);
      if (await meaningImageFile.exists()) {
        try {
          final meaningStoragePath = _getMeaningImagePath(vocabularyId, chapterId, wordId, meaning.id);
          final meaningFileRef = storage.ref().child(meaningStoragePath);
          
          final meaningUploadTask = await meaningFileRef.putFile(
            meaningImageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final meaningDownloadUrl = await meaningUploadTask.ref.getDownloadURL();
          
          if (meaningDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for meaning image');
          }
          
          if (existingMeaning?.imagePath != null && 
              existingMeaning!.imagePath!.isNotEmpty &&
              existingMeaning.imagePath != meaningStoragePath) {
            pathsToDelete.add(existingMeaning.imagePath!);
          }
          
          newUploadedPaths.add(meaningStoragePath);
          return meaning.copyWith(
            imageUrl: meaningDownloadUrl,
            imagePath: meaningStoragePath,
          );
        } catch (e) {
          return meaning.copyWith(
            imageUrl: existingMeaning?.imageUrl,
            imagePath: existingMeaning?.imagePath,
          );
        }
      } else {
        return meaning.copyWith(
          imageUrl: existingMeaning?.imageUrl,
          imagePath: existingMeaning?.imagePath,
        );
      }
    } else {
      return meaning;
    }
  }

  Future<WordMeaning> _handleMeaningAudioUpload(
    String vocabularyId,
    String chapterId,
    String wordId,
    WordMeaning meaning,
    WordMeaning? existingMeaning,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (meaning.audioPath != null && 
        meaning.audioPath!.startsWith('/') &&
        !_isFirebaseStoragePath(meaning.audioPath!) &&
        !_isCachedFile(meaning.audioPath!)) {
      
      final meaningAudioFile = File(meaning.audioPath!);
      if (await meaningAudioFile.exists()) {
        try {
          final extension = _getAudioExtension(meaning.audioPath!);
          final meaningStoragePath = _getMeaningAudioPath(vocabularyId, chapterId, wordId, meaning.id, extension);
          final meaningFileRef = storage.ref().child(meaningStoragePath);
          
          final meaningUploadTask = await meaningFileRef.putFile(
            meaningAudioFile,
            SettableMetadata(contentType: _getAudioContentType(extension))
          );
          
          final meaningDownloadUrl = await meaningUploadTask.ref.getDownloadURL();
          
          if (meaningDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for meaning audio');
          }
          
          if (existingMeaning?.audioPath != null && 
              existingMeaning!.audioPath!.isNotEmpty &&
              existingMeaning.audioPath != meaningStoragePath) {
            pathsToDelete.add(existingMeaning.audioPath!);
          }
          
          newUploadedPaths.add(meaningStoragePath);
          return meaning.copyWith(
            audioUrl: meaningDownloadUrl,
            audioPath: meaningStoragePath,
          );
        } catch (e) {
          return meaning.copyWith(
            audioUrl: existingMeaning?.audioUrl,
            audioPath: existingMeaning?.audioPath,
          );
        }
      } else {
        return meaning.copyWith(
          audioUrl: existingMeaning?.audioUrl,
          audioPath: existingMeaning?.audioPath,
        );
      }
    } else {
      return meaning;
    }
  }

  Future<WordExample> _handleExampleImageUpload(
    String vocabularyId,
    String chapterId,
    String wordId,
    WordExample example,
    WordExample? existingExample,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (example.imagePath != null && 
        example.imagePath!.startsWith('/') &&
        !_isFirebaseStoragePath(example.imagePath!) &&
        !_isCachedFile(example.imagePath!)) {
      
      final exampleImageFile = File(example.imagePath!);
      if (await exampleImageFile.exists()) {
        try {
          final exampleStoragePath = _getExampleImagePath(vocabularyId, chapterId, wordId, example.id);
          final exampleFileRef = storage.ref().child(exampleStoragePath);
          
          final exampleUploadTask = await exampleFileRef.putFile(
            exampleImageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final exampleDownloadUrl = await exampleUploadTask.ref.getDownloadURL();
          
          if (exampleDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for example image');
          }
          
          if (existingExample?.imagePath != null && 
              existingExample!.imagePath!.isNotEmpty &&
              existingExample.imagePath != exampleStoragePath) {
            pathsToDelete.add(existingExample.imagePath!);
          }
          
          newUploadedPaths.add(exampleStoragePath);
          return example.copyWith(
            imageUrl: exampleDownloadUrl,
            imagePath: exampleStoragePath,
          );
        } catch (e) {
          return example.copyWith(
            imageUrl: existingExample?.imageUrl,
            imagePath: existingExample?.imagePath,
          );
        }
      } else {
        return example.copyWith(
          imageUrl: existingExample?.imageUrl,
          imagePath: existingExample?.imagePath,
        );
      }
    } else {
      return example;
    }
  }

  Future<WordExample> _handleExampleAudioUpload(
    String vocabularyId,
    String chapterId,
    String wordId,
    WordExample example,
    WordExample? existingExample,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (example.audioPath != null && 
        example.audioPath!.startsWith('/') &&
        !_isFirebaseStoragePath(example.audioPath!) &&
        !_isCachedFile(example.audioPath!)) {
      
      final exampleAudioFile = File(example.audioPath!);
      if (await exampleAudioFile.exists()) {
        try {
          final extension = _getAudioExtension(example.audioPath!);
          final exampleStoragePath = _getExampleAudioPath(vocabularyId, chapterId, wordId, example.id, extension);
          final exampleFileRef = storage.ref().child(exampleStoragePath);
          
          final exampleUploadTask = await exampleFileRef.putFile(
            exampleAudioFile,
            SettableMetadata(contentType: _getAudioContentType(extension))
          );
          
          final exampleDownloadUrl = await exampleUploadTask.ref.getDownloadURL();
          
          if (exampleDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for example audio');
          }
          
          if (existingExample?.audioPath != null && 
              existingExample!.audioPath!.isNotEmpty &&
              existingExample.audioPath != exampleStoragePath) {
            pathsToDelete.add(existingExample.audioPath!);
          }
          
          newUploadedPaths.add(exampleStoragePath);
          return example.copyWith(
            audioUrl: exampleDownloadUrl,
            audioPath: exampleStoragePath,
          );
        } catch (e) {
          return example.copyWith(
            audioUrl: existingExample?.audioUrl,
            audioPath: existingExample?.audioPath,
          );
        }
      } else {
        return example.copyWith(
          audioUrl: existingExample?.audioUrl,
          audioPath: existingExample?.audioPath,
        );
      }
    } else {
      return example;
    }
  }

  void _handleRemovedChapters(
    VocabularyItem existingVocabulary,
    Set<String> currentChapterIds,
    List<String> pathsToDelete,
  ) {
    for (final existingChapter in existingVocabulary.chapters) {
      if (!currentChapterIds.contains(existingChapter.id)) {
        if (existingChapter.imagePath != null && 
            existingChapter.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingChapter.imagePath!);
        }
        
        for (final word in existingChapter.words) {
          if (word.imagePath != null && word.imagePath!.isNotEmpty) {
            pathsToDelete.add(word.imagePath!);
          }
          if (word.audioPath != null && word.audioPath!.isNotEmpty) {
            pathsToDelete.add(word.audioPath!);
          }
          
          for (final meaning in word.meanings) {
            if (meaning.imagePath != null && meaning.imagePath!.isNotEmpty) {
              pathsToDelete.add(meaning.imagePath!);
            }
            if (meaning.audioPath != null && meaning.audioPath!.isNotEmpty) {
              pathsToDelete.add(meaning.audioPath!);
            }
          }
          
          for (final example in word.examples) {
            if (example.imagePath != null && example.imagePath!.isNotEmpty) {
              pathsToDelete.add(example.imagePath!);
            }
            if (example.audioPath != null && example.audioPath!.isNotEmpty) {
              pathsToDelete.add(example.audioPath!);
            }
          }
        }
      }
    }
  }

  void _handleRemovedWords(
    String vocabularyId,
    String chapterId,
    VocabularyChapter existingChapter,
    Set<String> currentWordIds,
    List<String> pathsToDelete,
  ) {
    for (final existingWord in existingChapter.words) {
      if (!currentWordIds.contains(existingWord.id)) {
        if (existingWord.imagePath != null && existingWord.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingWord.imagePath!);
        }
        if (existingWord.audioPath != null && existingWord.audioPath!.isNotEmpty) {
          pathsToDelete.add(existingWord.audioPath!);
        }
        
        for (final meaning in existingWord.meanings) {
          if (meaning.imagePath != null && meaning.imagePath!.isNotEmpty) {
            pathsToDelete.add(meaning.imagePath!);
          }
          if (meaning.audioPath != null && meaning.audioPath!.isNotEmpty) {
            pathsToDelete.add(meaning.audioPath!);
          }
        }
        
        for (final example in existingWord.examples) {
          if (example.imagePath != null && example.imagePath!.isNotEmpty) {
            pathsToDelete.add(example.imagePath!);
          }
          if (example.audioPath != null && example.audioPath!.isNotEmpty) {
            pathsToDelete.add(example.audioPath!);
          }
        }
      }
    }
  }

  void _handleRemovedMeanings(
    String vocabularyId,
    String chapterId,
    String wordId,
    VocabularyWord existingWord,
    Set<String> currentMeaningIds,
    List<String> pathsToDelete,
  ) {
    for (final existingMeaning in existingWord.meanings) {
      if (!currentMeaningIds.contains(existingMeaning.id)) {
        if (existingMeaning.imagePath != null && existingMeaning.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingMeaning.imagePath!);
        }
        if (existingMeaning.audioPath != null && existingMeaning.audioPath!.isNotEmpty) {
          pathsToDelete.add(existingMeaning.audioPath!);
        }
      }
    }
  }

  void _handleRemovedExamples(
    String vocabularyId,
    String chapterId,
    String wordId,
    VocabularyWord existingWord,
    Set<String> currentExampleIds,
    List<String> pathsToDelete,
  ) {
    for (final existingExample in existingWord.examples) {
      if (!currentExampleIds.contains(existingExample.id)) {
        if (existingExample.imagePath != null && existingExample.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingExample.imagePath!);
        }
        if (existingExample.audioPath != null && existingExample.audioPath!.isNotEmpty) {
          pathsToDelete.add(existingExample.audioPath!);
        }
      }
    }
  }

  Future<void> _saveUpdatedVocabulary(
    WriteBatch batch,
    DocumentReference docRef,
    VocabularyItem finalVocabulary,
  ) async {
    final updateData = finalVocabulary.toJson();
    updateData['titleLowerCase'] = finalVocabulary.title.toLowerCase();
    updateData['descriptionLowerCase'] = finalVocabulary.description.toLowerCase();
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    batch.update(docRef, updateData);
    await batch.commit();
  }

  bool _isNewMedia({
    required String? currentImagePath,
    required String? currentImageUrl,
    required String? existingImagePath,
    required String? existingImageUrl,
  }) {
    if ((currentImagePath == null || currentImagePath.isEmpty) &&
        (currentImageUrl == null || currentImageUrl.isEmpty)) {
      return false;
    }
    
    if ((existingImagePath == null || existingImagePath.isEmpty) &&
        (existingImageUrl == null || existingImageUrl.isEmpty)) {
      return true;
    }
    
    if (currentImagePath != null && 
        currentImagePath.startsWith('/') && 
        !_isFirebaseStoragePath(currentImagePath) &&
        !_isCachedFile(currentImagePath)) {
      try {
        final file = File(currentImagePath);
        if (file.existsSync()) {
          if (kDebugMode) {
            print('Detected new local media file: $currentImagePath');
          }
          return true;
        } else {
          if (kDebugMode) {
            print('Local media file does not exist: $currentImagePath');
          }
          return false;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error checking file existence for $currentImagePath: $e');
        }
        return false;
      }
    }
    
    if (currentImageUrl != null && existingImageUrl != null) {
      return currentImageUrl != existingImageUrl;
    }
    
    if (currentImagePath != null && existingImagePath != null) {
      return currentImagePath != existingImagePath;
    }
    
    if ((currentImageUrl != null && existingImagePath != null) ||
        (currentImagePath != null && existingImageUrl != null)) {
      return true;
    }
    
    return false;
  }

  @override
  Future<bool> deleteVocabulary(String vocabularyId) async {
    final batch = firestore.batch();
    final docRef = firestore.collection(vocabulariesCollection).doc(vocabularyId);
    
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Vocabulary not found');
    }
    
    final data = docSnapshot.data() as Map<String, dynamic>;
    final pathsToDelete = <String>[];
    
    try {
      if (data.containsKey('imagePath') && data['imagePath'] != null) {
        pathsToDelete.add(data['imagePath'] as String);
      }
      
      if (data.containsKey('pdfPaths') && data['pdfPaths'] is List) {
        final pdfPaths = data['pdfPaths'] as List;
        for (final pdfPath in pdfPaths) {
          if (pdfPath is String && pdfPath.isNotEmpty) {
            pathsToDelete.add(pdfPath);
          }
        }
      }
      
      if (data.containsKey('chapters') && data['chapters'] is List) {
        final chapters = data['chapters'] as List;
        for (final chapterData in chapters) {
          if (chapterData is Map<String, dynamic>) {
            if (chapterData.containsKey('imagePath') && chapterData['imagePath'] != null) {
              pathsToDelete.add(chapterData['imagePath'] as String);
            }
            
            if (chapterData.containsKey('words') && chapterData['words'] is List) {
              final words = chapterData['words'] as List;
              for (final wordData in words) {
                if (wordData is Map<String, dynamic>) {
                  if (wordData.containsKey('imagePath') && wordData['imagePath'] != null) {
                    pathsToDelete.add(wordData['imagePath'] as String);
                  }
                  if (wordData.containsKey('audioPath') && wordData['audioPath'] != null) {
                    pathsToDelete.add(wordData['audioPath'] as String);
                  }
                  
                  if (wordData.containsKey('meanings') && wordData['meanings'] is List) {
                    final meanings = wordData['meanings'] as List;
                    for (final meaningData in meanings) {
                      if (meaningData is Map<String, dynamic>) {
                        if (meaningData.containsKey('imagePath') && meaningData['imagePath'] != null) {
                          pathsToDelete.add(meaningData['imagePath'] as String);
                        }
                        if (meaningData.containsKey('audioPath') && meaningData['audioPath'] != null) {
                          pathsToDelete.add(meaningData['audioPath'] as String);
                        }
                      }
                    }
                  }
                  
                  if (wordData.containsKey('examples') && wordData['examples'] is List) {
                    final examples = wordData['examples'] as List;
                    for (final exampleData in examples) {
                      if (exampleData is Map<String, dynamic>) {
                        if (exampleData.containsKey('imagePath') && exampleData['imagePath'] != null) {
                          pathsToDelete.add(exampleData['imagePath'] as String);
                        }
                        if (exampleData.containsKey('audioPath') && exampleData['audioPath'] != null) {
                          pathsToDelete.add(exampleData['audioPath'] as String);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      await _cleanupFiles(pathsToDelete);
      
      batch.delete(docRef);
      await batch.commit();
      
      return true;
      
    } on FirebaseException catch (e) {
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      throw Exception('Failed to delete vocabulary: $e');
    }
  }

  @override
  Future<DateTime?> getVocabularyLastUpdated(String vocabularyId) async {
    try {
      final docSnapshot = await firestore.collection(vocabulariesCollection).doc(vocabularyId).get();
      
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
      throw Exception('Failed to get vocabulary last updated: $e');
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
          (path.contains('vocabularies_images_cache') || 
            path.contains('vocabularies_audio_cache') ||
            path.contains('vocabularies_pdfs_cache'));
  }

  bool _isFirebaseStoragePath(String path) {
    return path.startsWith('$_vocabulariesStorageRoot/') && 
          (path.contains('.jpg') || 
            path.contains('.jpeg') ||
            path.contains('.png') ||
            path.contains('.m4a') ||
            path.contains('.mp3') ||
            path.contains('.wav') ||
            path.contains('.aac') ||
            path.contains('.pdf'));
  }
}