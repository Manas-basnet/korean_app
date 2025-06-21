import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/test_upload/data/datasources/test_upload_remote_datasource.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/models/test_question.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';

class FirestoreTestUploadDataSourceImpl implements TestUploadRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final String testsCollection = 'tests';
  
  static const String _testsStorageRoot = 'tests';
  static const String _coverImageFilename = 'cover_image.jpg';
  static const String _questionImageFilename = 'question_image.jpg';
  static const String _questionAudioFilename = 'question_audio';
  static const String _questionsFolder = 'questions';
  static const String _answersFolder = 'answers';

  FirestoreTestUploadDataSourceImpl({
    required this.firestore,
    required this.storage,
  });

  String _getCoverImagePath(String testId) {
    return '$_testsStorageRoot/$testId/$_coverImageFilename';
  }

  String _getQuestionImagePath(String testId, String questionId) {
    return '$_testsStorageRoot/$testId/$_questionsFolder/$questionId/$_questionImageFilename';
  }

  String _getQuestionAudioPath(String testId, String questionId, String extension) {
    return '$_testsStorageRoot/$testId/$_questionsFolder/$questionId/$_questionAudioFilename$extension';
  }

  String _getAnswerImagePath(String testId, String questionId, int optionIndex) {
    return '$_testsStorageRoot/$testId/$_questionsFolder/$questionId/$_answersFolder/$optionIndex.jpg';
  }

  String _getAnswerAudioPath(String testId, String questionId, int optionIndex, String extension) {
    return '$_testsStorageRoot/$testId/$_questionsFolder/$questionId/$_answersFolder/$optionIndex$extension';
  }

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
        final storagePath = _getCoverImagePath(testId);
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
          final questionStoragePath = _getQuestionImagePath(testId, question.id);
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
          final questionStoragePath = _getQuestionAudioPath(testId, question.id, extension);
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
            final answerStoragePath = _getAnswerImagePath(testId, question.id, i);
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
            final answerStoragePath = _getAnswerAudioPath(testId, question.id, i, extension);
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
      finalTest = await _handleCoverImageUpdate(
        testId, finalTest, existingTest, imageFile, newUploadedPaths, pathsToDelete
      );
      
      final updatedQuestions = await _handleQuestionsUpdate(
        testId, finalTest, existingTest, newUploadedPaths, pathsToDelete
      );
      
      finalTest = finalTest.copyWith(questions: updatedQuestions);
      
      await _saveUpdatedTest(batch, docRef, finalTest);
      
      if (pathsToDelete.isNotEmpty) {
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

  Future<TestItem> _handleCoverImageUpdate(
    String testId,
    TestItem finalTest,
    TestItem existingTest,
    File? imageFile,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (imageFile != null) {
      if (await imageFile.exists()) {
        try {
          final storagePath = _getCoverImagePath(testId);
          final fileRef = storage.ref().child(storagePath);
          
          final uploadTask = await fileRef.putFile(
            imageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          
          if (downloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for uploaded cover image');
          }
          
          if (existingTest.imagePath != null && 
              existingTest.imagePath!.isNotEmpty &&
              existingTest.imagePath != storagePath) {
            pathsToDelete.add(existingTest.imagePath!);
          }
          
          newUploadedPaths.add(storagePath);
          return finalTest.copyWith(
            imageUrl: downloadUrl,
            imagePath: storagePath,
          );
        } catch (e) {
          return finalTest.copyWith(
            imageUrl: existingTest.imageUrl,
            imagePath: existingTest.imagePath,
          );
        }
      } else {
        return finalTest.copyWith(
          imageUrl: existingTest.imageUrl,
          imagePath: existingTest.imagePath,
        );
      }
    } else if ((finalTest.imageUrl == null || finalTest.imageUrl!.isEmpty) &&
              (finalTest.imagePath == null || finalTest.imagePath!.isEmpty)) {
      if (existingTest.imagePath != null && existingTest.imagePath!.isNotEmpty) {
        pathsToDelete.add(existingTest.imagePath!);
      }
      return finalTest;
    } else {
      return finalTest.copyWith(
        imageUrl: existingTest.imageUrl,
        imagePath: existingTest.imagePath,
      );
    }
  }

  Future<List<TestQuestion>> _handleQuestionsUpdate(
    String testId,
    TestItem finalTest,
    TestItem existingTest,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final existingQuestionsMap = <String, TestQuestion>{};
    for (final q in existingTest.questions) {
      existingQuestionsMap[q.id] = q;
    }
    
    final updatedQuestions = <TestQuestion>[];
    final currentQuestionIds = <String>{};
    
    for (final question in finalTest.questions) {
      currentQuestionIds.add(question.id);
      final existingQuestion = existingQuestionsMap[question.id];
      
      final updatedQuestion = await _handleSingleQuestionUpdate(
        testId, question, existingQuestion, newUploadedPaths, pathsToDelete
      );
      
      updatedQuestions.add(updatedQuestion);
    }
    
    _handleRemovedQuestions(existingTest, currentQuestionIds, pathsToDelete);
    
    return updatedQuestions;
  }

  Future<TestQuestion> _handleSingleQuestionUpdate(
    String testId,
    TestQuestion question,
    TestQuestion? existingQuestion,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    var updatedQuestion = question;
    
    updatedQuestion = await _handleQuestionImageUpdate(
      testId, updatedQuestion, existingQuestion, newUploadedPaths, pathsToDelete
    );
    
    updatedQuestion = await _handleQuestionAudioUpdate(
      testId, updatedQuestion, existingQuestion, newUploadedPaths, pathsToDelete
    );
    
    final updatedOptions = await _handleAnswerOptionsUpdate(
      testId, question, existingQuestion, newUploadedPaths, pathsToDelete
    );
    
    return updatedQuestion.copyWith(options: updatedOptions);
  }

  Future<TestQuestion> _handleQuestionImageUpdate(
    String testId,
    TestQuestion question,
    TestQuestion? existingQuestion,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewQuestionImage = _isNewMedia(
      currentImagePath: question.questionImagePath,
      currentImageUrl: question.questionImageUrl,
      existingImagePath: existingQuestion?.questionImagePath,
      existingImageUrl: existingQuestion?.questionImageUrl,
    );
    
    if (isNewQuestionImage) {
      if (question.questionImagePath != null && 
          question.questionImagePath!.startsWith('/') &&
          !_isFirebaseStoragePath(question.questionImagePath!) &&
          !_isCachedFile(question.questionImagePath!)) {
        
        final questionImageFile = File(question.questionImagePath!);
        if (await questionImageFile.exists()) {
          try {
            final questionStoragePath = _getQuestionImagePath(testId, question.id);
            final questionFileRef = storage.ref().child(questionStoragePath);
            
            final questionUploadTask = await questionFileRef.putFile(
              questionImageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            final questionDownloadUrl = await questionUploadTask.ref.getDownloadURL();
            
            if (questionDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for question image');
            }
            
            if (existingQuestion?.questionImagePath != null && 
                existingQuestion!.questionImagePath!.isNotEmpty &&
                existingQuestion.questionImagePath != questionStoragePath) {
              pathsToDelete.add(existingQuestion.questionImagePath!);
            }
            
            newUploadedPaths.add(questionStoragePath);
            return question.copyWith(
              questionImageUrl: questionDownloadUrl,
              questionImagePath: questionStoragePath,
            );
          } catch (e) {
            return question.copyWith(
              questionImageUrl: existingQuestion?.questionImageUrl,
              questionImagePath: existingQuestion?.questionImagePath,
            );
          }
        } else {
          return question.copyWith(
            questionImageUrl: existingQuestion?.questionImageUrl,
            questionImagePath: existingQuestion?.questionImagePath,
          );
        }
      }
      return question;
    } else if ((question.questionImageUrl == null || question.questionImageUrl!.isEmpty) &&
              (question.questionImagePath == null || question.questionImagePath!.isEmpty) &&
              existingQuestion?.questionImagePath != null && 
              existingQuestion!.questionImagePath!.isNotEmpty) {
      pathsToDelete.add(existingQuestion.questionImagePath!);
      return question;
    } else {
      return question.copyWith(
        questionImageUrl: existingQuestion?.questionImageUrl,
        questionImagePath: existingQuestion?.questionImagePath,
      );
    }
  }

  Future<TestQuestion> _handleQuestionAudioUpdate(
    String testId,
    TestQuestion question,
    TestQuestion? existingQuestion,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewQuestionAudio = _isNewMedia(
      currentImagePath: question.questionAudioPath,
      currentImageUrl: question.questionAudioUrl,
      existingImagePath: existingQuestion?.questionAudioPath,
      existingImageUrl: existingQuestion?.questionAudioUrl,
    );
    
    if (isNewQuestionAudio) {
      if (question.questionAudioPath != null && 
          question.questionAudioPath!.startsWith('/') &&
          !_isFirebaseStoragePath(question.questionAudioPath!) &&
          !_isCachedFile(question.questionAudioPath!)) {
        
        final questionAudioFile = File(question.questionAudioPath!);
        if (await questionAudioFile.exists()) {
          try {
            final extension = _getAudioExtension(question.questionAudioPath!);
            final questionStoragePath = _getQuestionAudioPath(testId, question.id, extension);
            final questionFileRef = storage.ref().child(questionStoragePath);
            
            final questionUploadTask = await questionFileRef.putFile(
              questionAudioFile,
              SettableMetadata(contentType: _getAudioContentType(extension))
            );
            
            final questionDownloadUrl = await questionUploadTask.ref.getDownloadURL();
            
            if (questionDownloadUrl.isEmpty) {
              throw Exception('Failed to get download URL for question audio');
            }
            
            if (existingQuestion?.questionAudioPath != null && 
                existingQuestion!.questionAudioPath!.isNotEmpty &&
                existingQuestion.questionAudioPath != questionStoragePath) {
              pathsToDelete.add(existingQuestion.questionAudioPath!);
            }
            
            newUploadedPaths.add(questionStoragePath);
            return question.copyWith(
              questionAudioUrl: questionDownloadUrl,
              questionAudioPath: questionStoragePath,
            );
          } catch (e) {
            return question.copyWith(
              questionAudioUrl: existingQuestion?.questionAudioUrl,
              questionAudioPath: existingQuestion?.questionAudioPath,
            );
          }
        } else {
          return question.copyWith(
            questionAudioUrl: existingQuestion?.questionAudioUrl,
            questionAudioPath: existingQuestion?.questionAudioPath,
          );
        }
      }
      return question;
    } else if ((question.questionAudioUrl == null || question.questionAudioUrl!.isEmpty) &&
              (question.questionAudioPath == null || question.questionAudioPath!.isEmpty) &&
              existingQuestion?.questionAudioPath != null && 
              existingQuestion!.questionAudioPath!.isNotEmpty) {
      pathsToDelete.add(existingQuestion.questionAudioPath!);
      return question;
    } else {
      return question.copyWith(
        questionAudioUrl: existingQuestion?.questionAudioUrl,
        questionAudioPath: existingQuestion?.questionAudioPath,
      );
    }
  }

  Future<List<AnswerOption>> _handleAnswerOptionsUpdate(
    String testId,
    TestQuestion question,
    TestQuestion? existingQuestion,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final updatedOptions = <AnswerOption>[];
    
    for (int i = 0; i < question.options.length; i++) {
      final option = question.options[i];
      final existingOption = existingQuestion != null && i < existingQuestion.options.length 
          ? existingQuestion.options[i] 
          : null;
      
      final updatedOption = await _handleSingleAnswerOptionUpdate(
        testId, question.id, i, option, existingOption, newUploadedPaths, pathsToDelete
      );
      
      updatedOptions.add(updatedOption);
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
    
    return updatedOptions;
  }

  Future<AnswerOption> _handleSingleAnswerOptionUpdate(
    String testId,
    String questionId,
    int optionIndex,
    AnswerOption option,
    AnswerOption? existingOption,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    final isNewAnswerImage = _isNewMedia(
      currentImagePath: option.imagePath,
      currentImageUrl: option.imageUrl,
      existingImagePath: existingOption?.imagePath,
      existingImageUrl: existingOption?.imageUrl,
    );

    final isNewAnswerAudio = _isNewMedia(
      currentImagePath: option.audioPath,
      currentImageUrl: option.audioUrl,
      existingImagePath: existingOption?.audioPath,
      existingImageUrl: existingOption?.audioUrl,
    );
    
    if (isNewAnswerImage) {
      return await _handleAnswerImageUpload(
        testId, questionId, optionIndex, option, existingOption, newUploadedPaths, pathsToDelete
      );
    } else if (isNewAnswerAudio) {
      return await _handleAnswerAudioUpload(
        testId, questionId, optionIndex, option, existingOption, newUploadedPaths, pathsToDelete
      );
    } else if (!option.isImage && !option.isAudio && 
              existingOption?.isImage == true && 
              existingOption?.imagePath != null && 
              existingOption!.imagePath!.isNotEmpty) {
      pathsToDelete.add(existingOption.imagePath!);
      return option;
    } else if (!option.isImage && !option.isAudio && 
              existingOption?.isAudio == true && 
              existingOption?.audioPath != null && 
              existingOption!.audioPath!.isNotEmpty) {
      pathsToDelete.add(existingOption.audioPath!);
      return option;
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
      return option;
    } else {
      return option.copyWith(
        imageUrl: existingOption?.imageUrl ?? option.imageUrl,
        imagePath: existingOption?.imagePath ?? option.imagePath,
        audioUrl: existingOption?.audioUrl ?? option.audioUrl,
        audioPath: existingOption?.audioPath ?? option.audioPath,
      );
    }
  }

  Future<AnswerOption> _handleAnswerImageUpload(
    String testId,
    String questionId,
    int optionIndex,
    AnswerOption option,
    AnswerOption? existingOption,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (option.imagePath != null && 
        option.imagePath!.startsWith('/') &&
        !_isFirebaseStoragePath(option.imagePath!) &&
        !_isCachedFile(option.imagePath!)) {
      
      final answerImageFile = File(option.imagePath!);
      if (await answerImageFile.exists()) {
        try {
          final answerStoragePath = _getAnswerImagePath(testId, questionId, optionIndex);
          final answerFileRef = storage.ref().child(answerStoragePath);
          
          final answerUploadTask = await answerFileRef.putFile(
            answerImageFile,
            SettableMetadata(contentType: 'image/jpeg')
          );
          
          final answerDownloadUrl = await answerUploadTask.ref.getDownloadURL();
          
          if (answerDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for answer image');
          }
          
          if (existingOption?.imagePath != null && 
              existingOption!.imagePath!.isNotEmpty &&
              existingOption.imagePath != answerStoragePath) {
            pathsToDelete.add(existingOption.imagePath!);
          }
          
          newUploadedPaths.add(answerStoragePath);
          return option.copyWith(
            imageUrl: answerDownloadUrl,
            imagePath: answerStoragePath,
          );
        } catch (e) {
          return option.copyWith(
            imageUrl: existingOption?.imageUrl,
            imagePath: existingOption?.imagePath,
          );
        }
      } else {
        return option.copyWith(
          imageUrl: existingOption?.imageUrl,
          imagePath: existingOption?.imagePath,
        );
      }
    } else {
      return option;
    }
  }

  Future<AnswerOption> _handleAnswerAudioUpload(
    String testId,
    String questionId,
    int optionIndex,
    AnswerOption option,
    AnswerOption? existingOption,
    List<String> newUploadedPaths,
    List<String> pathsToDelete,
  ) async {
    if (option.audioPath != null && 
        option.audioPath!.startsWith('/') &&
        !_isFirebaseStoragePath(option.audioPath!) &&
        !_isCachedFile(option.audioPath!)) {
      
      final answerAudioFile = File(option.audioPath!);
      if (await answerAudioFile.exists()) {
        try {
          final extension = _getAudioExtension(option.audioPath!);
          final answerStoragePath = _getAnswerAudioPath(testId, questionId, optionIndex, extension);
          final answerFileRef = storage.ref().child(answerStoragePath);
          
          final answerUploadTask = await answerFileRef.putFile(
            answerAudioFile,
            SettableMetadata(contentType: _getAudioContentType(extension))
          );
          
          final answerDownloadUrl = await answerUploadTask.ref.getDownloadURL();
          
          if (answerDownloadUrl.isEmpty) {
            throw Exception('Failed to get download URL for answer audio');
          }
          
          if (existingOption?.audioPath != null && 
              existingOption!.audioPath!.isNotEmpty &&
              existingOption.audioPath != answerStoragePath) {
            pathsToDelete.add(existingOption.audioPath!);
          }
          
          newUploadedPaths.add(answerStoragePath);
          return option.copyWith(
            audioUrl: answerDownloadUrl,
            audioPath: answerStoragePath,
          );
        } catch (e) {
          return option.copyWith(
            audioUrl: existingOption?.audioUrl,
            audioPath: existingOption?.audioPath,
          );
        }
      } else {
        return option.copyWith(
          audioUrl: existingOption?.audioUrl,
          audioPath: existingOption?.audioPath,
        );
      }
    } else {
      return option;
    }
  }

  void _handleRemovedQuestions(
    TestItem existingTest,
    Set<String> currentQuestionIds,
    List<String> pathsToDelete,
  ) {
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
  }

  Future<void> _saveUpdatedTest(
    WriteBatch batch,
    DocumentReference docRef,
    TestItem finalTest,
  ) async {
    final updateData = finalTest.toJson();
    updateData['titleLowerCase'] = finalTest.title.toLowerCase();
    updateData['descriptionLowerCase'] = finalTest.description.toLowerCase();
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

  bool _isCachedFile(String path) {
    return path.startsWith('/') && 
          (path.contains('tests_images_cache') || 
            path.contains('tests_audio_cache'));
  }

  bool _isFirebaseStoragePath(String path) {
    return path.startsWith('$_testsStorageRoot/') && 
          (path.contains('.jpg') || 
            path.contains('.jpeg') ||
            path.contains('.png') ||
            path.contains('.m4a') ||
            path.contains('.mp3') ||
            path.contains('.wav') ||
            path.contains('.aac'));
  }
}