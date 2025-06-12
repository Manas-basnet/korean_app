import 'dart:developer' as dev;
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/core/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/core/services/auth_service.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_remote_datasource.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';
import 'package:korean_language_app/core/shared/models/test_question.dart';
import 'package:korean_language_app/core/enums/question_type.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';

class TestsRepositoryImpl extends BaseRepository implements TestsRepository {
  final TestsRemoteDataSource remoteDataSource;
  final TestsLocalDataSource localDataSource;
  final AuthService authService;
  
  static const Duration cacheValidityDuration = Duration(hours: 1, minutes: 30);

  TestsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<List<TestItem>>> getTests({int page = 0, int pageSize = 5}) async {
    dev.log('Getting tests - page: $page, pageSize: $pageSize');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<TestItem>>(
      () async {
        final cachedTests = await localDataSource.getTestsPage(page, pageSize);
        if (cachedTests.isNotEmpty) {
          dev.log('Returning ${cachedTests.length} tests from cache (page $page)');
          final processedTests = await _processTestsWithMedia(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final totalCached = await localDataSource.getTestsCount();
          final currentCount = page * pageSize;

          if(totalCached > currentCount) {
            dev.log('Requested page $page is within cached range but no data found');
            return ApiResult.success(<TestItem>[]);
          }

        }
        
        return ApiResult.failure('No cached data available', FailureType.cache);
      },
      () async {
        final remoteTests = await remoteDataSource.getTests(page: page, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheData: (remoteTests) async {
        if (page == 0) {
          await _cacheTestsDataOnly(remoteTests);
          _cacheTestMediaInBackground(remoteTests);
        } else {
          await _updateCacheWithNewTestsDataOnly(remoteTests);
          _cacheTestMediaInBackground(remoteTests);
        }
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final firstItem = result.data!.isNotEmpty ? result.data!.first : null;
      if (firstItem != null && (firstItem.imagePath == null || firstItem.imagePath!.isEmpty)) {
        final processedTests = await _processTestsWithMedia(result.data!);
        return ApiResult.success(processedTests);
      }
    }
    
    return result;
  }

  @override
  Future<ApiResult<List<TestItem>>> getTestsByCategory(TestCategory category, {int page = 0, int pageSize = 5}) async {
    final categoryString = category.toString().split('.').last;
    dev.log('Getting tests by category: $categoryString - page: $page, pageSize: $pageSize');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<TestItem>>(
      () async {
        final cachedTests = await localDataSource.getTestsByCategoryPage(categoryString, page, pageSize);
        if (cachedTests.isNotEmpty) {
          dev.log('Returning ${cachedTests.length} category tests from cache (page $page)');
          final processedTests = await _processTestsWithMedia(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final allCachedTests = await localDataSource.getAllTests();
          final categoryTests = allCachedTests.where((test) => test.category == category).toList();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= categoryTests.length) {
            dev.log('Requested category page $page is within cached range but no data found');
            return ApiResult.success(<TestItem>[]);
          }
        }
        
        return ApiResult.failure('No cached category data available', FailureType.cache);
      },
      () async {
        final remoteTests = await remoteDataSource.getTestsByCategory(category, page: page, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheData: (remoteTests) async {
        await _updateCacheWithNewTestsDataOnly(remoteTests);
        _cacheTestMediaInBackground(remoteTests);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final firstItem = result.data!.isNotEmpty ? result.data!.first : null;
      if (firstItem != null && (firstItem.imagePath == null || firstItem.imagePath!.isEmpty)) {
        final processedTests = await _processTestsWithMedia(result.data!);
        return ApiResult.success(processedTests);
      }
    }
    
    return result;
  }
  // Tried to use cache first call but it didn't work
  // @override
  // Future<ApiResult<bool>> hasMoreTests(int currentCount) async {
  //   return handleCacheFirstCall<bool>(
  //     () async {
  //       try {
  //         final cachedTotal = await localDataSource.getTotalTestsCount();
  //         if (cachedTotal != null && await _isCacheValid()) {
  //           return ApiResult.success(currentCount < cachedTotal);
  //         }
          
  //         final totalCached = await localDataSource.getTestsCount();
  //         return ApiResult.success(currentCount < totalCached);
  //       } catch (e) {
  //         return ApiResult.failure('Cache check failed', FailureType.cache);
  //       }
  //     },
  //     () async {
  //       final hasMore = await remoteDataSource.hasMoreTests(currentCount);
  //       return ApiResult.success(hasMore);
  //     },
  //   );
  // }

  @override
  Future<ApiResult<bool>> hasMoreTests(int currentCount) async {
    return handleRepositoryCall(
      () async {
        final hasMore = await remoteDataSource.hasMoreTests(currentCount);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        final totalCached = await localDataSource.getTestsCount();
        return ApiResult.success(currentCount < totalCached);
      },
    );
  }

  @override
  Future<ApiResult<bool>> hasMoreTestsByCategory(TestCategory category, int currentCount) async {
    final categoryString = category.toString().split('.').last;
    
    return handleCacheFirstCall<bool>(
      () async {
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
      () async {
        final hasMore = await remoteDataSource.hasMoreTestsByCategory(category, currentCount);
        return ApiResult.success(hasMore);
      },
    );
  }

  @override
  Future<ApiResult<List<TestItem>>> hardRefreshTests({int pageSize = 5}) async {
    dev.log('Hard refresh requested');

    final result = await handleRepositoryCall<List<TestItem>>(
      () async {
        await localDataSource.clearAllTests();
        
        final remoteTests = await remoteDataSource.getTests(page: 0, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheCall: () async {
        dev.log('Hard refresh requested but offline - returning cached data');
        final cachedTests = await localDataSource.getTestsPage(0, pageSize);
        final processedTests = await _processTestsWithMedia(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _cacheTestsDataOnly(remoteTests);
        _cacheTestMediaInBackground(remoteTests);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final processedTests = await _processTestsWithMedia(result.data!);
      return ApiResult.success(processedTests);
    }
    
    return result;
  }

  @override
  Future<ApiResult<List<TestItem>>> hardRefreshTestsByCategory(TestCategory category, {int pageSize = 5}) async {
    dev.log('Hard refresh category requested');
    
    final result = await handleRepositoryCall<List<TestItem>>(
      () async {
        await localDataSource.clearAllTests();

        final remoteTests = await remoteDataSource.getTestsByCategory(category, page: 0, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheCall: () async {
        dev.log('Hard refresh category requested but offline - returning cached data');
        final categoryString = category.toString().split('.').last;
        final cachedTests = await localDataSource.getTestsByCategoryPage(categoryString, 0, pageSize);
        final processedTests = await _processTestsWithMedia(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _updateCacheWithNewTestsDataOnly(remoteTests);
        _cacheTestMediaInBackground(remoteTests);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final processedTests = await _processTestsWithMedia(result.data!);
      return ApiResult.success(processedTests);
    }
    
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
            _cacheTestMediaInBackground(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          dev.log('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processTestsWithMedia(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          dev.log('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processTestsWithMedia(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        dev.log('Offline search returned ${cachedResults.length} cached results');
        final processedResults = await _processTestsWithMedia(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedTests = await localDataSource.getAllTests();
        final cachedResults = _searchInTests(cachedTests, query);
        final processedResults = await _processTestsWithMedia(cachedResults);
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
          
          if (cachedTest != null && await _isCacheValid()) {
            final processedTests = await _processTestsWithMedia([cachedTest]);
            return ApiResult.success(processedTests.isNotEmpty ? processedTests.first : null);
          }
          
          if (cachedTest != null) {
            final processedTests = await _processTestsWithMedia([cachedTest]);
            dev.log('Returning expired cached test, will refresh from remote');
            return ApiResult.success(processedTests.isNotEmpty ? processedTests.first : null);
          }
          
          return ApiResult.failure('No cached test found', FailureType.cache);
        },
        () async {
          final remoteTest = await remoteDataSource.getTestById(testId);
          return ApiResult.success(remoteTest);
        },
        cacheData: (remoteTest) async {
          if (remoteTest != null) {
            await localDataSource.updateTest(remoteTest);
            await _updateTestHash(remoteTest);
            _cacheTestMediaInBackground([remoteTest]);
          }
        },
      );
      
      if (result.isSuccess && result.data != null) {
        if (result.data!.imagePath == null || result.data!.imagePath!.isEmpty) {
          final processedTests = await _processTestsWithMedia([result.data!]);
          return ApiResult.success(processedTests.isNotEmpty ? processedTests.first : null);
        }
      }
      
      return result;
    } catch (e) {
      return ExceptionMapper.mapExceptionToApiResult(e as Exception);
    }
  }

  Future<bool> _isCacheValid() async {
    try {
      final lastSyncTime = await localDataSource.getLastSyncTime();
      if (lastSyncTime == null) return false;
      
      final cacheAge = DateTime.now().difference(lastSyncTime);
      final isValid = cacheAge < cacheValidityDuration;
      
      if (!isValid) {
        dev.log('Cache expired: age=${cacheAge.inMinutes}min, limit=${cacheValidityDuration.inMinutes}min');
      }
      
      return isValid;
    } catch (e) {
      dev.log('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> _manageCacheValidity() async {
    try {
      final isValid = await _isCacheValid();
      if (!isValid) {
        if (await networkInfo.isConnected) {
          dev.log('Cache expired and online, clearing cache');
          await localDataSource.clearAllTests();
        } else {
          dev.log('Cache expired but offline, keeping expired cache for offline access');
        }
      }
    } catch (e) {
      dev.log('Error managing cache validity: $e');
    }
  }

  Future<void> _cacheTestsDataOnly(List<TestItem> tests) async {
    try {
      await localDataSource.saveTests(tests);
      await localDataSource.setLastSyncTime(DateTime.now());
      await _updateTestsHashes(tests);
      
      dev.log('Cached ${tests.length} tests data only (media will be cached in background)');
    } catch (e) {
      dev.log('Failed to cache tests data: $e');
    }
  }

  Future<void> _updateCacheWithNewTestsDataOnly(List<TestItem> newTests) async {
    try {
      for (final test in newTests) {
        await localDataSource.addTest(test);
        await _updateTestHash(test);
      }
      
      dev.log('Added ${newTests.length} new tests data to cache (media will be cached in background)');
    } catch (e) {
      dev.log('Failed to update cache with new tests data: $e');
    }
  }

  void _cacheTestMediaInBackground(List<TestItem> tests) {
    Future.microtask(() async {
      try {
        dev.log('Starting background media caching for ${tests.length} tests...');
        await _cacheTestMedia(tests);
        dev.log('Completed background media caching for ${tests.length} tests');
      } catch (e) {
        dev.log('Background media caching failed: $e');
      }
    });
  }

  Future<void> _cacheTestMedia(List<TestItem> tests) async {
    try {
      for (final test in tests) {
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
          await localDataSource.cacheImage(test.imageUrl!, test.id, 'main');
        }
        
        for (int i = 0; i < test.questions.length; i++) {
          final question = test.questions[i];
          
          if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
            await localDataSource.cacheImage(question.questionImageUrl!, test.id, 'question_$i');
          }

          if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
            await localDataSource.cacheAudio(question.questionAudioUrl!, test.id, 'question_audio_$i');
          }

          for (int j = 0; j < question.options.length; j++) {
            final option = question.options[j];
            
            if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
              await localDataSource.cacheImage(option.imageUrl!, test.id, 'answer_${i}_$j');
            }
            
            if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
              await localDataSource.cacheAudio(option.audioUrl!, test.id, 'answer_audio_${i}_$j');
            }
          }
        }
      }
    } catch (e) {
      dev.log('Error caching test media: $e');
    }
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

  Future<List<TestItem>> _processTestsWithMedia(List<TestItem> tests) async {
      try {
        final processedTests = <TestItem>[];
        
        for (final test in tests) {
          TestItem updatedTest = test;
          
          // Process main test image
          if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedImagePath(test.imageUrl!, test.id, 'main');
            if (cachedPath != null) {
              dev.log('Using cached image for test ${test.id}: $cachedPath');
              updatedTest = updatedTest.copyWith(imagePath: cachedPath);
            } else {
              dev.log('No cached image found for test ${test.id}, will use network URL');
              // Clear any existing invalid path
              if (test.imagePath != null && test.imagePath!.isNotEmpty) {
                updatedTest = updatedTest.copyWith(imagePath: null);
              }
            }
          }
          
          final updatedQuestions = <TestQuestion>[];
          for (int i = 0; i < test.questions.length; i++) {
            final question = test.questions[i];
            TestQuestion updatedQuestion = question;
            
            // Process question image
            if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedImagePath(
                question.questionImageUrl!, test.id, 'question_$i'
              );
              if (cachedPath != null) {
                dev.log('Using cached question image for test ${test.id}, question $i: $cachedPath');
                updatedQuestion = updatedQuestion.copyWith(questionImagePath: cachedPath);
              } else {
                dev.log('No cached question image found for test ${test.id}, question $i');
                // Clear any existing invalid path
                if (question.questionImagePath != null && question.questionImagePath!.isNotEmpty) {
                  updatedQuestion = updatedQuestion.copyWith(questionImagePath: null);
                }
              }
            }

            // Process question audio
            if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedAudioPath(
                question.questionAudioUrl!, test.id, 'question_audio_$i'
              );
              if (cachedPath != null) {
                dev.log('Using cached question audio for test ${test.id}, question $i: $cachedPath');
                updatedQuestion = updatedQuestion.copyWith(questionAudioPath: cachedPath);
              } else {
                dev.log('No cached question audio found for test ${test.id}, question $i');
                // Clear any existing invalid path
                if (question.questionAudioPath != null && question.questionAudioPath!.isNotEmpty) {
                  updatedQuestion = updatedQuestion.copyWith(questionAudioPath: null);
                }
              }
            }
            
            // Process answer options
            final updatedOptions = <AnswerOption>[];
            for (int j = 0; j < question.options.length; j++) {
              final option = question.options[j];
              AnswerOption updatedOption = option;
              
              // Process option image
              if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
                final cachedPath = await localDataSource.getCachedImagePath(
                  option.imageUrl!, test.id, 'answer_${i}_$j'
                );
                if (cachedPath != null) {
                  dev.log('Using cached answer image for test ${test.id}, question $i, option $j: $cachedPath');
                  updatedOption = updatedOption.copyWith(imagePath: cachedPath);
                } else {
                  dev.log('No cached answer image found for test ${test.id}, question $i, option $j');
                  // Clear any existing invalid path
                  if (option.imagePath != null && option.imagePath!.isNotEmpty) {
                    updatedOption = updatedOption.copyWith(imagePath: null);
                  }
                }
              }
              
              // Process option audio
              if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
                final cachedPath = await localDataSource.getCachedAudioPath(
                  option.audioUrl!, test.id, 'answer_audio_${i}_$j'
                );
                if (cachedPath != null) {
                  dev.log('Using cached answer audio for test ${test.id}, question $i, option $j: $cachedPath');
                  updatedOption = updatedOption.copyWith(audioPath: cachedPath);
                } else {
                  dev.log('No cached answer audio found for test ${test.id}, question $i, option $j');
                  // Clear any existing invalid path
                  if (option.audioPath != null && option.audioPath!.isNotEmpty) {
                    updatedOption = updatedOption.copyWith(audioPath: null);
                  }
                }
              }
              
              updatedOptions.add(updatedOption);
            }
            
            updatedQuestion = updatedQuestion.copyWith(options: updatedOptions);
            updatedQuestions.add(updatedQuestion);
          }
          
          updatedTest = updatedTest.copyWith(questions: updatedQuestions);
          processedTests.add(updatedTest);
        }
        
        dev.log('Processed ${processedTests.length} tests with media paths');
        return processedTests;
      } catch (e) {
        dev.log('Error processing tests with media: $e');
        return tests; // Return original tests if processing fails
      }
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