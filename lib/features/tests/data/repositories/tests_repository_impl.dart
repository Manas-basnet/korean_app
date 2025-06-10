import 'dart:developer' as dev;
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/core/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource_impl.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_remote_datasource.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';
import 'package:korean_language_app/core/shared/models/test_question.dart';
import 'package:korean_language_app/core/enums/question_type.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';

class TestsRepositoryImpl extends BaseRepository implements TestsRepository {
  final TestsRemoteDataSource remoteDataSource;
  final TestsLocalDataSourceImpl localDataSource;
  
  static const Duration cacheValidityDuration = Duration(hours: 1, minutes: 30);

  TestsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
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
          final processedTests = await _processTestsWithImages(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final totalCached = await localDataSource.getTestsCount();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= totalCached) {
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
          await _cacheTestsCompletely(remoteTests);
        } else {
          await _updateCacheWithNewTests(remoteTests);
        }
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final firstItem = result.data!.isNotEmpty ? result.data!.first : null;
      if (firstItem != null && (firstItem.imagePath == null || firstItem.imagePath!.isEmpty)) {
        final processedTests = await _processTestsWithImages(result.data!);
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
          final processedTests = await _processTestsWithImages(cachedTests);
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
        await _updateCacheWithNewTests(remoteTests);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final firstItem = result.data!.isNotEmpty ? result.data!.first : null;
      if (firstItem != null && (firstItem.imagePath == null || firstItem.imagePath!.isEmpty)) {
        final processedTests = await _processTestsWithImages(result.data!);
        return ApiResult.success(processedTests);
      }
    }
    
    return result;
  }

  @override
  Future<ApiResult<bool>> hasMoreTests(int currentCount) async {
    return handleCacheFirstCall<bool>(
      () async {
        try {
          final cachedTotal = await localDataSource.getTotalTestsCount();
          if (cachedTotal != null && await _isCacheValid()) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final totalCached = await localDataSource.getTestsCount();
          return ApiResult.success(currentCount < totalCached);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
      () async {
        // Remote call - only if cache is unavailable
        final hasMore = await remoteDataSource.hasMoreTests(currentCount);
        return ApiResult.success(hasMore);
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
        final processedTests = await _processTestsWithImages(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _cacheTestsCompletely(remoteTests);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final processedTests = await _processTestsWithImages(result.data!);
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
        final processedTests = await _processTestsWithImages(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _updateCacheWithNewTests(remoteTests);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final processedTests = await _processTestsWithImages(result.data!);
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
            await _updateCacheWithNewTests(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          dev.log('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processTestsWithImages(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          dev.log('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processTestsWithImages(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        dev.log('Offline search returned ${cachedResults.length} cached results');
        final processedResults = await _processTestsWithImages(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedTests = await localDataSource.getAllTests();
        final cachedResults = _searchInTests(cachedTests, query);
        final processedResults = await _processTestsWithImages(cachedResults);
        return ApiResult.success(processedResults);
      } catch (cacheError) {
        return ExceptionMapper.mapExceptionToApiResult(e as Exception);
      }
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

  @override
  Future<ApiResult<TestItem?>> getTestById(String testId) async {
    try {
      final result = await handleCacheFirstCall<TestItem?>(
        () async {
          final cachedTests = await localDataSource.getAllTests();
          final cachedTest = cachedTests.where((t) => t.id == testId).firstOrNull;
          
          if (cachedTest != null && await _isCacheValid()) {
            final processedTests = await _processTestsWithImages([cachedTest]);
            return ApiResult.success(processedTests.isNotEmpty ? processedTests.first : null);
          }
          
          if (cachedTest != null) {
            final processedTests = await _processTestsWithImages([cachedTest]);
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
          }
        },
      );
      
      if (result.isSuccess && result.data != null) {
        if (result.data!.imagePath == null || result.data!.imagePath!.isEmpty) {
          final processedTests = await _processTestsWithImages([result.data!]);
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

  Future<void> _cacheTestsCompletely(List<TestItem> tests) async {
    try {
      await localDataSource.saveTests(tests);
      await _cacheTestImages(tests);
      await localDataSource.setLastSyncTime(DateTime.now());
      await _updateTestsHashes(tests);
      
      dev.log('Completely cached ${tests.length} tests with images');
    } catch (e) {
      dev.log('Failed to cache tests completely: $e');
    }
  }

  Future<void> _updateCacheWithNewTests(List<TestItem> newTests) async {
    try {
      for (final test in newTests) {
        await localDataSource.addTest(test);
        await _updateTestHash(test);
      }

      await _cacheTestImages(newTests);
      
      dev.log('Added ${newTests.length} new tests to cache');
    } catch (e) {
      dev.log('Failed to update cache with new tests: $e');
    }
  }

  Future<void> _cacheTestImages(List<TestItem> tests) async {
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

          for (int j = 0; j < question.options.length; j++) {
            final option = question.options[j];
            if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
              await localDataSource.cacheImage(option.imageUrl!, test.id, 'answer_${i}_$j');
            }
          }
        }
      }
    } catch (e) {
      dev.log('Error caching test images: $e');
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

  Future<List<TestItem>> _processTestsWithImages(List<TestItem> tests) async {
    try {
      final processedTests = <TestItem>[];
      
      for (final test in tests) {
        TestItem updatedTest = test;
        
        // For cover image: only set imagePath to cached if no storage path exists
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(test.imageUrl!, test.id, 'main');
          if (cachedPath != null && (test.imagePath == null || test.imagePath!.isEmpty)) {
            // Only set cached path if there's no existing storage path
            updatedTest = updatedTest.copyWith(imagePath: cachedPath);
          }
        }
        
        final updatedQuestions = <TestQuestion>[];
        for (int i = 0; i < test.questions.length; i++) {
          final question = test.questions[i];
          TestQuestion updatedQuestion = question;
          
          // For question image: only set cached path if no storage path exists
          if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedImagePath(
              question.questionImageUrl!, test.id, 'question_$i'
            );
            if (cachedPath != null && (question.questionImagePath == null || question.questionImagePath!.isEmpty)) {
              updatedQuestion = updatedQuestion.copyWith(questionImagePath: cachedPath);
            }
          }
          
          final updatedOptions = <AnswerOption>[];
          for (int j = 0; j < question.options.length; j++) {
            final option = question.options[j];
            AnswerOption updatedOption = option;
            
            if (option.isImage && option.imageUrl != null && option.imageUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedImagePath(
                option.imageUrl!, test.id, 'answer_${i}_$j'
              );
              if (cachedPath != null && (option.imagePath == null || option.imagePath!.isEmpty)) {
                updatedOption = updatedOption.copyWith(imagePath: cachedPath);
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
      
      return processedTests;
    } catch (e) {
      dev.log('Error processing tests with images: $e');
      return tests;
    }
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