import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/tests/data/datasources/local/tests_local_datasource.dart';
import 'package:korean_language_app/features/tests/data/datasources/remote/tests_remote_datasource.dart';
import 'package:korean_language_app/features/tests/domain/entities/user_test_interation.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';
import 'package:korean_language_app/shared/models/test_related/test_question.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';

class MediaItem {
  final String url;
  final int questionIndex;
  final int optionIndex;
  
  MediaItem({
    required this.url,
    required this.questionIndex,
    required this.optionIndex,
  });
}

class FullMediaCheckData {
  final String testId;
  final List<MediaItem> questionImageItems;
  final List<MediaItem> questionAudioItems;
  final List<MediaItem> optionImageItems;
  final List<MediaItem> optionAudioItems;
  final TestsLocalDataSource localDataSource;
  final RootIsolateToken token;

  FullMediaCheckData({
    required this.testId,
    required this.questionImageItems,
    required this.questionAudioItems,
    required this.optionImageItems,
    required this.optionAudioItems,
    required this.localDataSource,
    required this.token,
  });
}


class MediaProcessingData {
  final List<TestItem> tests;
  final TestsLocalDataSource localDataSource;
  final bool processFullMedia;
  final RootIsolateToken token;

  MediaProcessingData({
    required this.tests,
    required this.localDataSource,
    required this.processFullMedia,
    required this.token,
  });
}

Future<bool> _checkFullMediaCached(FullMediaCheckData data) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  
  for (final item in data.questionImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.testId, 'question_${item.questionIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  for (final item in data.questionAudioItems) {
    final cachedPath = await data.localDataSource.getCachedAudioPath(item.url, data.testId, 'question_audio_${item.questionIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  for (final item in data.optionImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.testId, 'answer_${item.questionIndex}_${item.optionIndex}');
    if (cachedPath == null) {
      return false;
    }
  }

  for (final item in data.optionAudioItems) {
    final cachedPath = await data.localDataSource.getCachedAudioPath(item.url, data.testId, 'answer_audio_${item.questionIndex}_${item.optionIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  return true;
}

Future<List<TestItem>> _processTestsInIsolate(MediaProcessingData data) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  
  final processedTests = <TestItem>[];
  
  for (int testIndex = 0; testIndex < data.tests.length; testIndex++) {
    final test = data.tests[testIndex];
    TestItem updatedTest = test;
    
    if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
      final cachedPath = await data.localDataSource.getCachedImagePath(test.imageUrl!, test.id, 'main');
      if (cachedPath != null) {
        updatedTest = updatedTest.copyWith(
          imagePath: cachedPath,
          imageUrl: null
        );
      } else {
        updatedTest = updatedTest.copyWith(imagePath: null);
      }
    }
    
    if (data.processFullMedia) {
      final updatedQuestions = <TestQuestion>[];
      for (int i = 0; i < test.questions.length; i++) {
        final question = test.questions[i];
        TestQuestion updatedQuestion = question;
        
        if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
          final cachedPath = await data.localDataSource.getCachedImagePath(question.questionImageUrl!, test.id, 'question_$i');
          if (cachedPath != null) {
            updatedQuestion = updatedQuestion.copyWith(
              questionImagePath: cachedPath,
              questionImageUrl: null,
            );
          } else {
            updatedQuestion = updatedQuestion.copyWith(questionImagePath: null);
          }
        }

        if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
          final cachedPath = await data.localDataSource.getCachedAudioPath(question.questionAudioUrl!, test.id, 'question_audio_$i');
          if (cachedPath != null) {
            updatedQuestion = updatedQuestion.copyWith(
              questionAudioPath: cachedPath,
              questionAudioUrl: null,
            );
          } else {
            updatedQuestion = updatedQuestion.copyWith(questionAudioPath: null);
          }
        }
        
        final updatedOptions = <AnswerOption>[];
        for (int j = 0; j < question.options.length; j++) {
          final option = question.options[j];
          AnswerOption updatedOption = option;
          
          if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
            final cachedPath = await data.localDataSource.getCachedImagePath(option.imageUrl!, test.id, 'answer_${i}_$j');
            if (cachedPath != null) {
              updatedOption = updatedOption.copyWith(
                imagePath: cachedPath,
                imageUrl: null,
              );
            } else {
              updatedOption = updatedOption.copyWith(imagePath: null);
            }
          }
          
          if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
            final cachedPath = await data.localDataSource.getCachedAudioPath(option.audioUrl!, test.id, 'answer_audio_${i}_$j');
            if (cachedPath != null) {
              updatedOption = updatedOption.copyWith(
                audioPath: cachedPath,
                audioUrl: null,
              );
            } else {
              updatedOption = updatedOption.copyWith(audioPath: null);
            }
          }
          
          updatedOptions.add(updatedOption);
        }
        
        updatedQuestion = updatedQuestion.copyWith(options: updatedOptions);
        updatedQuestions.add(updatedQuestion);
        
        if (i % 2 == 0 && i > 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
      
      updatedTest = updatedTest.copyWith(questions: updatedQuestions);
    }
    
    processedTests.add(updatedTest);
    
    if (testIndex % 5 == 0 && testIndex > 0) {
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }
  
  return processedTests;
}

class TestsRepositoryImpl extends BaseRepository implements TestsRepository {
  final TestsRemoteDataSource remoteDataSource;
  final TestsLocalDataSource localDataSource;
  final AuthService authService;
  
  static const Duration cacheValidityDuration = Duration(days: 3);

  TestsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<List<TestItem>>> getTests({
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    debugPrint('Getting tests - page: $page, pageSize: $pageSize, sortType: ${sortType.name}');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<TestItem>>(
      () async {
        final cachedTests = await localDataSource.getTestsPage(page, pageSize, sortType: sortType);
        if (cachedTests.isNotEmpty) {
          debugPrint('Returning ${cachedTests.length} tests from cache (page $page, sortType: ${sortType.name})');
          final processedTests = await _processTestsWithCoverImages(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final totalCached = await localDataSource.getTestsCount();
          final currentCount = page * pageSize;

          if(totalCached > currentCount) {
            debugPrint('Requested page $page is within cached range but no data found');
            return ApiResult.success(<TestItem>[]);
          }
        }
        
        return ApiResult.failure('No cached data available', FailureType.cache);
      },
      () async {
        final remoteTests = await remoteDataSource.getTests(
          page: page, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteTests);
      },
      cacheData: (remoteTests) async {
        if (page == 0) {
          await _cacheTestsDataOnly(remoteTests);
          _cacheCoverImagesInBackground(remoteTests);
        } else {
          await _updateCacheWithNewTestsDataOnly(remoteTests);
          _cacheCoverImagesInBackground(remoteTests);
        }
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<TestItem>>> getTestsByCategory(
    TestCategory category, {
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    final categoryString = category.toString().split('.').last;
    debugPrint('Getting tests by category: $categoryString - page: $page, pageSize: $pageSize, sortType: ${sortType.name}');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<TestItem>>(
      () async {
        final cachedTests = await localDataSource.getTestsByCategoryPage(categoryString, page, pageSize, sortType: sortType);
        if (cachedTests.isNotEmpty) {
          debugPrint('Returning ${cachedTests.length} category tests from cache (page $page, sortType: ${sortType.name})');
          final processedTests = await _processTestsWithCoverImages(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final allCachedTests = await localDataSource.getAllTests();
          final categoryTests = allCachedTests.where((test) => test.category == category).toList();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= categoryTests.length) {
            debugPrint('Requested category page $page is within cached range but no data found');
            return ApiResult.success(<TestItem>[]);
          }
        }
        
        return ApiResult.failure('No cached category data available', FailureType.cache);
      },
      () async {
        final remoteTests = await remoteDataSource.getTestsByCategory(
          category, 
          page: page, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteTests);
      },
      cacheData: (remoteTests) async {
        await _updateCacheWithNewTestsDataOnly(remoteTests);
        _cacheCoverImagesInBackground(remoteTests);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<bool>> hasMoreTests(int currentCount, [TestSortType? sortType]) async {
    return handleRepositoryCall(
      () async {
        final hasMore = await remoteDataSource.hasMoreTests(currentCount, sortType);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        final totalCached = await localDataSource.getTestsCount();
        return ApiResult.success(currentCount < totalCached);
      },
    );
  }

  @override
  Future<ApiResult<bool>> hasMoreTestsByCategory(
    TestCategory category, 
    int currentCount, 
    [TestSortType? sortType]
  ) async {
    final categoryString = category.toString().split('.').last;
    
    return handleRepositoryCall<bool>(
      () async {
        final hasMore = await remoteDataSource.hasMoreTestsByCategory(category, currentCount, sortType);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        try {
          final cachedTotal = await localDataSource.getCategoryTestsCount(categoryString);
          if (cachedTotal != null && await _isCacheValid()) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final cachedTests = await localDataSource.getAllTests();
          final categoryTests = cachedTests.where((test) => test.category == category).length;
          return ApiResult.success(currentCount < categoryTests);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
    );
  }

  @override
  Future<ApiResult<List<TestItem>>> hardRefreshTests({
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    debugPrint('Hard refresh requested with sortType: ${sortType.name}');

    final result = await handleRepositoryCall<List<TestItem>>(
      () async {
        await _clearTestsDataOnly();
        
        final remoteTests = await remoteDataSource.getTests(
          page: 0, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteTests);
      },
      cacheCall: () async {
        debugPrint('Hard refresh requested but offline - returning cached data with sortType: ${sortType.name}');
        final cachedTests = await localDataSource.getTestsPage(0, pageSize, sortType: sortType);
        final processedTests = await _processTestsWithCoverImages(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _cacheTestsDataOnly(remoteTests);
        _cacheCoverImagesInBackground(remoteTests);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<TestItem>>> hardRefreshTestsByCategory(
    TestCategory category, {
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    debugPrint('Hard refresh category requested with sortType: ${sortType.name}');
    
    final result = await handleRepositoryCall<List<TestItem>>(
      () async {
        await _clearTestsDataOnly();

        final remoteTests = await remoteDataSource.getTestsByCategory(
          category, 
          page: 0, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteTests);
      },
      cacheCall: () async {
        debugPrint('Hard refresh category requested but offline - returning cached data with sortType: ${sortType.name}');
        final categoryString = category.toString().split('.').last;
        final cachedTests = await localDataSource.getTestsByCategoryPage(categoryString, 0, pageSize, sortType: sortType);
        final processedTests = await _processTestsWithCoverImages(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _updateCacheWithNewTestsDataOnly(remoteTests);
        _cacheCoverImagesInBackground(remoteTests);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<TestItem>>> searchTests(String query) async {
    if (query.trim().length < 2) {
      return ApiResult.success([]);
    }

    try {
      final cachedTests = await localDataSource.getAllTests();
      final cachedResults = _searchInTests(cachedTests, query);
      
      if (await networkInfo.isConnected) {
        try {
          final remoteResults = await remoteDataSource.searchTests(query);
          
          if (remoteResults.isNotEmpty) {
            await _updateCacheWithNewTestsDataOnly(remoteResults);
            _cacheCoverImagesInBackground(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          debugPrint('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processTestsWithCoverImages(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          debugPrint('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processTestsWithCoverImages(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        debugPrint('Offline search returned ${cachedResults.length} cached results');
        final processedResults = await _processTestsWithCoverImages(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedTests = await localDataSource.getAllTests();
        final cachedResults = _searchInTests(cachedTests, query);
        final processedResults = await _processTestsWithCoverImages(cachedResults);
        return ApiResult.success(processedResults);
      } catch (cacheError) {
        return ExceptionMapper.mapExceptionToApiResult(e as Exception);
      }
    }
  }

  @override
  Future<ApiResult<TestItem?>> getTestById(String testId) async {
    try {
      final result = await handleCacheFirstCall<TestItem?>(
        () async {
          final cachedTests = await localDataSource.getAllTests();
          final cachedTest = cachedTests.where((t) => t.id == testId).firstOrNull;
          
          if (cachedTest == null) {
            return ApiResult.failure('No cached test found', FailureType.cache);
          }
          
          final hasAllMedia = await _hasAllMediaCachedForTest(cachedTest);
          
          if (await _isCacheValid() && hasAllMedia) {
            final processedTests = await _processTestWithAllMedia([cachedTest]);
            return ApiResult.success(processedTests.isNotEmpty ? processedTests.first : null);
          }
          
          debugPrint('Cache expired or media missing for test ${cachedTest.id}, will refresh from remote');
          return ApiResult.failure('Cache expired or media missing', FailureType.cache);
        },
        () async {
          final remoteTest = await remoteDataSource.getTestById(testId);
          return ApiResult.success(remoteTest);
        },
        cacheData: (remoteTest) async {
          if (remoteTest != null) {
            await localDataSource.updateTest(remoteTest);
            await _updateTestHash(remoteTest);
            debugPrint('Caching full media for individual test: ${remoteTest.id}');
            _cacheFullTestMediaInBackground([remoteTest]);
          }
        },
      );
      
      return result;
    } catch (e) {
      return ExceptionMapper.mapExceptionToApiResult(e as Exception);
    }
  }

  @override
  Future<ApiResult<void>> recordTestView(String testId, String userId) async {
    return handleRepositoryCall<void>(
      () async {
        await remoteDataSource.recordTestView(testId, userId);
        return ApiResult.success(null);
      },
      cacheCall: () async {
        debugPrint('Cannot record test view offline');
        return ApiResult.success(null);
      },
    );
  }

  @override
  Future<ApiResult<void>> rateTest(String testId, String userId, double rating) async {
    return handleRepositoryCall<void>(
      () async {
        await remoteDataSource.rateTest(testId, userId, rating);
        return ApiResult.success(null);
      },
      cacheCall: () async {
        debugPrint('Cannot rate test offline');
        return ApiResult.success(null);
      },
    );
  }

  @override
  Future<ApiResult<UserTestInteraction?>> completeTestWithViewAndRating(String testId, String userId, double? rating, UserTestInteraction? userInteraction) async {
    return handleRepositoryCall<UserTestInteraction?>(
      () async {
        final updatedInteractionData = await remoteDataSource.completeTestWithViewAndRating(testId, userId, rating, userInteraction);
        return ApiResult.success(updatedInteractionData);
      },
      cacheCall: () async {
        debugPrint('Cannot complete test with view and rating offline');
        return ApiResult.success(null);
      },
      cacheData: (interaction) async {
        if (interaction != null) {
          localDataSource.saveUserTestInteraction(interaction);
        }
      },
    );
  }

  @override
  Future<ApiResult<UserTestInteraction?>> getUserTestInteraction(String testId, String userId) async {
    return handleCacheFirstCall<UserTestInteraction?>(
      () async {
        final interaction = await localDataSource.getUserTestInteraction(testId, userId);
        if(interaction == null) {
          return ApiResult.failure('No cached interaction found', FailureType.cache);
        } else {
          return ApiResult.success(interaction);
        }
      },
      () async {
        final interaction = await remoteDataSource.getUserTestInteraction(testId, userId);
        return ApiResult.success(interaction);
      },
      cacheData: (interaction) async {
        if (interaction != null) {
          await localDataSource.saveUserTestInteraction(interaction);
        }
      },
    );
  }

  Future<List<TestItem>> _processTestsWithCoverImages(List<TestItem> tests) async {
    if (tests.isEmpty) return tests;

    final processData = MediaProcessingData(
      tests: tests,
      localDataSource: localDataSource,
      processFullMedia: false,
      token: RootIsolateToken.instance!,
    );
    
    return await compute(_processTestsInIsolate, processData);
  }

  Future<List<TestItem>> _processTestWithAllMedia(List<TestItem> tests) async {
    if (tests.isEmpty) return tests;

    final processData = MediaProcessingData(
      tests: tests,
      localDataSource: localDataSource,
      processFullMedia: true,
      token: RootIsolateToken.instance!,
    );
    
    return await compute(_processTestsInIsolate, processData);
  }

  Future<bool> _hasAllMediaCachedForTest(TestItem test) async {
    try {
      final questionImageItems = <MediaItem>[];
      final questionAudioItems = <MediaItem>[];
      final optionImageItems = <MediaItem>[];
      final optionAudioItems = <MediaItem>[];

      for (int i = 0; i < test.questions.length; i++) {
        final question = test.questions[i];
        
        if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
          questionImageItems.add(MediaItem(
            url: question.questionImageUrl!,
            questionIndex: i,
            optionIndex: -1,
          ));
        }
        if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
          questionAudioItems.add(MediaItem(
            url: question.questionAudioUrl!,
            questionIndex: i,
            optionIndex: -1,
          ));
        }
        
        for (int j = 0; j < question.options.length; j++) {
          final option = question.options[j];
          if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
            optionImageItems.add(MediaItem(
              url: option.imageUrl!,
              questionIndex: i,
              optionIndex: j,
            ));
          }
          if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
            optionAudioItems.add(MediaItem(
              url: option.audioUrl!,
              questionIndex: i,
              optionIndex: j,
            ));
          }
        }
      }

      final mediaCheckData = FullMediaCheckData(
        testId: test.id,
        questionImageItems: questionImageItems,
        questionAudioItems: questionAudioItems,
        optionImageItems: optionImageItems,
        optionAudioItems: optionAudioItems,
        localDataSource: localDataSource,
        token: RootIsolateToken.instance!,
      );
      
      final hasAllMedia = await compute(_checkFullMediaCached, mediaCheckData);
      
      if (hasAllMedia) {
        debugPrint('All media cached for test: ${test.id}');
      } else {
        debugPrint('Some media missing for test: ${test.id}');
      }
      
      return hasAllMedia;
    } catch (e) {
      debugPrint('Error checking cached media for test: ${test.id}, error: $e');
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
          debugPrint('Cache expired and online, clearing test data only (keeping media files for reuse)');
          await _clearTestsDataOnly();
        } else {
          debugPrint('Cache expired but offline, keeping expired cache for offline access');
        }
      }
    } catch (e) {
      debugPrint('Error managing cache validity: $e');
    }
  }

  Future<void> _cacheTestsDataOnly(List<TestItem> tests) async {
    try {
      await localDataSource.saveTests(tests);
      await localDataSource.setLastSyncTime(DateTime.now());
      await _updateTestsHashes(tests);
      
      debugPrint('Cached ${tests.length} tests data only (media cached separately based on URLs)');
    } catch (e) {
      debugPrint('Failed to cache tests data: $e');
    }
  }

  Future<void> _updateCacheWithNewTestsDataOnly(List<TestItem> newTests) async {
    try {
      for (final test in newTests) {
        await localDataSource.addTest(test);
        await _updateTestHash(test);
      }
      
      debugPrint('Added ${newTests.length} new tests data to cache (media cached separately based on URLs)');
    } catch (e) {
      debugPrint('Failed to update cache with new tests data: $e');
    }
  }
  
  void _cacheFullTestMediaInBackground(List<TestItem> tests) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background full media caching for ${tests.length} tests...');
        await _cacheFullTestMedia(tests);
        debugPrint('Completed background full media caching for ${tests.length} tests');
      } catch (e) {
        debugPrint('Background full media caching failed: $e');
      }
    });
  }

  void _cacheCoverImagesInBackground(List<TestItem> tests) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background cover image caching for ${tests.length} tests...');
        await _cacheCoverImages(tests);
        debugPrint('Completed background cover image caching for ${tests.length} tests');
      } catch (e) {
        debugPrint('Background cover image caching failed: $e');
      }
    });
  }

  Future<void> _cacheCoverImages(List<TestItem> tests) async {
    try {
      for (int i = 0; i < tests.length; i++) {
        final test = tests[i];
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(test.imageUrl!, test.id, 'main');
          if (cachedPath == null) {
            debugPrint('Caching cover image for test: ${test.id}');
            await localDataSource.cacheImage(test.imageUrl!, test.id, 'main');
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

  Future<void> _cacheFullTestMedia(List<TestItem> tests) async {
    try {
      for (int testIndex = 0; testIndex < tests.length; testIndex++) {
        final test = tests[testIndex];
        
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(test.imageUrl!, test.id, 'main');
          if (cachedPath == null) {
            await localDataSource.cacheImage(test.imageUrl!, test.id, 'main');
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }
        
        for (int i = 0; i < test.questions.length; i++) {
          final question = test.questions[i];
          
          if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedImagePath(question.questionImageUrl!, test.id, 'question_$i');
            if (cachedPath == null) {
              await localDataSource.cacheImage(question.questionImageUrl!, test.id, 'question_$i');
              await Future.delayed(const Duration(milliseconds: 10));
            }
          }

          if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedAudioPath(question.questionAudioUrl!, test.id, 'question_audio_$i');
            if (cachedPath == null) {
              await localDataSource.cacheAudio(question.questionAudioUrl!, test.id, 'question_audio_$i');
              await Future.delayed(const Duration(milliseconds: 20));
            }
          }

          for (int j = 0; j < question.options.length; j++) {
            final option = question.options[j];
            
            if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedImagePath(option.imageUrl!, test.id, 'answer_${i}_$j');
              if (cachedPath == null) {
                await localDataSource.cacheImage(option.imageUrl!, test.id, 'answer_${i}_$j');
                await Future.delayed(const Duration(milliseconds: 10));
              }
            }
            
            if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedAudioPath(option.audioUrl!, test.id, 'answer_audio_${i}_$j');
              if (cachedPath == null) {
                await localDataSource.cacheAudio(option.audioUrl!, test.id, 'answer_audio_${i}_$j');
                await Future.delayed(const Duration(milliseconds: 20));
              }
            }
          }
          
          if (i % 2 == 0 && i > 0) {
            await Future.delayed(const Duration(milliseconds: 25));
          }
        }
        
        if (testIndex % 1 == 0 && testIndex > 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      debugPrint('Error caching full test media: $e');
    }
  }

  Future<void> _clearTestsDataOnly() async {
    try {
      await localDataSource.saveTests([]);
      await localDataSource.setTestHashes({});
      await localDataSource.setTotalTestsCount(0);
      
      final allKeys = await _getAllCategoryKeys();
      for (final key in allKeys) {
        await localDataSource.setCategoryTestsCount(key, 0);
      }
      
      debugPrint('Cleared test data only, preserving media files for URL-based reuse');
    } catch (e) {
      debugPrint('Failed to clear test data: $e');
      try {
        await localDataSource.clearAllTests();
        debugPrint('Fallback: cleared all tests including media');
      } catch (fallbackError) {
        debugPrint('Fallback clear also failed: $fallbackError');
      }
    }
  }

  Future<List<String>> _getAllCategoryKeys() async {
    final categoryKeys = <String>[];
    for (final category in TestCategory.values) {
      if (category != TestCategory.all) {
        categoryKeys.add(category.toString().split('.').last);
      }
    }
    return categoryKeys;
  }

  Future<void> _updateTestsHashes(List<TestItem> tests) async {
    final hashes = <String, String>{};
    for (final test in tests) {
      hashes[test.id] = _generateTestHash(test);
    }
    await localDataSource.setTestHashes(hashes);
  }

  Future<void> _updateTestHash(TestItem test) async {
    final currentHashes = await localDataSource.getTestHashes();
    currentHashes[test.id] = _generateTestHash(test);
    await localDataSource.setTestHashes(currentHashes);
  }

  String _generateTestHash(TestItem test) {
    final content = '${test.title}_${test.description}_${test.questions.length}_${test.updatedAt?.millisecondsSinceEpoch ?? 0}';
    return content.hashCode.toString();
  }

  List<TestItem> _combineAndDeduplicateResults(
    List<TestItem> cachedTests,
    List<TestItem> remoteTests,
  ) {
    final Map<String, TestItem> uniqueTests = {};
    
    for (final test in cachedTests) {
      uniqueTests[test.id] = test;
    }
    
    for (final test in remoteTests) {
      uniqueTests[test.id] = test;
    }
    
    return uniqueTests.values.toList();
  }

  List<TestItem> _searchInTests(List<TestItem> tests, String query) {
    final normalizedQuery = query.toLowerCase();
    
    return tests.where((test) {
      return test.title.toLowerCase().contains(normalizedQuery) ||
             test.description.toLowerCase().contains(normalizedQuery) ||
             test.language.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}