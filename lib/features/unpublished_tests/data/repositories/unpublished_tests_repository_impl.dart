import 'package:flutter/foundation.dart';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/unpublished_tests/data/datasources/unpublished_tests_local_datasource.dart';
import 'package:korean_language_app/features/unpublished_tests/data/datasources/unpublished_tests_remote_datasource.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';
import 'package:korean_language_app/shared/models/test_related/test_question.dart';
import 'package:korean_language_app/shared/enums/question_type.dart';
import 'package:korean_language_app/features/unpublished_tests/domain/repositories/unpublished_tests_repository.dart';

class UnpublishedTestsRepositoryImpl extends BaseRepository implements UnpublishedTestsRepository {
  final UnpublishedTestsRemoteDataSource remoteDataSource;
  final UnpublishedTestsLocalDataSource localDataSource;
  final AuthService authService;
  
  static const Duration cacheValidityDuration = Duration(hours: 1, minutes: 30);

  UnpublishedTestsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<List<TestItem>>> getUnpublishedTests({int page = 0, int pageSize = 5}) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    debugPrint('Getting unpublished tests for user: $userId - page: $page, pageSize: $pageSize');
    
    await _manageUnpublishedCacheValidity(userId);
    
    final result = await handleCacheFirstCall<List<TestItem>>(
      () async {
        final cachedTests = await localDataSource.getUnpublishedTestsPage(userId, page, pageSize);
        if (cachedTests.isNotEmpty) {
          debugPrint('Returning ${cachedTests.length} unpublished tests from cache (page $page)');
          final processedTests = await _processTestsWithMedia(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final totalCached = await localDataSource.getUnpublishedTestsCount(userId);
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= totalCached) {
            debugPrint('Requested unpublished page $page is within cached range but no data found');
            return ApiResult.success(<TestItem>[]);
          }
        }
        
        return ApiResult.failure('No cached unpublished data available', FailureType.cache);
      },
      () async {
        final remoteTests = await remoteDataSource.getUnpublishedTests(userId, page: page, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheData: (remoteTests) async {
        if (page == 0) {
          await _cacheUnpublishedTestsDataOnly(userId, remoteTests);
          _cacheTestMediaInBackground(remoteTests);
        } else {
          await _updateUnpublishedCacheWithNewTestsDataOnly(userId, remoteTests);
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
  Future<ApiResult<List<TestItem>>> getUnpublishedTestsByCategory(TestCategory category, {int page = 0, int pageSize = 5}) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    final categoryString = category.toString().split('.').last;
    debugPrint('Getting unpublished tests by category: $categoryString for user: $userId - page: $page, pageSize: $pageSize');
    
    await _manageUnpublishedCacheValidity(userId);
    
    final result = await handleCacheFirstCall<List<TestItem>>(
      () async {
        final cachedTests = await localDataSource.getUnpublishedTestsByCategoryPage(userId, categoryString, page, pageSize);
        if (cachedTests.isNotEmpty) {
          debugPrint('Returning ${cachedTests.length} unpublished category tests from cache (page $page)');
          final processedTests = await _processTestsWithMedia(cachedTests);
          return ApiResult.success(processedTests);
        }
        
        if (page > 0) {
          final allCachedTests = await localDataSource.getAllUnpublishedTests(userId);
          final categoryTests = allCachedTests.where((test) => test.category == category).toList();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= categoryTests.length) {
            debugPrint('Requested unpublished category page $page is within cached range but no data found');
            return ApiResult.success(<TestItem>[]);
          }
        }
        
        return ApiResult.failure('No cached unpublished category data available', FailureType.cache);
      },
      () async {
        final remoteTests = await remoteDataSource.getUnpublishedTestsByCategory(userId, category, page: page, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheData: (remoteTests) async {
        await _updateUnpublishedCacheWithNewTestsDataOnly(userId, remoteTests);
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

  @override
  Future<ApiResult<bool>> hasMoreUnpublishedTests(int currentCount) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    return handleCacheFirstCall<bool>(
      () async {
        try {
          final cachedTotal = await localDataSource.getTotalUnpublishedTestsCount(userId);
          if (cachedTotal != null && await _isUnpublishedCacheValid(userId)) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final totalCached = await localDataSource.getUnpublishedTestsCount(userId);
          return ApiResult.success(currentCount < totalCached);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
      () async {
        final hasMore = await remoteDataSource.hasMoreUnpublishedTests(userId, currentCount);
        return ApiResult.success(hasMore);
      },
    );
  }

  @override
  Future<ApiResult<bool>> hasMoreUnpublishedTestsByCategory(TestCategory category, int currentCount) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    final categoryString = category.toString().split('.').last;
    
    return handleCacheFirstCall<bool>(
      () async {
        try {
          final cachedTotal = await localDataSource.getUnpublishedCategoryTestsCount(userId, categoryString);
          if (cachedTotal != null && await _isUnpublishedCacheValid(userId)) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final cachedTests = await localDataSource.getAllUnpublishedTests(userId);
          final categoryTests = cachedTests.where((test) => test.category == category).length;
          return ApiResult.success(currentCount < categoryTests);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
      () async {
        final hasMore = await remoteDataSource.hasMoreUnpublishedTestsByCategory(userId, category, currentCount);
        return ApiResult.success(hasMore);
      },
    );
  }

  @override
  Future<ApiResult<List<TestItem>>> hardRefreshUnpublishedTests({int pageSize = 5}) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    debugPrint('Hard refresh unpublished tests requested for user: $userId');

    final result = await handleRepositoryCall<List<TestItem>>(
      () async {
        await localDataSource.clearAllUnpublishedTests(userId);
        
        final remoteTests = await remoteDataSource.getUnpublishedTests(userId, page: 0, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheCall: () async {
        debugPrint('Hard refresh unpublished tests requested but offline - returning cached data');
        final cachedTests = await localDataSource.getUnpublishedTestsPage(userId, 0, pageSize);
        final processedTests = await _processTestsWithMedia(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _cacheUnpublishedTestsDataOnly(userId, remoteTests);
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
  Future<ApiResult<List<TestItem>>> hardRefreshUnpublishedTestsByCategory(TestCategory category, {int pageSize = 5}) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    debugPrint('Hard refresh unpublished tests by category requested for user: $userId');
    
    final result = await handleRepositoryCall<List<TestItem>>(
      () async {
        await localDataSource.clearAllUnpublishedTests(userId);

        final remoteTests = await remoteDataSource.getUnpublishedTestsByCategory(userId, category, page: 0, pageSize: pageSize);
        return ApiResult.success(remoteTests);
      },
      cacheCall: () async {
        debugPrint('Hard refresh unpublished category requested but offline - returning cached data');
        final categoryString = category.toString().split('.').last;
        final cachedTests = await localDataSource.getUnpublishedTestsByCategoryPage(userId, categoryString, 0, pageSize);
        final processedTests = await _processTestsWithMedia(cachedTests);
        return ApiResult.success(processedTests);
      },
      cacheData: (remoteTests) async {
        await _updateUnpublishedCacheWithNewTestsDataOnly(userId, remoteTests);
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
  Future<ApiResult<List<TestItem>>> searchUnpublishedTests(String query) async {
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return ApiResult.failure('User not authenticated', FailureType.auth);
    }

    if (query.trim().length < 2) {
      return ApiResult.success([]);
    }

    try {
      final cachedTests = await localDataSource.getAllUnpublishedTests(userId);
      final cachedResults = _searchInTests(cachedTests, query);
      
      if (await networkInfo.isConnected) {
        try {
          final remoteResults = await remoteDataSource.searchUnpublishedTests(userId, query);
          
          if (remoteResults.isNotEmpty) {
            await _updateUnpublishedCacheWithNewTestsDataOnly(userId, remoteResults);
            _cacheTestMediaInBackground(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          debugPrint('Unpublished search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processTestsWithMedia(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          debugPrint('Remote unpublished search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processTestsWithMedia(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        debugPrint('Offline unpublished search returned ${cachedResults.length} cached results');
        final processedResults = await _processTestsWithMedia(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedTests = await localDataSource.getAllUnpublishedTests(userId);
        final cachedResults = _searchInTests(cachedTests, query);
        final processedResults = await _processTestsWithMedia(cachedResults);
        return ApiResult.success(processedResults);
      } catch (cacheError) {
        return ExceptionMapper.mapExceptionToApiResult(e as Exception);
      }
    }
  }

  String _getCurrentUserId() {
    return authService.getCurrentUserId();
  }

  Future<bool> _isUnpublishedCacheValid(String userId) async {
    try {
      final lastSyncTime = await localDataSource.getLastUnpublishedSyncTime(userId);
      if (lastSyncTime == null) return false;
      
      final cacheAge = DateTime.now().difference(lastSyncTime);
      final isValid = cacheAge < cacheValidityDuration;
      
      if (!isValid) {
        debugPrint('Unpublished cache expired: age=${cacheAge.inMinutes}min, limit=${cacheValidityDuration.inMinutes}min');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('Error checking unpublished cache validity: $e');
      return false;
    }
  }

  Future<void> _manageUnpublishedCacheValidity(String userId) async {
    try {
      final isValid = await _isUnpublishedCacheValid(userId);
      if (!isValid) {
        if (await networkInfo.isConnected) {
          debugPrint('Unpublished cache expired and online, clearing cache');
          await localDataSource.clearAllUnpublishedTests(userId);
        } else {
          debugPrint('Unpublished cache expired but offline, keeping expired cache for offline access');
        }
      }
    } catch (e) {
      debugPrint('Error managing unpublished cache validity: $e');
    }
  }

  Future<void> _cacheUnpublishedTestsDataOnly(String userId, List<TestItem> tests) async {
    try {
      await localDataSource.saveUnpublishedTests(userId, tests);
      await localDataSource.setLastUnpublishedSyncTime(userId, DateTime.now());
      await _updateUnpublishedTestsHashes(userId, tests);
      
      debugPrint('Cached ${tests.length} unpublished tests data only for user: $userId (media will be cached in background)');
    } catch (e) {
      debugPrint('Failed to cache unpublished tests data: $e');
    }
  }

  Future<void> _updateUnpublishedCacheWithNewTestsDataOnly(String userId, List<TestItem> newTests) async {
    try {
      for (final test in newTests) {
        await localDataSource.addUnpublishedTest(userId, test);
        await _updateUnpublishedTestHash(userId, test);
      }
      
      debugPrint('Added ${newTests.length} new unpublished tests data to cache for user: $userId (media will be cached in background)');
    } catch (e) {
      debugPrint('Failed to update unpublished cache with new tests data: $e');
    }
  }

  void _cacheTestMediaInBackground(List<TestItem> tests) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background media caching for ${tests.length} unpublished tests...');
        await _cacheTestMedia(tests);
        debugPrint('Completed background media caching for ${tests.length} unpublished tests');
      } catch (e) {
        debugPrint('Background media caching failed: $e');
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
      debugPrint('Error caching test media: $e');
    }
  }

  Future<void> _updateUnpublishedTestsHashes(String userId, List<TestItem> tests) async {
    final hashes = <String, String>{};
    for (final test in tests) {
      hashes[test.id] = _generateTestHash(test);
    }
    await localDataSource.setUnpublishedTestHashes(userId, hashes);
  }

  Future<void> _updateUnpublishedTestHash(String userId, TestItem test) async {
    final currentHashes = await localDataSource.getUnpublishedTestHashes(userId);
    currentHashes[test.id] = _generateTestHash(test);
    await localDataSource.setUnpublishedTestHashes(userId, currentHashes);
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
        
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(test.imageUrl!, test.id, 'main');
          if (cachedPath != null && (test.imagePath == null || test.imagePath!.isEmpty)) {
            updatedTest = updatedTest.copyWith(imagePath: cachedPath);
          }
        }
        
        final updatedQuestions = <TestQuestion>[];
        for (int i = 0; i < test.questions.length; i++) {
          final question = test.questions[i];
          TestQuestion updatedQuestion = question;
          
          if (question.questionImageUrl != null && question.questionImageUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedImagePath(
              question.questionImageUrl!, test.id, 'question_$i'
            );
            if (cachedPath != null && (question.questionImagePath == null || question.questionImagePath!.isEmpty)) {
              updatedQuestion = updatedQuestion.copyWith(questionImagePath: cachedPath);
            }
          }

          if (question.questionAudioUrl != null && question.questionAudioUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedAudioPath(
              question.questionAudioUrl!, test.id, 'question_audio_$i'
            );
            if (cachedPath != null && (question.questionAudioPath == null || question.questionAudioPath!.isEmpty)) {
              updatedQuestion = updatedQuestion.copyWith(questionAudioPath: cachedPath);
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
            
            if (option.isAudio && option.audioUrl != null && option.audioUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedAudioPath(
                option.audioUrl!, test.id, 'answer_audio_${i}_$j'
              );
              if (cachedPath != null && (option.audioPath == null || option.audioPath!.isEmpty)) {
                updatedOption = updatedOption.copyWith(audioPath: cachedPath);
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
      debugPrint('Error processing tests with media: $e');
      return tests;
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