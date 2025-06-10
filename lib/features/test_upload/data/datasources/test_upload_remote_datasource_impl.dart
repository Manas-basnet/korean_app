import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/test_upload/data/datasources/test_upload_remote_datasource.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';
import 'package:korean_language_app/core/shared/models/test_question.dart';
import 'package:korean_language_app/core/enums/question_type.dart';

class FirestoreTestUploadDataSourceImpl implements TestUploadRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final String testsCollection = 'tests';

  FirestoreTestUploadDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  @override
  Future<TestItem> uploadTest(TestItem test, {File? imageFile}) async {
    if (test.title.isEmpty || test.description.isEmpty || test.questions.isEmpty) {
      throw ArgumentError('Test title, description, and questions cannot be empty');
    }

    final batch = firestore.batch();
    final docRef = test.id.isEmpty 
        ? firestore.collection(testsCollection).doc() 
        : firestore.collection(testsCollection).doc(test.id);
    
    final testId = docRef.id;
    var finalTest = test.copyWith(id: testId);
    final uploadedPaths = <String>[];

    try {
      if (imageFile != null) {
        final storagePath = 'tests/$testId/cover_image.jpg';
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
        finalTest = finalTest.copyWith(
          imageUrl: downloadUrl,
          imagePath: storagePath,
        );
      }
      
      final updatedQuestions = <TestQuestion>[];
      for (final question in finalTest.questions) {
        var updatedQuestion = question;
        
        if (question.questionImagePath != null && 
            question.questionImagePath!.startsWith('/') && 
            File(question.questionImagePath!).existsSync()) {
          
          final questionImageFile = File(question.questionImagePath!);
          final questionStoragePath = 'tests/$testId/questions/${question.id}/question_image.jpg';
          final questionFileRef = storage.ref().child(questionStoragePath);
          
          final questionUploadTask = await questionFileRef.putFile(
            questionImageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final questionDownloadUrl = await questionUploadTask.ref.getDownloadURL();
          
          if (questionDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for question image');
          }
          
          uploadedPaths.add(questionStoragePath);
          updatedQuestion = updatedQuestion.copyWith(
            questionImageUrl: questionDownloadUrl,
            questionImagePath: questionStoragePath,
          );
        }

        if (question.questionAudioPath != null && 
            question.questionAudioPath!.startsWith('/') && 
            File(question.questionAudioPath!).existsSync()) {
          
          final questionAudioFile = File(question.questionAudioPath!);
          final extension = _getAudioExtension(question.questionAudioPath!);
          final questionStoragePath = 'tests/$testId/questions/${question.id}/question_audio$extension';
          final questionFileRef = storage.ref().child(questionStoragePath);
          
          final questionUploadTask = await questionFileRef.putFile(
            questionAudioFile,
            SettableMetadata(contentType: _getAudioContentType(extension))
          );
          
          final questionDownloadUrl = await questionUploadTask.ref.getDownloadURL();
          
          if (questionDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for question audio');
          }
          
          uploadedPaths.add(questionStoragePath);
          updatedQuestion = updatedQuestion.copyWith(
            questionAudioUrl: questionDownloadUrl,
            questionAudioPath: questionStoragePath,
          );
        }
        
        final updatedOptions = <AnswerOption>[];
        for (int i = 0; i < question.options.length; i++) {
          final option = question.options[i];
          
          if (option.isImage && 
              option.imagePath != null && 
              option.imagePath!.startsWith('/') && 
              File(option.imagePath!).existsSync()) {
            
            final answerImageFile = File(option.imagePath!);
            final answerStoragePath = 'tests/$testId/questions/${question.id}/answers/$i.jpg';
            final answerFileRef = storage.ref().child(answerStoragePath);
            
            final answerUploadTask = await answerFileRef.putFile(
              answerImageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final answerDownloadUrl = await answerUploadTask.ref.getDownloadURL();
            
            if (answerDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for answer image');
            }
            
            uploadedPaths.add(answerStoragePath);
            updatedOptions.add(option.copyWith(
              imageUrl: answerDownloadUrl,
              imagePath: answerStoragePath,
            ));
          } else if (option.isAudio && 
              option.audioPath != null && 
              option.audioPath!.startsWith('/') && 
              File(option.audioPath!).existsSync()) {
            
            final answerAudioFile = File(option.audioPath!);
            final extension = _getAudioExtension(option.audioPath!);
            final answerStoragePath = 'tests/$testId/questions/${question.id}/answers/$i$extension';
            final answerFileRef = storage.ref().child(answerStoragePath);
            
            final answerUploadTask = await answerFileRef.putFile(
              answerAudioFile,
              SettableMetadata(contentType: _getAudioContentType(extension))
            );
            
            final answerDownloadUrl = await answerUploadTask.ref.getDownloadURL();
            
            if (answerDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for answer audio');
            }
            
            uploadedPaths.add(answerStoragePath);
            updatedOptions.add(option.copyWith(
              audioUrl: answerDownloadUrl,
              audioPath: answerStoragePath,
            ));
          } else {
            updatedOptions.add(option);
          }
        }
        
        updatedQuestion = updatedQuestion.copyWith(options: updatedOptions);
        updatedQuestions.add(updatedQuestion);
      }
      
      finalTest = finalTest.copyWith(questions: updatedQuestions);
      
      final testData = finalTest.toJson();
      testData['titleLowerCase'] = finalTest.title.toLowerCase();
      testData['descriptionLowerCase'] = finalTest.description.toLowerCase();
      testData['createdAt'] = FieldValue.serverTimestamp();
      testData['updatedAt'] = FieldValue.serverTimestamp();
      
      batch.set(docRef, testData);
      await batch.commit();
      
      return finalTest.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
    } on FirebaseException catch (e) {
      await _cleanupFiles(uploadedPaths);
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      await _cleanupFiles(uploadedPaths);
      throw Exception('Failed to upload test: $e');
    }
  }

  @override
  Future<TestItem> updateTest(String testId, TestItem updatedTest, {File? imageFile}) async {
    final batch = firestore.batch();
    final docRef = firestore.collection(testsCollection).doc(testId);
    
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Test not found');
    }
    
    final existingData = docSnapshot.data() as Map<String, dynamic>;
    final existingTest = TestItem.fromJson({...existingData, 'id': testId});
    
    var finalTest = updatedTest;
    final newUploadedPaths = <String>[];
    final pathsToDelete = <String>[];
    
    try {
      if (imageFile != null) {
        if (existingTest.imagePath != null && existingTest.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingTest.imagePath!);
        }
        
        final storagePath = 'tests/$testId/cover_image.jpg';
        final fileRef = storage.ref().child(storagePath);
        
        final uploadTask = await fileRef.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg')
        );
        
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        
        if (downloadUrl.isEmpty) {
          throw Exception('Failed to get download URL for uploaded cover image');
        }
        
        newUploadedPaths.add(storagePath);
        finalTest = finalTest.copyWith(
          imageUrl: downloadUrl,
          imagePath: storagePath,
        );
      } else if ((finalTest.imageUrl == null || finalTest.imageUrl!.isEmpty) &&
                (finalTest.imagePath == null || finalTest.imagePath!.isEmpty)) {
        if (existingTest.imagePath != null && existingTest.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingTest.imagePath!);
        }
      }
      
      final existingQuestionsMap = <String, TestQuestion>{};
      for (final q in existingTest.questions) {
        existingQuestionsMap[q.id] = q;
      }
      
      final updatedQuestions = <TestQuestion>[];
      final currentQuestionIds = <String>{};
      
      for (final question in finalTest.questions) {
        currentQuestionIds.add(question.id);
        var updatedQuestion = question;
        final existingQuestion = existingQuestionsMap[question.id];
        
        bool isNewQuestionImage = _isNewLocalFile(
          question.questionImagePath, 
          existingQuestion?.questionImagePath
        );
        
        bool isNewQuestionAudio = _isNewLocalFile(
          question.questionAudioPath, 
          existingQuestion?.questionAudioPath
        );
        
        if (isNewQuestionImage) {
          if (existingQuestion?.questionImagePath != null && 
              existingQuestion!.questionImagePath!.isNotEmpty) {
            pathsToDelete.add(existingQuestion.questionImagePath!);
          }
          
          final questionImageFile = File(question.questionImagePath!);
          final questionStoragePath = 'tests/$testId/questions/${question.id}/question_image.jpg';
          final questionFileRef = storage.ref().child(questionStoragePath);
          
          final questionUploadTask = await questionFileRef.putFile(
            questionImageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final questionDownloadUrl = await questionUploadTask.ref.getDownloadURL();
          
          if (questionDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for question image');
          }
          
          newUploadedPaths.add(questionStoragePath);
          updatedQuestion = updatedQuestion.copyWith(
            questionImageUrl: questionDownloadUrl,
            questionImagePath: questionStoragePath,
          );
        } else if ((question.questionImageUrl == null || question.questionImageUrl!.isEmpty) &&
                  (question.questionImagePath == null || question.questionImagePath!.isEmpty) &&
                  existingQuestion?.questionImagePath != null && 
                  existingQuestion!.questionImagePath!.isNotEmpty) {
          pathsToDelete.add(existingQuestion.questionImagePath!);
        }

        if (isNewQuestionAudio) {
          if (existingQuestion?.questionAudioPath != null && 
              existingQuestion!.questionAudioPath!.isNotEmpty) {
            pathsToDelete.add(existingQuestion.questionAudioPath!);
          }
          
          final questionAudioFile = File(question.questionAudioPath!);
          final extension = _getAudioExtension(question.questionAudioPath!);
          final questionStoragePath = 'tests/$testId/questions/${question.id}/question_audio$extension';
          final questionFileRef = storage.ref().child(questionStoragePath);
          
          final questionUploadTask = await questionFileRef.putFile(
            questionAudioFile,
            SettableMetadata(contentType: _getAudioContentType(extension))
          );
          
          final questionDownloadUrl = await questionUploadTask.ref.getDownloadURL();
          
          if (questionDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for question audio');
          }
          
          newUploadedPaths.add(questionStoragePath);
          updatedQuestion = updatedQuestion.copyWith(
            questionAudioUrl: questionDownloadUrl,
            questionAudioPath: questionStoragePath,
          );
        } else if ((question.questionAudioUrl == null || question.questionAudioUrl!.isEmpty) &&
                  (question.questionAudioPath == null || question.questionAudioPath!.isEmpty) &&
                  existingQuestion?.questionAudioPath != null && 
                  existingQuestion!.questionAudioPath!.isNotEmpty) {
          pathsToDelete.add(existingQuestion.questionAudioPath!);
        }
        
        final updatedOptions = <AnswerOption>[];
        for (int i = 0; i < question.options.length; i++) {
          final option = question.options[i];
          final existingOption = existingQuestion != null && i < existingQuestion.options.length 
              ? existingQuestion.options[i] 
              : null;
          
          bool isNewAnswerImage = _isNewLocalFile(
            option.imagePath, 
            existingOption?.imagePath
          );

          bool isNewAnswerAudio = _isNewLocalFile(
            option.audioPath, 
            existingOption?.audioPath
          );
          
          if (isNewAnswerImage) {
            if (existingOption?.imagePath != null && existingOption!.imagePath!.isNotEmpty) {
              pathsToDelete.add(existingOption.imagePath!);
            }
            
            final answerImageFile = File(option.imagePath!);
            final answerStoragePath = 'tests/$testId/questions/${question.id}/answers/$i.jpg';
            final answerFileRef = storage.ref().child(answerStoragePath);
            
            final answerUploadTask = await answerFileRef.putFile(
              answerImageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final answerDownloadUrl = await answerUploadTask.ref.getDownloadURL();
            
            if (answerDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for answer image');
            }
            
            newUploadedPaths.add(answerStoragePath);
            updatedOptions.add(option.copyWith(
              imageUrl: answerDownloadUrl,
              imagePath: answerStoragePath,
            ));
          } else if (isNewAnswerAudio) {
            if (existingOption?.audioPath != null && existingOption!.audioPath!.isNotEmpty) {
              pathsToDelete.add(existingOption.audioPath!);
            }
            
            final answerAudioFile = File(option.audioPath!);
            final extension = _getAudioExtension(option.audioPath!);
            final answerStoragePath = 'tests/$testId/questions/${question.id}/answers/$i$extension';
            final answerFileRef = storage.ref().child(answerStoragePath);
            
            final answerUploadTask = await answerFileRef.putFile(
              answerAudioFile,
              SettableMetadata(contentType: _getAudioContentType(extension))
            );
            
            final answerDownloadUrl = await answerUploadTask.ref.getDownloadURL();
            
            if (answerDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for answer audio');
            }
            
            newUploadedPaths.add(answerStoragePath);
            updatedOptions.add(option.copyWith(
              audioUrl: answerDownloadUrl,
              audioPath: answerStoragePath,
            ));
          } else if (!option.isImage && !option.isAudio && 
                    existingOption?.isImage == true && 
                    existingOption?.imagePath != null && 
                    existingOption!.imagePath!.isNotEmpty) {
            pathsToDelete.add(existingOption.imagePath!);
            updatedOptions.add(option);
          } else if (!option.isImage && !option.isAudio && 
                    existingOption?.isAudio == true && 
                    existingOption?.audioPath != null && 
                    existingOption!.audioPath!.isNotEmpty) {
            pathsToDelete.add(existingOption.audioPath!);
            updatedOptions.add(option);
          } else if ((option.isImage && 
                    (option.imageUrl == null || option.imageUrl!.isEmpty) &&
                    (option.imagePath == null || option.imagePath!.isEmpty) &&
                    existingOption?.isImage == true &&
                    existingOption?.imagePath != null &&
                    existingOption!.imagePath!.isNotEmpty) ||
                   (option.isAudio && 
                    (option.audioUrl == null || option.audioUrl!.isEmpty) &&
                    (option.audioPath == null || option.audioPath!.isEmpty) &&
                    existingOption?.isAudio == true &&
                    existingOption?.audioPath != null &&
                    existingOption!.audioPath!.isNotEmpty)) {
            if (existingOption.imagePath != null && existingOption.imagePath!.isNotEmpty) {
              pathsToDelete.add(existingOption.imagePath!);
            }
            if (existingOption.audioPath != null && existingOption.audioPath!.isNotEmpty) {
              pathsToDelete.add(existingOption.audioPath!);
            }
            updatedOptions.add(option);
          } else {
            updatedOptions.add(option);
          }
        }

        if (existingQuestion != null) {
          for (int i = question.options.length; i < existingQuestion.options.length; i++) {
            final removedOption = existingQuestion.options[i];
            if (removedOption.isImage && 
                removedOption.imagePath != null && 
                removedOption.imagePath!.isNotEmpty) {
              pathsToDelete.add(removedOption.imagePath!);
            }
            if (removedOption.isAudio && 
                removedOption.audioPath != null && 
                removedOption.audioPath!.isNotEmpty) {
              pathsToDelete.add(removedOption.audioPath!);
            }
          }
        }
        
        updatedQuestion = updatedQuestion.copyWith(options: updatedOptions);
        updatedQuestions.add(updatedQuestion);
      }
      
      for (final existingQuestion in existingTest.questions) {
        if (!currentQuestionIds.contains(existingQuestion.id)) {
          if (existingQuestion.questionImagePath != null && 
              existingQuestion.questionImagePath!.isNotEmpty) {
            pathsToDelete.add(existingQuestion.questionImagePath!);
          }
          if (existingQuestion.questionAudioPath != null && 
              existingQuestion.questionAudioPath!.isNotEmpty) {
            pathsToDelete.add(existingQuestion.questionAudioPath!);
          }
          
          for (final option in existingQuestion.options) {
            if (option.isImage && 
                option.imagePath != null && 
                option.imagePath!.isNotEmpty) {
              pathsToDelete.add(option.imagePath!);
            }
            if (option.isAudio && 
                option.audioPath != null && 
                option.audioPath!.isNotEmpty) {
              pathsToDelete.add(option.audioPath!);
            }
          }
        }
      }
      
      finalTest = finalTest.copyWith(questions: updatedQuestions);
      
      final updateData = finalTest.toJson();
      updateData['titleLowerCase'] = finalTest.title.toLowerCase();
      updateData['descriptionLowerCase'] = finalTest.description.toLowerCase();
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      batch.update(docRef, updateData);
      await batch.commit();
      
      if (pathsToDelete.isNotEmpty) {
        if (kDebugMode) {
          print('Deleting ${pathsToDelete.length} replaced/removed files: $pathsToDelete');
        }
        await _cleanupFiles(pathsToDelete);
      }
      
      return finalTest.copyWith(updatedAt: DateTime.now());
      
    } on FirebaseException catch (e) {
      await _cleanupFiles(newUploadedPaths);
      throw ExceptionMapper.mapFirebaseException(e);
    } catch (e) {
      await _cleanupFiles(newUploadedPaths);
      throw Exception('Failed to update test: $e');
    }
  }

  @override
  Future<bool> deleteTest(String testId) async {
    final batch = firestore.batch();
    final docRef = firestore.collection(testsCollection).doc(testId);
    
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Test not found');
    }
    
    final data = docSnapshot.data() as Map<String, dynamic>;
    final pathsToDelete = <String>[];
    
    try {
      if (data.containsKey('imagePath') && data['imagePath'] != null) {
        pathsToDelete.add(data['imagePath'] as String);
      }
      
      if (data.containsKey('questions') && data['questions'] is List) {
        final questions = data['questions'] as List;
        for (final questionData in questions) {
          if (questionData is Map<String, dynamic>) {
            if (questionData.containsKey('questionImagePath') && questionData['questionImagePath'] != null) {
              pathsToDelete.add(questionData['questionImagePath'] as String);
            }
            if (questionData.containsKey('questionAudioPath') && questionData['questionAudioPath'] != null) {
              pathsToDelete.add(questionData['questionAudioPath'] as String);
            }
            
            if (questionData.containsKey('options') && questionData['options'] is List) {
              final options = questionData['options'] as List;
              for (final option in options) {
                if (option is Map<String, dynamic>) {
                  if (option.containsKey('imagePath') && option['imagePath'] != null) {
                    pathsToDelete.add(option['imagePath'] as String);
                  }
                  if (option.containsKey('audioPath') && option['audioPath'] != null) {
                    pathsToDelete.add(option['audioPath'] as String);
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
      throw Exception('Failed to delete test: $e');
    }
  }

  @override
  Future<DateTime?> getTestLastUpdated(String testId) async {
    try {
      final docSnapshot = await firestore.collection(testsCollection).doc(testId).get();
      
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
      throw Exception('Failed to get test last updated: $e');
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

  bool _isNewLocalFile(String? currentPath, String? existingStoragePath) {
    if (currentPath == null || currentPath.isEmpty) {
      return false;
    }
    
    if (!File(currentPath).existsSync()) {
      return false;
    }
    
    if (existingStoragePath == null || existingStoragePath.isEmpty) {
      return true;
    }
    
    if (currentPath == existingStoragePath) {
      return false;
    }
    
    if (existingStoragePath.startsWith('tests/') && 
        (existingStoragePath.contains('.jpg') || 
         existingStoragePath.contains('.m4a') ||
         existingStoragePath.contains('.mp3') ||
         existingStoragePath.contains('.wav') ||
         existingStoragePath.contains('.aac'))) {
      return true;
    }
    
    if (currentPath.startsWith('/') && existingStoragePath.startsWith('/')) {
      return currentPath != existingStoragePath;
    }
    
    return false;
  }
}