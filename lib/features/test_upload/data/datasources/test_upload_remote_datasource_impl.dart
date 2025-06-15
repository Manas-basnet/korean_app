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
      // ========== COVER IMAGE HANDLING ==========
      if (imageFile != null) {
        // Validate that the file exists before attempting upload
        if (await imageFile.exists()) {
          try {
            if (kDebugMode) {
              print('Uploading cover image: ${imageFile.path}');
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
            
            if (kDebugMode) {
              print('Successfully uploaded cover image. URL: $downloadUrl');
            }
            
            // Only mark old image for deletion after successful upload IF it's a different path
            if (existingTest.imagePath != null && 
                existingTest.imagePath!.isNotEmpty &&
                existingTest.imagePath != storagePath) {
              pathsToDelete.add(existingTest.imagePath!);
              if (kDebugMode) {
                print('Marking old cover image for deletion: ${existingTest.imagePath}');
              }
            } else if (existingTest.imagePath == storagePath) {
              if (kDebugMode) {
                print('New cover image overwrote existing image at same path: $storagePath');
              }
            }
            
            newUploadedPaths.add(storagePath);
            finalTest = finalTest.copyWith(
              imageUrl: downloadUrl,
              imagePath: storagePath,
            );
          } catch (e) {
            if (kDebugMode) {
              print('Failed to upload cover image: $e');
            }
            // If upload fails, preserve existing image
            if (existingTest.imageUrl != null && existingTest.imageUrl!.isNotEmpty) {
              if (kDebugMode) {
                print('Preserving existing cover image: ${existingTest.imageUrl}');
              }
              finalTest = finalTest.copyWith(
                imageUrl: existingTest.imageUrl,
                imagePath: existingTest.imagePath,
              );
            } else {
              if (kDebugMode) {
                print('No existing cover image to preserve, clearing image fields');
              }
              finalTest = finalTest.copyWith(
                imageUrl: null,
                imagePath: null,
              );
            }
          }
        } else {
          if (kDebugMode) {
            print('Cover image file does not exist: ${imageFile.path}');
          }
          // File doesn't exist, preserve existing image or clear
          if (existingTest.imageUrl != null && existingTest.imageUrl!.isNotEmpty) {
            finalTest = finalTest.copyWith(
              imageUrl: existingTest.imageUrl,
              imagePath: existingTest.imagePath,
            );
          } else {
            finalTest = finalTest.copyWith(
              imageUrl: null,
              imagePath: null,
            );
          }
        }
      } else if ((finalTest.imageUrl == null || finalTest.imageUrl!.isEmpty) &&
                (finalTest.imagePath == null || finalTest.imagePath!.isEmpty)) {
        // User removed the cover image
        if (existingTest.imagePath != null && existingTest.imagePath!.isNotEmpty) {
          pathsToDelete.add(existingTest.imagePath!);
          if (kDebugMode) {
            print('User removed cover image, marking for deletion: ${existingTest.imagePath}');
          }
        }
      }
      
      // ========== QUESTIONS HANDLING ==========
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
        
        // Check if question image is new
        bool isNewQuestionImage = _isNewMedia(
          currentImagePath: question.questionImagePath,
          currentImageUrl: question.questionImageUrl,
          existingImagePath: existingQuestion?.questionImagePath,
          existingImageUrl: existingQuestion?.questionImageUrl,
        );
        
        // Check if question audio is new
        bool isNewQuestionAudio = _isNewMedia(
          currentImagePath: question.questionAudioPath,
          currentImageUrl: question.questionAudioUrl,
          existingImagePath: existingQuestion?.questionAudioPath,
          existingImageUrl: existingQuestion?.questionAudioUrl,
        );
        
        // ========== QUESTION IMAGE HANDLING ==========
        if (isNewQuestionImage) {
          if (question.questionImagePath != null && question.questionImagePath!.startsWith('/')) {
            // First validate that the file exists
            final questionImageFile = File(question.questionImagePath!);
            if (await questionImageFile.exists()) {
              try {
                if (kDebugMode) {
                  print('Uploading question image for question ${question.id}: ${question.questionImagePath}');
                }
                
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
                
                if (kDebugMode) {
                  print('Successfully uploaded question image. URL: $questionDownloadUrl');
                }
                
                // Only mark old image for deletion after successful upload IF it's a different path
                if (existingQuestion?.questionImagePath != null && 
                    existingQuestion!.questionImagePath!.isNotEmpty &&
                    existingQuestion.questionImagePath != questionStoragePath) {
                  pathsToDelete.add(existingQuestion.questionImagePath!);
                  if (kDebugMode) {
                    print('Marking old question image for deletion: ${existingQuestion.questionImagePath}');
                  }
                } else if (existingQuestion?.questionImagePath == questionStoragePath) {
                  if (kDebugMode) {
                    print('New question image overwrote existing image at same path: $questionStoragePath');
                  }
                }
                
                newUploadedPaths.add(questionStoragePath);
                updatedQuestion = updatedQuestion.copyWith(
                  questionImageUrl: questionDownloadUrl,
                  questionImagePath: questionStoragePath,
                );
              } catch (e) {
                if (kDebugMode) {
                  print('Failed to upload question image: $e');
                }
                // If upload fails, preserve existing media or clear invalid media
                if (existingQuestion?.questionImageUrl != null && existingQuestion!.questionImageUrl!.isNotEmpty) {
                  if (kDebugMode) {
                    print('Preserving existing question image: ${existingQuestion.questionImageUrl}');
                  }
                  updatedQuestion = updatedQuestion.copyWith(
                    questionImageUrl: existingQuestion.questionImageUrl,
                    questionImagePath: existingQuestion.questionImagePath,
                  );
                } else {
                  if (kDebugMode) {
                    print('No existing question image to preserve, clearing media fields');
                  }
                  // Clear the media fields since upload failed and no existing media
                  updatedQuestion = updatedQuestion.copyWith(
                    questionImageUrl: null,
                    questionImagePath: null,
                  );
                }
              }
            } else {
              if (kDebugMode) {
                print('Question image file does not exist: ${question.questionImagePath}');
              }
              // File doesn't exist, preserve existing media or clear
              if (existingQuestion?.questionImageUrl != null && existingQuestion!.questionImageUrl!.isNotEmpty) {
                updatedQuestion = updatedQuestion.copyWith(
                  questionImageUrl: existingQuestion.questionImageUrl,
                  questionImagePath: existingQuestion.questionImagePath,
                );
              } else {
                updatedQuestion = updatedQuestion.copyWith(
                  questionImageUrl: null,
                  questionImagePath: null,
                );
              }
            }
          }
        } else if ((question.questionImageUrl == null || question.questionImageUrl!.isEmpty) &&
                  (question.questionImagePath == null || question.questionImagePath!.isEmpty) &&
                  existingQuestion?.questionImagePath != null && 
                  existingQuestion!.questionImagePath!.isNotEmpty) {
          // User removed question image
          pathsToDelete.add(existingQuestion.questionImagePath!);
          if (kDebugMode) {
            print('User removed question image, marking for deletion: ${existingQuestion.questionImagePath}');
          }
        }

        // ========== QUESTION AUDIO HANDLING ==========
        if (isNewQuestionAudio) {
          if (question.questionAudioPath != null && question.questionAudioPath!.startsWith('/')) {
            // First validate that the file exists
            final questionAudioFile = File(question.questionAudioPath!);
            if (await questionAudioFile.exists()) {
              try {
                if (kDebugMode) {
                  print('Uploading question audio for question ${question.id}: ${question.questionAudioPath}');
                }
                
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
                
                if (kDebugMode) {
                  print('Successfully uploaded question audio. URL: $questionDownloadUrl');
                }
                
                // Only mark old audio for deletion after successful upload IF it's a different path
                if (existingQuestion?.questionAudioPath != null && 
                    existingQuestion!.questionAudioPath!.isNotEmpty &&
                    existingQuestion.questionAudioPath != questionStoragePath) {
                  pathsToDelete.add(existingQuestion.questionAudioPath!);
                  if (kDebugMode) {
                    print('Marking old question audio for deletion: ${existingQuestion.questionAudioPath}');
                  }
                } else if (existingQuestion?.questionAudioPath == questionStoragePath) {
                  if (kDebugMode) {
                    print('New question audio overwrote existing audio at same path: $questionStoragePath');
                  }
                }
                
                newUploadedPaths.add(questionStoragePath);
                updatedQuestion = updatedQuestion.copyWith(
                  questionAudioUrl: questionDownloadUrl,
                  questionAudioPath: questionStoragePath,
                );
              } catch (e) {
                if (kDebugMode) {
                  print('Failed to upload question audio: $e');
                }
                // If upload fails, preserve existing media or clear invalid media
                if (existingQuestion?.questionAudioUrl != null && existingQuestion!.questionAudioUrl!.isNotEmpty) {
                  if (kDebugMode) {
                    print('Preserving existing question audio: ${existingQuestion.questionAudioUrl}');
                  }
                  updatedQuestion = updatedQuestion.copyWith(
                    questionAudioUrl: existingQuestion.questionAudioUrl,
                    questionAudioPath: existingQuestion.questionAudioPath,
                  );
                } else {
                  if (kDebugMode) {
                    print('No existing question audio to preserve, clearing media fields');
                  }
                  // Clear the media fields since upload failed and no existing media
                  updatedQuestion = updatedQuestion.copyWith(
                    questionAudioUrl: null,
                    questionAudioPath: null,
                  );
                }
              }
            } else {
              if (kDebugMode) {
                print('Question audio file does not exist: ${question.questionAudioPath}');
              }
              // File doesn't exist, preserve existing media or clear
              if (existingQuestion?.questionAudioUrl != null && existingQuestion!.questionAudioUrl!.isNotEmpty) {
                updatedQuestion = updatedQuestion.copyWith(
                  questionAudioUrl: existingQuestion.questionAudioUrl,
                  questionAudioPath: existingQuestion.questionAudioPath,
                );
              } else {
                updatedQuestion = updatedQuestion.copyWith(
                  questionAudioUrl: null,
                  questionAudioPath: null,
                );
              }
            }
          }
        } else if ((question.questionAudioUrl == null || question.questionAudioUrl!.isEmpty) &&
                  (question.questionAudioPath == null || question.questionAudioPath!.isEmpty) &&
                  existingQuestion?.questionAudioPath != null && 
                  existingQuestion!.questionAudioPath!.isNotEmpty) {
          // User removed question audio
          pathsToDelete.add(existingQuestion.questionAudioPath!);
          if (kDebugMode) {
            print('User removed question audio, marking for deletion: ${existingQuestion.questionAudioPath}');
          }
        }
        
        // ========== ANSWER OPTIONS HANDLING ==========
        final updatedOptions = <AnswerOption>[];
        for (int i = 0; i < question.options.length; i++) {
          final option = question.options[i];
          final existingOption = existingQuestion != null && i < existingQuestion.options.length 
              ? existingQuestion.options[i] 
              : null;
          
          // Check if answer image is new
          bool isNewAnswerImage = _isNewMedia(
            currentImagePath: option.imagePath,
            currentImageUrl: option.imageUrl,
            existingImagePath: existingOption?.imagePath,
            existingImageUrl: existingOption?.imageUrl,
          );

          // Check if answer audio is new
          bool isNewAnswerAudio = _isNewMedia(
            currentImagePath: option.audioPath,
            currentImageUrl: option.audioUrl,
            existingImagePath: existingOption?.audioPath,
            existingImageUrl: existingOption?.audioUrl,
          );
          
          // ========== ANSWER IMAGE HANDLING ==========
          if (isNewAnswerImage) {
            if (option.imagePath != null && option.imagePath!.startsWith('/')) {
              // First validate that the file exists
              final answerImageFile = File(option.imagePath!);
              if (await answerImageFile.exists()) {
                try {
                  if (kDebugMode) {
                    print('Uploading answer image for question ${question.id}, option $i: ${option.imagePath}');
                  }
                  
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
                  
                  if (kDebugMode) {
                    print('Successfully uploaded answer image. URL: $answerDownloadUrl');
                  }
                  
                  // Only mark old image for deletion after successful upload IF it's a different path
                  if (existingOption?.imagePath != null && 
                      existingOption!.imagePath!.isNotEmpty &&
                      existingOption.imagePath != answerStoragePath) {
                    pathsToDelete.add(existingOption.imagePath!);
                    if (kDebugMode) {
                      print('Marking old answer image for deletion: ${existingOption.imagePath}');
                    }
                  } else if (existingOption?.imagePath == answerStoragePath) {
                    if (kDebugMode) {
                      print('New answer image overwrote existing image at same path: $answerStoragePath');
                    }
                  }
                  
                  newUploadedPaths.add(answerStoragePath);
                  updatedOptions.add(option.copyWith(
                    imageUrl: answerDownloadUrl,
                    imagePath: answerStoragePath,
                  ));
                } catch (e) {
                  if (kDebugMode) {
                    print('Failed to upload answer image: $e');
                  }
                  // If upload fails, preserve existing media or clear invalid media
                  if (existingOption?.imageUrl != null && existingOption!.imageUrl!.isNotEmpty) {
                    if (kDebugMode) {
                      print('Preserving existing answer image: ${existingOption.imageUrl}');
                    }
                    updatedOptions.add(option.copyWith(
                      imageUrl: existingOption.imageUrl,
                      imagePath: existingOption.imagePath,
                    ));
                  } else {
                    if (kDebugMode) {
                      print('No existing answer image to preserve, clearing media fields');
                    }
                    // Clear the media fields since upload failed and no existing media
                    updatedOptions.add(option.copyWith(
                      imageUrl: null,
                      imagePath: null,
                    ));
                  }
                }
              } else {
                if (kDebugMode) {
                  print('Answer image file does not exist: ${option.imagePath}');
                }
                // File doesn't exist, preserve existing media or clear
                if (existingOption?.imageUrl != null && existingOption!.imageUrl!.isNotEmpty) {
                  updatedOptions.add(option.copyWith(
                    imageUrl: existingOption.imageUrl,
                    imagePath: existingOption.imagePath,
                  ));
                } else {
                  updatedOptions.add(option.copyWith(
                    imageUrl: null,
                    imagePath: null,
                  ));
                }
              }
            } else {
              updatedOptions.add(option);
            }
          } 
          // ========== ANSWER AUDIO HANDLING ==========
          else if (isNewAnswerAudio) {
            if (option.audioPath != null && option.audioPath!.startsWith('/')) {
              // First validate that the file exists
              final answerAudioFile = File(option.audioPath!);
              if (await answerAudioFile.exists()) {
                try {
                  if (kDebugMode) {
                    print('Uploading answer audio for question ${question.id}, option $i: ${option.audioPath}');
                  }
                  
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
                  
                  if (kDebugMode) {
                    print('Successfully uploaded answer audio. URL: $answerDownloadUrl');
                  }
                  
                  // Only mark old audio for deletion after successful upload IF it's a different path
                  if (existingOption?.audioPath != null && 
                      existingOption!.audioPath!.isNotEmpty &&
                      existingOption.audioPath != answerStoragePath) {
                    pathsToDelete.add(existingOption.audioPath!);
                    if (kDebugMode) {
                      print('Marking old answer audio for deletion: ${existingOption.audioPath}');
                    }
                  } else if (existingOption?.audioPath == answerStoragePath) {
                    if (kDebugMode) {
                      print('New answer audio overwrote existing audio at same path: $answerStoragePath');
                    }
                  }
                  
                  newUploadedPaths.add(answerStoragePath);
                  updatedOptions.add(option.copyWith(
                    audioUrl: answerDownloadUrl,
                    audioPath: answerStoragePath,
                  ));
                } catch (e) {
                  if (kDebugMode) {
                    print('Failed to upload answer audio: $e');
                  }
                  // If upload fails, preserve existing media or clear invalid media
                  if (existingOption?.audioUrl != null && existingOption!.audioUrl!.isNotEmpty) {
                    if (kDebugMode) {
                      print('Preserving existing answer audio: ${existingOption.audioUrl}');
                    }
                    updatedOptions.add(option.copyWith(
                      audioUrl: existingOption.audioUrl,
                      audioPath: existingOption.audioPath,
                    ));
                  } else {
                    if (kDebugMode) {
                      print('No existing answer audio to preserve, clearing media fields');
                    }
                    // Clear the media fields since upload failed and no existing media
                    updatedOptions.add(option.copyWith(
                      audioUrl: null,
                      audioPath: null,
                    ));
                  }
                }
              } else {
                if (kDebugMode) {
                  print('Answer audio file does not exist: ${option.audioPath}');
                }
                // File doesn't exist, preserve existing media or clear
                if (existingOption?.audioUrl != null && existingOption!.audioUrl!.isNotEmpty) {
                  updatedOptions.add(option.copyWith(
                    audioUrl: existingOption.audioUrl,
                    audioPath: existingOption.audioPath,
                  ));
                } else {
                  updatedOptions.add(option.copyWith(
                    audioUrl: null,
                    audioPath: null,
                  ));
                }
              }
            } else {
              updatedOptions.add(option);
            }
          } 
          // ========== HANDLE TYPE CHANGES ==========
          else if (!option.isImage && !option.isAudio && 
                    existingOption?.isImage == true && 
                    existingOption?.imagePath != null && 
                    existingOption!.imagePath!.isNotEmpty) {
            // User changed from image to text
            pathsToDelete.add(existingOption.imagePath!);
            if (kDebugMode) {
              print('User changed option from image to text, marking image for deletion: ${existingOption.imagePath}');
            }
            updatedOptions.add(option);
          } else if (!option.isImage && !option.isAudio && 
                    existingOption?.isAudio == true && 
                    existingOption?.audioPath != null && 
                    existingOption!.audioPath!.isNotEmpty) {
            // User changed from audio to text
            pathsToDelete.add(existingOption.audioPath!);
            if (kDebugMode) {
              print('User changed option from audio to text, marking audio for deletion: ${existingOption.audioPath}');
            }
            updatedOptions.add(option);
          } 
          // ========== HANDLE MEDIA REMOVAL ==========
          else if ((option.isImage && 
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
            // User removed media
            if (existingOption.imagePath != null && existingOption.imagePath!.isNotEmpty) {
              pathsToDelete.add(existingOption.imagePath!);
              if (kDebugMode) {
                print('User removed answer image, marking for deletion: ${existingOption.imagePath}');
              }
            }
            if (existingOption.audioPath != null && existingOption.audioPath!.isNotEmpty) {
              pathsToDelete.add(existingOption.audioPath!);
              if (kDebugMode) {
                print('User removed answer audio, marking for deletion: ${existingOption.audioPath}');
              }
            }
            updatedOptions.add(option);
          } else {
            // No changes, keep existing option
            updatedOptions.add(option);
          }
        }

        // Handle removed options (if question now has fewer options)
        if (existingQuestion != null) {
          for (int i = question.options.length; i < existingQuestion.options.length; i++) {
            final removedOption = existingQuestion.options[i];
            if (removedOption.isImage && 
                removedOption.imagePath != null && 
                removedOption.imagePath!.isNotEmpty) {
              pathsToDelete.add(removedOption.imagePath!);
              if (kDebugMode) {
                print('Removed option had image, marking for deletion: ${removedOption.imagePath}');
              }
            }
            if (removedOption.isAudio && 
                removedOption.audioPath != null && 
                removedOption.audioPath!.isNotEmpty) {
              pathsToDelete.add(removedOption.audioPath!);
              if (kDebugMode) {
                print('Removed option had audio, marking for deletion: ${removedOption.audioPath}');
              }
            }
          }
        }
        
        updatedQuestion = updatedQuestion.copyWith(options: updatedOptions);
        updatedQuestions.add(updatedQuestion);
      }
      
      // Handle removed questions (if test now has fewer questions)
      for (final existingQuestion in existingTest.questions) {
        if (!currentQuestionIds.contains(existingQuestion.id)) {
          if (existingQuestion.questionImagePath != null && 
              existingQuestion.questionImagePath!.isNotEmpty) {
            pathsToDelete.add(existingQuestion.questionImagePath!);
            if (kDebugMode) {
              print('Removed question had image, marking for deletion: ${existingQuestion.questionImagePath}');
            }
          }
          if (existingQuestion.questionAudioPath != null && 
              existingQuestion.questionAudioPath!.isNotEmpty) {
            pathsToDelete.add(existingQuestion.questionAudioPath!);
            if (kDebugMode) {
              print('Removed question had audio, marking for deletion: ${existingQuestion.questionAudioPath}');
            }
          }
          
          for (final option in existingQuestion.options) {
            if (option.isImage && 
                option.imagePath != null && 
                option.imagePath!.isNotEmpty) {
              pathsToDelete.add(option.imagePath!);
              if (kDebugMode) {
                print('Removed question option had image, marking for deletion: ${option.imagePath}');
              }
            }
            if (option.isAudio && 
                option.audioPath != null && 
                option.audioPath!.isNotEmpty) {
              pathsToDelete.add(option.audioPath!);
              if (kDebugMode) {
                print('Removed question option had audio, marking for deletion: ${option.audioPath}');
              }
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

  /// **Improved logic to determine if media is new**
  bool _isNewMedia({
    required String? currentImagePath,
    required String? currentImageUrl,
    required String? existingImagePath,
    required String? existingImageUrl,
  }) {
    // Case 1: No current media (user removed it)
    if ((currentImagePath == null || currentImagePath.isEmpty) &&
        (currentImageUrl == null || currentImageUrl.isEmpty)) {
      return false;
    }
    
    // Case 2: Has current media but no existing media (new media added)
    if ((existingImagePath == null || existingImagePath.isEmpty) &&
        (existingImageUrl == null || existingImageUrl.isEmpty)) {
      return true;
    }
    
    // Case 3: Current media is a local file path (newly picked from image_picker or similar)
    if (currentImagePath != null && 
        currentImagePath.startsWith('/') && 
        !_isFirebaseStoragePath(currentImagePath) &&
        !_isCachedFile(currentImagePath)) {
      // Additional validation: check if file actually exists
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
    
    // Case 4: Current media is different from existing (URL comparison)
    if (currentImageUrl != null && existingImageUrl != null) {
      return currentImageUrl != existingImageUrl;
    }
    
    // Case 5: Current media path is different from existing (path comparison)
    if (currentImagePath != null && existingImagePath != null) {
      return currentImagePath != existingImagePath;
    }
    
    // Case 6: Mixed comparison (one has URL, other has path) - assume different
    if ((currentImageUrl != null && existingImagePath != null) ||
        (currentImagePath != null && existingImageUrl != null)) {
      return true;
    }
    
    // Default: no change
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
    return path.startsWith('tests/') && 
          (path.contains('.jpg') || 
            path.contains('.jpeg') ||
            path.contains('.png') ||
            path.contains('.m4a') ||
            path.contains('.mp3') ||
            path.contains('.wav') ||
            path.contains('.aac'));
  }
}