import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/features/admin/data/service/admin_permission.dart';
import 'package:korean_language_app/features/vocabulary_upload/data/datasources/vocabulary_upload_remote_datasource.dart';
import 'package:korean_language_app/features/vocabulary_upload/domain/repositories/vocabulary_upload_repository.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

class VocabularyUploadRepositoryImpl extends BaseRepository implements VocabularyUploadRepository {
  final VocabularyUploadRemoteDataSource remoteDataSource;
  final AdminPermissionService adminService;

  VocabularyUploadRepositoryImpl({
    required this.remoteDataSource,
    required this.adminService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<VocabularyItem>> createVocabulary(VocabularyItem vocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    return handleRepositoryCall(() async {
      final createdVocabulary = await remoteDataSource.uploadVocabulary(vocabulary, imageFile: imageFile, pdfFiles: pdfFiles);
      return ApiResult.success(createdVocabulary);
    });
  }

  @override
  Future<ApiResult<VocabularyItem>> updateVocabulary(String vocabularyId, VocabularyItem updatedVocabulary, {File? imageFile, List<File>? pdfFiles}) async {
    return handleRepositoryCall(() async {
      final updatedVocabularyResult = await remoteDataSource.updateVocabulary(vocabularyId, updatedVocabulary, imageFile: imageFile, pdfFiles: pdfFiles);
      return ApiResult.success(updatedVocabularyResult);
    });
  }

  @override
  Future<ApiResult<bool>> deleteVocabulary(String vocabularyId) async {
    return handleRepositoryCall(() async {
      final success = await remoteDataSource.deleteVocabulary(vocabularyId);
      if (!success) {
        throw Exception('Failed to delete vocabulary');
      }
      return ApiResult.success(true);
    });
  }

  @override
  Future<ApiResult<String?>> regenerateImageUrl(VocabularyItem vocabulary) async {
    if (vocabulary.imagePath == null || vocabulary.imagePath!.isEmpty) {
      return ApiResult.success(null);
    }

    return handleRepositoryCall(() async {
      final newUrl = await remoteDataSource.regenerateUrlFromPath(vocabulary.imagePath!);
      
      if (newUrl != null && newUrl.isNotEmpty) {
        final updatedVocabulary = vocabulary.copyWith(imageUrl: newUrl);
        
        try {
          await remoteDataSource.updateVocabulary(vocabulary.id, updatedVocabulary);
        } catch (e) {
          debugPrint('Error updating vocabulary image URL: $e');
        }
      }
      
      return ApiResult.success(newUrl);
    });
  }

  @override
  Future<ApiResult<VocabularyItem?>> regenerateAllImageUrls(VocabularyItem vocabulary) async {
    return handleRepositoryCall(() async {
      var updatedVocabulary = vocabulary;
      bool hasUpdates = false;

      if (vocabulary.imagePath != null && vocabulary.imagePath!.isNotEmpty) {
        final newCoverUrl = await remoteDataSource.regenerateUrlFromPath(vocabulary.imagePath!);
        if (newCoverUrl != null && newCoverUrl != vocabulary.imageUrl) {
          updatedVocabulary = updatedVocabulary.copyWith(imageUrl: newCoverUrl);
          hasUpdates = true;
        }
      }

      final updatedChapters = updatedVocabulary.chapters.map((chapter) {
        var updatedChapter = chapter;
        bool chapterHasUpdates = false;

        if (chapter.imagePath != null && chapter.imagePath!.isNotEmpty) {
          final newChapterUrl = remoteDataSource.regenerateUrlFromPath(chapter.imagePath!);
          newChapterUrl.then((url) {
            if (url != null && url != chapter.imageUrl) {
              updatedChapter = updatedChapter.copyWith(imageUrl: url);
              chapterHasUpdates = true;
              hasUpdates = true;
            }
          });
        }

        final updatedWords = chapter.words.map((word) {
          var updatedWord = word;
          bool wordHasUpdates = false;

          if (word.imagePath != null && word.imagePath!.isNotEmpty) {
            final newWordUrl = remoteDataSource.regenerateUrlFromPath(word.imagePath!);
            newWordUrl.then((url) {
              if (url != null && url != word.imageUrl) {
                updatedWord = updatedWord.copyWith(imageUrl: url);
                wordHasUpdates = true;
                hasUpdates = true;
              }
            });
          }

          if (word.audioPath != null && word.audioPath!.isNotEmpty) {
            final newWordAudioUrl = remoteDataSource.regenerateUrlFromPath(word.audioPath!);
            newWordAudioUrl.then((url) {
              if (url != null && url != word.audioUrl) {
                updatedWord = updatedWord.copyWith(audioUrl: url);
                wordHasUpdates = true;
                hasUpdates = true;
              }
            });
          }

          final updatedMeanings = word.meanings.map((meaning) {
            var updatedMeaning = meaning;
            
            if (meaning.imagePath != null && meaning.imagePath!.isNotEmpty) {
              final newMeaningImageUrl = remoteDataSource.regenerateUrlFromPath(meaning.imagePath!);
              newMeaningImageUrl.then((url) {
                if (url != null && url != meaning.imageUrl) {
                  updatedMeaning = updatedMeaning.copyWith(imageUrl: url);
                  wordHasUpdates = true;
                  hasUpdates = true;
                }
              });
            }
            
            if (meaning.audioPath != null && meaning.audioPath!.isNotEmpty) {
              final newMeaningAudioUrl = remoteDataSource.regenerateUrlFromPath(meaning.audioPath!);
              newMeaningAudioUrl.then((url) {
                if (url != null && url != meaning.audioUrl) {
                  updatedMeaning = updatedMeaning.copyWith(audioUrl: url);
                  wordHasUpdates = true;
                  hasUpdates = true;
                }
              });
            }
            
            return updatedMeaning;
          }).toList();

          final updatedExamples = word.examples.map((example) {
            var updatedExample = example;
            
            if (example.imagePath != null && example.imagePath!.isNotEmpty) {
              final newExampleImageUrl = remoteDataSource.regenerateUrlFromPath(example.imagePath!);
              newExampleImageUrl.then((url) {
                if (url != null && url != example.imageUrl) {
                  updatedExample = updatedExample.copyWith(imageUrl: url);
                  wordHasUpdates = true;
                  hasUpdates = true;
                }
              });
            }
            
            if (example.audioPath != null && example.audioPath!.isNotEmpty) {
              final newExampleAudioUrl = remoteDataSource.regenerateUrlFromPath(example.audioPath!);
              newExampleAudioUrl.then((url) {
                if (url != null && url != example.audioUrl) {
                  updatedExample = updatedExample.copyWith(audioUrl: url);
                  wordHasUpdates = true;
                  hasUpdates = true;
                }
              });
            }
            
            return updatedExample;
          }).toList();

          if (wordHasUpdates) {
            updatedWord = updatedWord.copyWith(
              meanings: updatedMeanings,
              examples: updatedExamples,
            );
          }

          return updatedWord;
        }).toList();

        if (chapterHasUpdates) {
          updatedChapter = updatedChapter.copyWith(words: updatedWords);
        }

        return updatedChapter;
      }).toList();

      if (hasUpdates) {
        updatedVocabulary = updatedVocabulary.copyWith(chapters: updatedChapters);
        
        try {
          await remoteDataSource.updateVocabulary(vocabulary.id, updatedVocabulary);
        } catch (e) {
          debugPrint('Error updating vocabulary image URL: $e');
        }
        
        return ApiResult.success(updatedVocabulary);
      }

      return ApiResult.success(null);
    });
  }

  @override
  Future<ApiResult<bool>> verifyImageUrls(VocabularyItem vocabulary) async {
    return handleRepositoryCall(() async {
      if (vocabulary.imageUrl != null && vocabulary.imageUrl!.isNotEmpty) {
        final isWorking = await remoteDataSource.verifyUrlIsWorking(vocabulary.imageUrl!);
        if (!isWorking) {
          return ApiResult.success(false);
        }
      }

      for (final chapter in vocabulary.chapters) {
        if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
          final isWorking = await remoteDataSource.verifyUrlIsWorking(chapter.imageUrl!);
          if (!isWorking) {
            return ApiResult.success(false);
          }
        }

        for (final word in chapter.words) {
          if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
            final isWorking = await remoteDataSource.verifyUrlIsWorking(word.imageUrl!);
            if (!isWorking) {
              return ApiResult.success(false);
            }
          }

          if (word.audioUrl != null && word.audioUrl!.isNotEmpty) {
            final isWorking = await remoteDataSource.verifyUrlIsWorking(word.audioUrl!);
            if (!isWorking) {
              return ApiResult.success(false);
            }
          }

          for (final meaning in word.meanings) {
            if (meaning.imageUrl != null && meaning.imageUrl!.isNotEmpty) {
              final isWorking = await remoteDataSource.verifyUrlIsWorking(meaning.imageUrl!);
              if (!isWorking) {
                return ApiResult.success(false);
              }
            }
            
            if (meaning.audioUrl != null && meaning.audioUrl!.isNotEmpty) {
              final isWorking = await remoteDataSource.verifyUrlIsWorking(meaning.audioUrl!);
              if (!isWorking) {
                return ApiResult.success(false);
              }
            }
          }

          for (final example in word.examples) {
            if (example.imageUrl != null && example.imageUrl!.isNotEmpty) {
              final isWorking = await remoteDataSource.verifyUrlIsWorking(example.imageUrl!);
              if (!isWorking) {
                return ApiResult.success(false);
              }
            }
            
            if (example.audioUrl != null && example.audioUrl!.isNotEmpty) {
              final isWorking = await remoteDataSource.verifyUrlIsWorking(example.audioUrl!);
              if (!isWorking) {
                return ApiResult.success(false);
              }
            }
          }
        }
      }

      return ApiResult.success(true);
    });
  }

  @override
  Future<ApiResult<bool>> hasEditPermission(String vocabularyId, String userId) async {
    try {
      if (await adminService.isUserAdmin(userId)) {
        return ApiResult.success(true);
      }
      
      return ApiResult.success(false);
    } catch (e) {
      return ApiResult.failure('Error checking edit permission: $e');
    }
  }
}