import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_chapter.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_word.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_example.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/word_meaning.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/vocabularies_local_datasource.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/remote/vocabularies_remote_datasource.dart';
import 'package:korean_language_app/features/vocabularies/domain/repositories/vocabularies_repository.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

class MediaItem {
  final String url;
  final int chapterIndex;
  final int wordIndex;
  final int? meaningIndex;
  final int? exampleIndex;
  
  MediaItem({
    required this.url,
    required this.chapterIndex,
    required this.wordIndex,
    this.meaningIndex,
    this.exampleIndex,
  });
}

class FullMediaCheckData {
  final String vocabularyId;
  final List<MediaItem> chapterImageItems;
  final List<MediaItem> wordImageItems;
  final List<MediaItem> wordAudioItems;
  final List<MediaItem> meaningImageItems;
  final List<MediaItem> meaningAudioItems;
  final List<MediaItem> exampleImageItems;
  final List<MediaItem> exampleAudioItems;
  final List<String> pdfUrls;
  final VocabulariesLocalDataSource localDataSource;
  final RootIsolateToken token;

  FullMediaCheckData({
    required this.vocabularyId,
    required this.chapterImageItems,
    required this.wordImageItems,
    required this.wordAudioItems,
    required this.meaningImageItems,
    required this.meaningAudioItems,
    required this.exampleImageItems,
    required this.exampleAudioItems,
    required this.pdfUrls,
    required this.localDataSource,
    required this.token,
  });
}

class MediaProcessingData {
  final List<VocabularyItem> vocabularies;
  final VocabulariesLocalDataSource localDataSource;
  final bool processFullMedia;
  final RootIsolateToken token;

  MediaProcessingData({
    required this.vocabularies,
    required this.localDataSource,
    required this.processFullMedia,
    required this.token,
  });
}

Future<bool> _checkFullMediaCached(FullMediaCheckData data) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  
  for (final item in data.chapterImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.vocabularyId, 'chapter_${item.chapterIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  for (final item in data.wordImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.vocabularyId, 'word_${item.chapterIndex}_${item.wordIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  for (final item in data.wordAudioItems) {
    final cachedPath = await data.localDataSource.getCachedAudioPath(item.url, data.vocabularyId, 'word_audio_${item.chapterIndex}_${item.wordIndex}');
    if (cachedPath == null) {
      return false;
    }
  }

  for (final item in data.meaningImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.vocabularyId, 'meaning_${item.chapterIndex}_${item.wordIndex}_${item.meaningIndex}');
    if (cachedPath == null) {
      return false;
    }
  }

  for (final item in data.meaningAudioItems) {
    final cachedPath = await data.localDataSource.getCachedAudioPath(item.url, data.vocabularyId, 'meaning_audio_${item.chapterIndex}_${item.wordIndex}_${item.meaningIndex}');
    if (cachedPath == null) {
      return false;
    }
  }

  for (final item in data.exampleImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.vocabularyId, 'example_${item.chapterIndex}_${item.wordIndex}_${item.exampleIndex}');
    if (cachedPath == null) {
      return false;
    }
  }

  for (final item in data.exampleAudioItems) {
    final cachedPath = await data.localDataSource.getCachedAudioPath(item.url, data.vocabularyId, 'example_audio_${item.chapterIndex}_${item.wordIndex}_${item.exampleIndex}');
    if (cachedPath == null) {
      return false;
    }
  }

  for (int i = 0; i < data.pdfUrls.length; i++) {
    final pdfUrl = data.pdfUrls[i];
    final cachedPath = await data.localDataSource.getCachedPdfPath(pdfUrl, data.vocabularyId, 'pdf_$i');
    if (cachedPath == null) {
      return false;
    }
  }
  
  return true;
}

Future<List<VocabularyItem>> _processVocabulariesInIsolate(MediaProcessingData data) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  
  final processedVocabularies = <VocabularyItem>[];
  
  for (int vocabularyIndex = 0; vocabularyIndex < data.vocabularies.length; vocabularyIndex++) {
    final vocabulary = data.vocabularies[vocabularyIndex];
    VocabularyItem updatedVocabulary = vocabulary;
    
    if (vocabulary.imageUrl != null && vocabulary.imageUrl!.isNotEmpty) {
      final cachedPath = await data.localDataSource.getCachedImagePath(vocabulary.imageUrl!, vocabulary.id, 'main');
      if (cachedPath != null) {
        updatedVocabulary = updatedVocabulary.copyWith(
          imagePath: cachedPath,
          imageUrl: null
        );
      } else {
        updatedVocabulary = updatedVocabulary.copyWith(imagePath: null);
      }
    }
    
    if (data.processFullMedia) {
      final updatedChapters = <VocabularyChapter>[];
      for (int i = 0; i < vocabulary.chapters.length; i++) {
        final chapter = vocabulary.chapters[i];
        VocabularyChapter updatedChapter = chapter;
        
        if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
          final cachedPath = await data.localDataSource.getCachedImagePath(chapter.imageUrl!, vocabulary.id, 'chapter_$i');
          if (cachedPath != null) {
            updatedChapter = updatedChapter.copyWith(
              imagePath: cachedPath,
              imageUrl: null,
            );
          } else {
            updatedChapter = updatedChapter.copyWith(imagePath: null);
          }
        }
        
        final updatedWords = <VocabularyWord>[];
        for (int j = 0; j < chapter.words.length; j++) {
          final word = chapter.words[j];
          VocabularyWord updatedWord = word;
          
          if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
            final cachedPath = await data.localDataSource.getCachedImagePath(word.imageUrl!, vocabulary.id, 'word_${i}_$j');
            if (cachedPath != null) {
              updatedWord = updatedWord.copyWith(
                imagePath: cachedPath,
                imageUrl: null,
              );
            } else {
              updatedWord = updatedWord.copyWith(imagePath: null);
            }
          }

          if (word.audioUrl != null && word.audioUrl!.isNotEmpty) {
            final cachedPath = await data.localDataSource.getCachedAudioPath(word.audioUrl!, vocabulary.id, 'word_audio_${i}_$j');
            if (cachedPath != null) {
              updatedWord = updatedWord.copyWith(
                audioPath: cachedPath,
                audioUrl: null,
              );
            } else {
              updatedWord = updatedWord.copyWith(audioPath: null);
            }
          }
          
          final updatedMeanings = <WordMeaning>[];
          for (int k = 0; k < word.meanings.length; k++) {
            final meaning = word.meanings[k];
            WordMeaning updatedMeaning = meaning;
            
            if (meaning.imageUrl != null && meaning.imageUrl!.isNotEmpty) {
              final cachedPath = await data.localDataSource.getCachedImagePath(meaning.imageUrl!, vocabulary.id, 'meaning_${i}_${j}_$k');
              if (cachedPath != null) {
                updatedMeaning = updatedMeaning.copyWith(
                  imagePath: cachedPath,
                  imageUrl: null,
                );
              } else {
                updatedMeaning = updatedMeaning.copyWith(imagePath: null);
              }
            }

            if (meaning.audioUrl != null && meaning.audioUrl!.isNotEmpty) {
              final cachedPath = await data.localDataSource.getCachedAudioPath(meaning.audioUrl!, vocabulary.id, 'meaning_audio_${i}_${j}_$k');
              if (cachedPath != null) {
                updatedMeaning = updatedMeaning.copyWith(
                  audioPath: cachedPath,
                  audioUrl: null,
                );
              } else {
                updatedMeaning = updatedMeaning.copyWith(audioPath: null);
              }
            }
            
            updatedMeanings.add(updatedMeaning);
          }
          
          final updatedExamples = <WordExample>[];
          for (int l = 0; l < word.examples.length; l++) {
            final example = word.examples[l];
            WordExample updatedExample = example;
            
            if (example.imageUrl != null && example.imageUrl!.isNotEmpty) {
              final cachedPath = await data.localDataSource.getCachedImagePath(example.imageUrl!, vocabulary.id, 'example_${i}_${j}_$l');
              if (cachedPath != null) {
                updatedExample = updatedExample.copyWith(
                  imagePath: cachedPath,
                  imageUrl: null,
                );
              } else {
                updatedExample = updatedExample.copyWith(imagePath: null);
              }
            }

            if (example.audioUrl != null && example.audioUrl!.isNotEmpty) {
              final cachedPath = await data.localDataSource.getCachedAudioPath(example.audioUrl!, vocabulary.id, 'example_audio_${i}_${j}_$l');
              if (cachedPath != null) {
                updatedExample = updatedExample.copyWith(
                  audioPath: cachedPath,
                  audioUrl: null,
                );
              } else {
                updatedExample = updatedExample.copyWith(audioPath: null);
              }
            }
            
            updatedExamples.add(updatedExample);
          }
          
          updatedWord = updatedWord.copyWith(
            meanings: updatedMeanings,
            examples: updatedExamples,
          );
          updatedWords.add(updatedWord);
          
          if (j % 2 == 0 && j > 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }
        
        updatedChapter = updatedChapter.copyWith(words: updatedWords);
        updatedChapters.add(updatedChapter);
        
        if (i % 2 == 0 && i > 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      final updatedPdfPaths = <String>[];
      for (int i = 0; i < vocabulary.pdfUrls.length; i++) {
        final pdfUrl = vocabulary.pdfUrls[i];
        final cachedPath = await data.localDataSource.getCachedPdfPath(pdfUrl, vocabulary.id, 'pdf_$i');
        if (cachedPath != null) {
          updatedPdfPaths.add(cachedPath);
        }
      }
      
      updatedVocabulary = updatedVocabulary.copyWith(
        chapters: updatedChapters,
        pdfPaths: updatedPdfPaths,
      );
    }
    
    processedVocabularies.add(updatedVocabulary);
    
    if (vocabularyIndex % 5 == 0 && vocabularyIndex > 0) {
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }
  
  return processedVocabularies;
}

class VocabulariesRepositoryImpl extends BaseRepository implements VocabulariesRepository {
  final VocabulariesRemoteDataSource remoteDataSource;
  final VocabulariesLocalDataSource localDataSource;
  final AuthService authService;
  
  static const Duration cacheValidityDuration = Duration(days: 3);

  VocabulariesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<List<VocabularyItem>>> getVocabularies({
    int page = 0,
    int pageSize = 5,
    BookLevel? level,
    SupportedLanguage? language,
  }) async {
    debugPrint('Getting vocabularies - page: $page, pageSize: $pageSize, level: ${level?.name}, language: ${language?.name}');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<VocabularyItem>>(
      () async {
        final cachedVocabularies = await localDataSource.getVocabulariesPage(page, pageSize);
        if (cachedVocabularies.isNotEmpty) {
          debugPrint('Returning ${cachedVocabularies.length} vocabularies from cache (page $page)');
          final processedVocabularies = await _processVocabulariesWithCoverImages(cachedVocabularies);
          return ApiResult.success(processedVocabularies);
        }
        
        if (page > 0) {
          final totalCached = await localDataSource.getVocabulariesCount();
          final currentCount = page * pageSize;

          if(totalCached > currentCount) {
            debugPrint('Requested page $page is within cached range but no data found');
            return ApiResult.success(<VocabularyItem>[]);
          }
        }
        
        return ApiResult.failure('No cached data available', FailureType.cache);
      },
      () async {
        final remoteVocabularies = await remoteDataSource.getVocabularies(
          page: page,
          pageSize: pageSize,
          level: level,
          language: language,
        );
        return ApiResult.success(remoteVocabularies);
      },
      cacheData: (remoteVocabularies) async {
        if (page == 0) {
          await _cacheVocabulariesDataOnly(remoteVocabularies);
          _cacheCoverImagesInBackground(remoteVocabularies);
        } else {
          await _updateCacheWithNewVocabulariesDataOnly(remoteVocabularies);
          _cacheCoverImagesInBackground(remoteVocabularies);
        }
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<VocabularyItem>>> getVocabulariesByLevel(
    BookLevel level, {
    int page = 0,
    int pageSize = 5,
  }) async {
    debugPrint('Getting vocabularies by level: ${level.name} - page: $page, pageSize: $pageSize');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<VocabularyItem>>(
      () async {
        final cachedVocabularies = await localDataSource.getVocabulariesByLevelPage(level, page, pageSize);
        if (cachedVocabularies.isNotEmpty) {
          debugPrint('Returning ${cachedVocabularies.length} level vocabularies from cache (page $page)');
          final processedVocabularies = await _processVocabulariesWithCoverImages(cachedVocabularies);
          return ApiResult.success(processedVocabularies);
        }
        
        if (page > 0) {
          final allCachedVocabularies = await localDataSource.getAllVocabularies();
          final levelVocabularies = allCachedVocabularies.where((vocabulary) => vocabulary.level == level).toList();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= levelVocabularies.length) {
            debugPrint('Requested level page $page is within cached range but no data found');
            return ApiResult.success(<VocabularyItem>[]);
          }
        }
        
        return ApiResult.failure('No cached level data available', FailureType.cache);
      },
      () async {
        final remoteVocabularies = await remoteDataSource.getVocabulariesByLevel(
          level,
          page: page,
          pageSize: pageSize,
        );
        return ApiResult.success(remoteVocabularies);
      },
      cacheData: (remoteVocabularies) async {
        await _updateCacheWithNewVocabulariesDataOnly(remoteVocabularies);
        _cacheCoverImagesInBackground(remoteVocabularies);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<VocabularyItem>>> getVocabulariesByLanguage(
    SupportedLanguage language, {
    int page = 0,
    int pageSize = 5,
  }) async {
    debugPrint('Getting vocabularies by language: ${language.name} - page: $page, pageSize: $pageSize');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<VocabularyItem>>(
      () async {
        final cachedVocabularies = await localDataSource.getVocabulariesByLanguagePage(language, page, pageSize);
        if (cachedVocabularies.isNotEmpty) {
          debugPrint('Returning ${cachedVocabularies.length} language vocabularies from cache (page $page)');
          final processedVocabularies = await _processVocabulariesWithCoverImages(cachedVocabularies);
          return ApiResult.success(processedVocabularies);
        }
        
        if (page > 0) {
          final allCachedVocabularies = await localDataSource.getAllVocabularies();
          final languageVocabularies = allCachedVocabularies.where((vocabulary) => vocabulary.primaryLanguage == language).toList();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= languageVocabularies.length) {
            debugPrint('Requested language page $page is within cached range but no data found');
            return ApiResult.success(<VocabularyItem>[]);
          }
        }
        
        return ApiResult.failure('No cached language data available', FailureType.cache);
      },
      () async {
        final remoteVocabularies = await remoteDataSource.getVocabulariesByLanguage(
          language,
          page: page,
          pageSize: pageSize,
        );
        return ApiResult.success(remoteVocabularies);
      },
      cacheData: (remoteVocabularies) async {
        await _updateCacheWithNewVocabulariesDataOnly(remoteVocabularies);
        _cacheCoverImagesInBackground(remoteVocabularies);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<bool>> hasMoreVocabularies(int currentCount) async {
    return handleRepositoryCall(
      () async {
        final hasMore = await remoteDataSource.hasMoreVocabularies(currentCount);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        final totalCached = await localDataSource.getVocabulariesCount();
        return ApiResult.success(currentCount < totalCached);
      },
    );
  }

  @override
  Future<ApiResult<bool>> hasMoreVocabulariesByLevel(BookLevel level, int currentCount) async {
    return handleRepositoryCall<bool>(
      () async {
        final hasMore = await remoteDataSource.hasMoreVocabulariesByLevel(level, currentCount);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        try {
          final cachedTotal = await localDataSource.getLevelVocabulariesCount(level);
          if (cachedTotal != null && await _isCacheValid()) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final cachedVocabularies = await localDataSource.getAllVocabularies();
          final levelVocabularies = cachedVocabularies.where((vocabulary) => vocabulary.level == level).length;
          return ApiResult.success(currentCount < levelVocabularies);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
    );
  }

  @override
  Future<ApiResult<bool>> hasMoreVocabulariesByLanguage(SupportedLanguage language, int currentCount) async {
    return handleRepositoryCall<bool>(
      () async {
        final hasMore = await remoteDataSource.hasMoreVocabulariesByLanguage(language, currentCount);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        try {
          final cachedTotal = await localDataSource.getLanguageVocabulariesCount(language);
          if (cachedTotal != null && await _isCacheValid()) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final cachedVocabularies = await localDataSource.getAllVocabularies();
          final languageVocabularies = cachedVocabularies.where((vocabulary) => vocabulary.primaryLanguage == language).length;
          return ApiResult.success(currentCount < languageVocabularies);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
    );
  }

  @override
  Future<ApiResult<List<VocabularyItem>>> hardRefreshVocabularies({int pageSize = 5}) async {
    debugPrint('Hard refresh vocabularies requested');

    final result = await handleRepositoryCall<List<VocabularyItem>>(
      () async {
        await _clearVocabulariesDataOnly();
        
        final remoteVocabularies = await remoteDataSource.getVocabularies(
          page: 0,
          pageSize: pageSize,
        );
        return ApiResult.success(remoteVocabularies);
      },
      cacheCall: () async {
        debugPrint('Hard refresh requested but offline - returning cached data');
        final cachedVocabularies = await localDataSource.getVocabulariesPage(0, pageSize);
        final processedVocabularies = await _processVocabulariesWithCoverImages(cachedVocabularies);
        return ApiResult.success(processedVocabularies);
      },
      cacheData: (remoteVocabularies) async {
        await _cacheVocabulariesDataOnly(remoteVocabularies);
        _cacheCoverImagesInBackground(remoteVocabularies);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<VocabularyItem>>> hardRefreshVocabulariesByLevel(BookLevel level, {int pageSize = 5}) async {
    debugPrint('Hard refresh vocabularies by level requested');
    
    final result = await handleRepositoryCall<List<VocabularyItem>>(
      () async {
        await _clearVocabulariesDataOnly();

        final remoteVocabularies = await remoteDataSource.getVocabulariesByLevel(
          level,
          page: 0,
          pageSize: pageSize,
        );
        return ApiResult.success(remoteVocabularies);
      },
      cacheCall: () async {
        debugPrint('Hard refresh level requested but offline - returning cached data');
        final cachedVocabularies = await localDataSource.getVocabulariesByLevelPage(level, 0, pageSize);
        final processedVocabularies = await _processVocabulariesWithCoverImages(cachedVocabularies);
        return ApiResult.success(processedVocabularies);
      },
      cacheData: (remoteVocabularies) async {
        await _updateCacheWithNewVocabulariesDataOnly(remoteVocabularies);
        _cacheCoverImagesInBackground(remoteVocabularies);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<VocabularyItem>>> hardRefreshVocabulariesByLanguage(SupportedLanguage language, {int pageSize = 5}) async {
    debugPrint('Hard refresh vocabularies by language requested');
    
    final result = await handleRepositoryCall<List<VocabularyItem>>(
      () async {
        await _clearVocabulariesDataOnly();

        final remoteVocabularies = await remoteDataSource.getVocabulariesByLanguage(
          language,
          page: 0,
          pageSize: pageSize,
        );
        return ApiResult.success(remoteVocabularies);
      },
      cacheCall: () async {
        debugPrint('Hard refresh language requested but offline - returning cached data');
        final cachedVocabularies = await localDataSource.getVocabulariesByLanguagePage(language, 0, pageSize);
        final processedVocabularies = await _processVocabulariesWithCoverImages(cachedVocabularies);
        return ApiResult.success(processedVocabularies);
      },
      cacheData: (remoteVocabularies) async {
        await _updateCacheWithNewVocabulariesDataOnly(remoteVocabularies);
        _cacheCoverImagesInBackground(remoteVocabularies);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<VocabularyItem>>> searchVocabularies(String query) async {
    if (query.trim().length < 2) {
      return ApiResult.success([]);
    }

    try {
      final cachedVocabularies = await localDataSource.getAllVocabularies();
      final cachedResults = _searchInVocabularies(cachedVocabularies, query);
      
      if (await networkInfo.isConnected) {
        try {
          final remoteResults = await remoteDataSource.searchVocabularies(query);
          
          if (remoteResults.isNotEmpty) {
            await _updateCacheWithNewVocabulariesDataOnly(remoteResults);
            _cacheCoverImagesInBackground(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          debugPrint('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processVocabulariesWithCoverImages(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          debugPrint('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processVocabulariesWithCoverImages(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        debugPrint('Offline search returned ${cachedResults.length} cached results');
        final processedResults = await _processVocabulariesWithCoverImages(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedVocabularies = await localDataSource.getAllVocabularies();
        final cachedResults = _searchInVocabularies(cachedVocabularies, query);
        final processedResults = await _processVocabulariesWithCoverImages(cachedResults);
        return ApiResult.success(processedResults);
      } catch (cacheError) {
        return ExceptionMapper.mapExceptionToApiResult(e as Exception);
      }
    }
  }

  @override
  Future<ApiResult<VocabularyItem?>> getVocabularyById(String vocabularyId) async {
    try {
      final result = await handleCacheFirstCall<VocabularyItem?>(
        () async {
          final cachedVocabularies = await localDataSource.getAllVocabularies();
          final cachedVocabulary = cachedVocabularies.where((v) => v.id == vocabularyId).firstOrNull;
          
          if (cachedVocabulary == null) {
            return ApiResult.failure('No cached vocabulary found', FailureType.cache);
          }
          
          final hasAllMedia = await _hasAllMediaCachedForVocabulary(cachedVocabulary);
          
          if (await _isCacheValid() && hasAllMedia) {
            final processedVocabularies = await _processVocabularyWithAllMedia([cachedVocabulary]);
            return ApiResult.success(processedVocabularies.isNotEmpty ? processedVocabularies.first : null);
          }
          
          debugPrint('Cache expired or media missing for vocabulary ${cachedVocabulary.id}, will refresh from remote');
          return ApiResult.failure('Cache expired or media missing', FailureType.cache);
        },
        () async {
          final remoteVocabulary = await remoteDataSource.getVocabularyById(vocabularyId);
          return ApiResult.success(remoteVocabulary);
        },
        cacheData: (remoteVocabulary) async {
          if (remoteVocabulary != null) {
            await localDataSource.updateVocabulary(remoteVocabulary);
            await _updateVocabularyHash(remoteVocabulary);
            debugPrint('Caching full media for individual vocabulary: ${remoteVocabulary.id}');
            _cacheFullVocabularyMediaInBackground([remoteVocabulary]);
          }
        },
      );
      
      return result;
    } catch (e) {
      return ExceptionMapper.mapExceptionToApiResult(e as Exception);
    }
  }

  @override
  Future<ApiResult<void>> recordVocabularyView(String vocabularyId, String userId) async {
    return handleRepositoryCall<void>(
      () async {
        await remoteDataSource.recordVocabularyView(vocabularyId, userId);
        return ApiResult.success(null);
      },
      cacheCall: () async {
        debugPrint('Cannot record vocabulary view offline');
        return ApiResult.success(null);
      },
    );
  }

  @override
  Future<ApiResult<void>> rateVocabulary(String vocabularyId, String userId, double rating) async {
    return handleRepositoryCall<void>(
      () async {
        await remoteDataSource.rateVocabulary(vocabularyId, userId, rating);
        return ApiResult.success(null);
      },
      cacheCall: () async {
        debugPrint('Cannot rate vocabulary offline');
        return ApiResult.success(null);
      },
    );
  }

  Future<List<VocabularyItem>> _processVocabulariesWithCoverImages(List<VocabularyItem> vocabularies) async {
    if (vocabularies.isEmpty) return vocabularies;

    final processData = MediaProcessingData(
      vocabularies: vocabularies,
      localDataSource: localDataSource,
      processFullMedia: false,
      token: RootIsolateToken.instance!,
    );
    
    return await compute(_processVocabulariesInIsolate, processData);
  }

  Future<List<VocabularyItem>> _processVocabularyWithAllMedia(List<VocabularyItem> vocabularies) async {
    if (vocabularies.isEmpty) return vocabularies;

    final processData = MediaProcessingData(
      vocabularies: vocabularies,
      localDataSource: localDataSource,
      processFullMedia: true,
      token: RootIsolateToken.instance!,
    );
    
    return await compute(_processVocabulariesInIsolate, processData);
  }

  Future<bool> _hasAllMediaCachedForVocabulary(VocabularyItem vocabulary) async {
    try {
      final chapterImageItems = <MediaItem>[];
      final wordImageItems = <MediaItem>[];
      final wordAudioItems = <MediaItem>[];
      final meaningImageItems = <MediaItem>[];
      final meaningAudioItems = <MediaItem>[];
      final exampleImageItems = <MediaItem>[];
      final exampleAudioItems = <MediaItem>[];

      for (int i = 0; i < vocabulary.chapters.length; i++) {
        final chapter = vocabulary.chapters[i];
        
        if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
          chapterImageItems.add(MediaItem(
            url: chapter.imageUrl!,
            chapterIndex: i,
            wordIndex: -1,
          ));
        }
        
        for (int j = 0; j < chapter.words.length; j++) {
          final word = chapter.words[j];
          
          if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
            wordImageItems.add(MediaItem(
              url: word.imageUrl!,
              chapterIndex: i,
              wordIndex: j,
            ));
          }
          
          if (word.audioUrl != null && word.audioUrl!.isNotEmpty) {
            wordAudioItems.add(MediaItem(
              url: word.audioUrl!,
              chapterIndex: i,
              wordIndex: j,
            ));
          }
          
          for (int k = 0; k < word.meanings.length; k++) {
            final meaning = word.meanings[k];
            
            if (meaning.imageUrl != null && meaning.imageUrl!.isNotEmpty) {
              meaningImageItems.add(MediaItem(
                url: meaning.imageUrl!,
                chapterIndex: i,
                wordIndex: j,
                meaningIndex: k,
              ));
            }
            
            if (meaning.audioUrl != null && meaning.audioUrl!.isNotEmpty) {
              meaningAudioItems.add(MediaItem(
                url: meaning.audioUrl!,
                chapterIndex: i,
                wordIndex: j,
                meaningIndex: k,
              ));
            }
          }
          
          for (int l = 0; l < word.examples.length; l++) {
            final example = word.examples[l];
            
            if (example.imageUrl != null && example.imageUrl!.isNotEmpty) {
              exampleImageItems.add(MediaItem(
                url: example.imageUrl!,
                chapterIndex: i,
                wordIndex: j,
                exampleIndex: l,
              ));
            }
            
            if (example.audioUrl != null && example.audioUrl!.isNotEmpty) {
              exampleAudioItems.add(MediaItem(
                url: example.audioUrl!,
                chapterIndex: i,
                wordIndex: j,
                exampleIndex: l,
              ));
            }
          }
        }
      }

      final mediaCheckData = FullMediaCheckData(
        vocabularyId: vocabulary.id,
        chapterImageItems: chapterImageItems,
        wordImageItems: wordImageItems,
        wordAudioItems: wordAudioItems,
        meaningImageItems: meaningImageItems,
        meaningAudioItems: meaningAudioItems,
        exampleImageItems: exampleImageItems,
        exampleAudioItems: exampleAudioItems,
        pdfUrls: vocabulary.pdfUrls,
        localDataSource: localDataSource,
        token: RootIsolateToken.instance!,
      );
      
      final hasAllMedia = await compute(_checkFullMediaCached, mediaCheckData);
      
      if (hasAllMedia) {
        debugPrint('All media cached for vocabulary: ${vocabulary.id}');
      } else {
        debugPrint('Some media missing for vocabulary: ${vocabulary.id}');
      }
      
      return hasAllMedia;
    } catch (e) {
      debugPrint('Error checking cached media for vocabulary: ${vocabulary.id}, error: $e');
      return false;
    }
  }

  Future<bool> _isCacheValid() async {
    try {
      final lastSyncTime = await localDataSource.getLastSyncTime();
      if (lastSyncTime == null) return false;
      
      final cacheAge = DateTime.now().difference(lastSyncTime);
      final isValid = cacheAge < cacheValidityDuration;
      
      if (!isValid) {
        debugPrint('Cache expired: age=${cacheAge.inMinutes}min, limit=${cacheValidityDuration.inMinutes}min');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> _manageCacheValidity() async {
    try {
      final isValid = await _isCacheValid();
      if (!isValid) {
        if (await networkInfo.isConnected) {
          debugPrint('Cache expired and online, clearing vocabulary data only (keeping media files for reuse)');
          await _clearVocabulariesDataOnly();
        } else {
          debugPrint('Cache expired but offline, keeping expired cache for offline access');
        }
      }
    } catch (e) {
      debugPrint('Error managing cache validity: $e');
    }
  }

  Future<void> _cacheVocabulariesDataOnly(List<VocabularyItem> vocabularies) async {
    try {
      await localDataSource.saveVocabularies(vocabularies);
      await localDataSource.setLastSyncTime(DateTime.now());
      await _updateVocabulariesHashes(vocabularies);
      
      debugPrint('Cached ${vocabularies.length} vocabularies data only (media cached separately based on URLs)');
    } catch (e) {
      debugPrint('Failed to cache vocabularies data: $e');
    }
  }

  Future<void> _updateCacheWithNewVocabulariesDataOnly(List<VocabularyItem> newVocabularies) async {
    try {
      for (final vocabulary in newVocabularies) {
        await localDataSource.addVocabulary(vocabulary);
        await _updateVocabularyHash(vocabulary);
      }
      
      debugPrint('Added ${newVocabularies.length} new vocabularies data to cache (media cached separately based on URLs)');
    } catch (e) {
      debugPrint('Failed to update cache with new vocabularies data: $e');
    }
  }
  
  void _cacheFullVocabularyMediaInBackground(List<VocabularyItem> vocabularies) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background full media caching for ${vocabularies.length} vocabularies...');
        await _cacheFullVocabularyMedia(vocabularies);
        debugPrint('Completed background full media caching for ${vocabularies.length} vocabularies');
      } catch (e) {
        debugPrint('Background full media caching failed: $e');
      }
    });
  }

  void _cacheCoverImagesInBackground(List<VocabularyItem> vocabularies) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background cover image caching for ${vocabularies.length} vocabularies...');
        await _cacheCoverImages(vocabularies);
        debugPrint('Completed background cover image caching for ${vocabularies.length} vocabularies');
      } catch (e) {
        debugPrint('Background cover image caching failed: $e');
      }
    });
  }

  Future<void> _cacheCoverImages(List<VocabularyItem> vocabularies) async {
    try {
      for (int i = 0; i < vocabularies.length; i++) {
        final vocabulary = vocabularies[i];
        if (vocabulary.imageUrl != null && vocabulary.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(vocabulary.imageUrl!, vocabulary.id, 'main');
          if (cachedPath == null) {
            debugPrint('Caching cover image for vocabulary: ${vocabulary.id}');
            await localDataSource.cacheImage(vocabulary.imageUrl!, vocabulary.id, 'main');
          }
        }
        
        if (i % 3 == 0 && i > 0) {
          await Future.delayed(const Duration(milliseconds: 15));
        }
      }
    } catch (e) {
      debugPrint('Error caching cover images: $e');
    }
  }

  Future<void> _cacheFullVocabularyMedia(List<VocabularyItem> vocabularies) async {
    try {
      for (int vocabularyIndex = 0; vocabularyIndex < vocabularies.length; vocabularyIndex++) {
        final vocabulary = vocabularies[vocabularyIndex];
        
        if (vocabulary.imageUrl != null && vocabulary.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(vocabulary.imageUrl!, vocabulary.id, 'main');
          if (cachedPath == null) {
            await localDataSource.cacheImage(vocabulary.imageUrl!, vocabulary.id, 'main');
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }

        for (int i = 0; i < vocabulary.pdfUrls.length; i++) {
          final pdfUrl = vocabulary.pdfUrls[i];
          final cachedPath = await localDataSource.getCachedPdfPath(pdfUrl, vocabulary.id, 'pdf_$i');
          if (cachedPath == null) {
            await localDataSource.cachePdf(pdfUrl, vocabulary.id, 'pdf_$i');
            await Future.delayed(const Duration(milliseconds: 30));
          }
        }
        
        for (int i = 0; i < vocabulary.chapters.length; i++) {
          final chapter = vocabulary.chapters[i];
          
          if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedImagePath(chapter.imageUrl!, vocabulary.id, 'chapter_$i');
            if (cachedPath == null) {
              await localDataSource.cacheImage(chapter.imageUrl!, vocabulary.id, 'chapter_$i');
              await Future.delayed(const Duration(milliseconds: 10));
            }
          }

          for (int j = 0; j < chapter.words.length; j++) {
            final word = chapter.words[j];
            
            if (word.imageUrl != null && word.imageUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedImagePath(word.imageUrl!, vocabulary.id, 'word_${i}_$j');
              if (cachedPath == null) {
                await localDataSource.cacheImage(word.imageUrl!, vocabulary.id, 'word_${i}_$j');
                await Future.delayed(const Duration(milliseconds: 10));
              }
            }
            
            if (word.audioUrl != null && word.audioUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedAudioPath(word.audioUrl!, vocabulary.id, 'word_audio_${i}_$j');
              if (cachedPath == null) {
                await localDataSource.cacheAudio(word.audioUrl!, vocabulary.id, 'word_audio_${i}_$j');
                await Future.delayed(const Duration(milliseconds: 20));
              }
            }

            for (int k = 0; k < word.meanings.length; k++) {
              final meaning = word.meanings[k];
              
              if (meaning.imageUrl != null && meaning.imageUrl!.isNotEmpty) {
                final cachedPath = await localDataSource.getCachedImagePath(meaning.imageUrl!, vocabulary.id, 'meaning_${i}_${j}_$k');
                if (cachedPath == null) {
                  await localDataSource.cacheImage(meaning.imageUrl!, vocabulary.id, 'meaning_${i}_${j}_$k');
                  await Future.delayed(const Duration(milliseconds: 10));
                }
              }
              
              if (meaning.audioUrl != null && meaning.audioUrl!.isNotEmpty) {
                final cachedPath = await localDataSource.getCachedAudioPath(meaning.audioUrl!, vocabulary.id, 'meaning_audio_${i}_${j}_$k');
                if (cachedPath == null) {
                  await localDataSource.cacheAudio(meaning.audioUrl!, vocabulary.id, 'meaning_audio_${i}_${j}_$k');
                  await Future.delayed(const Duration(milliseconds: 20));
                }
              }
            }

            for (int l = 0; l < word.examples.length; l++) {
              final example = word.examples[l];
              
              if (example.imageUrl != null && example.imageUrl!.isNotEmpty) {
                final cachedPath = await localDataSource.getCachedImagePath(example.imageUrl!, vocabulary.id, 'example_${i}_${j}_$l');
                if (cachedPath == null) {
                  await localDataSource.cacheImage(example.imageUrl!, vocabulary.id, 'example_${i}_${j}_$l');
                  await Future.delayed(const Duration(milliseconds: 10));
                }
              }
              
              if (example.audioUrl != null && example.audioUrl!.isNotEmpty) {
                final cachedPath = await localDataSource.getCachedAudioPath(example.audioUrl!, vocabulary.id, 'example_audio_${i}_${j}_$l');
                if (cachedPath == null) {
                  await localDataSource.cacheAudio(example.audioUrl!, vocabulary.id, 'example_audio_${i}_${j}_$l');
                  await Future.delayed(const Duration(milliseconds: 20));
                }
              }
            }
            
            if (j % 2 == 0 && j > 0) {
              await Future.delayed(const Duration(milliseconds: 25));
            }
          }
          
          if (i % 1 == 0 && i > 0) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
        
        if (vocabularyIndex % 1 == 0 && vocabularyIndex > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      debugPrint('Error caching full vocabulary media: $e');
    }
  }

  Future<void> _clearVocabulariesDataOnly() async {
    try {
      await localDataSource.saveVocabularies([]);
      await localDataSource.setVocabularyHashes({});
      await localDataSource.setTotalVocabulariesCount(0);
      
      for (final level in BookLevel.values) {
        await localDataSource.setLevelVocabulariesCount(level, 0);
      }
      
      for (final language in SupportedLanguage.values) {
        await localDataSource.setLanguageVocabulariesCount(language, 0);
      }
      
      debugPrint('Cleared vocabulary data only, preserving media files for URL-based reuse');
    } catch (e) {
      debugPrint('Failed to clear vocabulary data: $e');
      try {
        await localDataSource.clearAllVocabularies();
        debugPrint('Fallback: cleared all vocabularies including media');
      } catch (fallbackError) {
        debugPrint('Fallback clear also failed: $fallbackError');
      }
    }
  }

  Future<void> _updateVocabulariesHashes(List<VocabularyItem> vocabularies) async {
    final hashes = <String, String>{};
    for (final vocabulary in vocabularies) {
      hashes[vocabulary.id] = _generateVocabularyHash(vocabulary);
    }
    await localDataSource.setVocabularyHashes(hashes);
  }

  Future<void> _updateVocabularyHash(VocabularyItem vocabulary) async {
    final currentHashes = await localDataSource.getVocabularyHashes();
    currentHashes[vocabulary.id] = _generateVocabularyHash(vocabulary);
    await localDataSource.setVocabularyHashes(currentHashes);
  }

  String _generateVocabularyHash(VocabularyItem vocabulary) {
    final content = '${vocabulary.title}_${vocabulary.description}_${vocabulary.chapters.length}_${vocabulary.updatedAt?.millisecondsSinceEpoch ?? 0}';
    return content.hashCode.toString();
  }

  List<VocabularyItem> _combineAndDeduplicateResults(
    List<VocabularyItem> cachedVocabularies,
    List<VocabularyItem> remoteVocabularies,
  ) {
    final Map<String, VocabularyItem> uniqueVocabularies = {};
    
    for (final vocabulary in cachedVocabularies) {
      uniqueVocabularies[vocabulary.id] = vocabulary;
    }
    
    for (final vocabulary in remoteVocabularies) {
      uniqueVocabularies[vocabulary.id] = vocabulary;
    }
    
    return uniqueVocabularies.values.toList();
  }

  List<VocabularyItem> _searchInVocabularies(List<VocabularyItem> vocabularies, String query) {
    final normalizedQuery = query.toLowerCase();
    
    return vocabularies.where((vocabulary) {
      return vocabulary.title.toLowerCase().contains(normalizedQuery) ||
             vocabulary.description.toLowerCase().contains(normalizedQuery) ||
             vocabulary.primaryLanguage.displayName.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}