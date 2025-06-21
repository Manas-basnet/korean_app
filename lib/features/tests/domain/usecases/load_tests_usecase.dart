// lib/features/tests/domain/usecases/load_tests_usecase.dart

import 'dart:developer' as dev;
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_results.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class LoadTestsUseCase implements UseCase<TestsLoadResult, LoadTestsParams> {
  final TestsRepository repository;
  final AuthService authService;

  LoadTestsUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<TestsLoadResult>> execute(LoadTestsParams params) async {
    try {
      dev.log('LoadTestsUseCase: Loading tests with params - page: ${params.page}, '
          'pageSize: ${params.pageSize}, sortType: ${params.sortType.name}, '
          'category: ${params.category?.name}, forceRefresh: ${params.forceRefresh}');

      // Business Rule: Validate parameters
      if (params.page < 0) {
        return ApiResult.failure('Page number cannot be negative', FailureType.validation);
      }

      if (params.pageSize <= 0 || params.pageSize > 50) {
        return ApiResult.failure('Page size must be between 1 and 50', FailureType.validation);
      }

      // Business Rule: Determine loading strategy
      ApiResult<List<TestItem>> result;

      if (params.forceRefresh) {
        result = await _executeRefresh(params);
      } else {
        result = await _executeNormalLoad(params);
      }

      return result.fold(
        onSuccess: (tests) async {
          // Business Rule: Calculate pagination and metadata
          final hasMoreResult = await _calculateHasMore(tests, params);
          final currentPage = _calculateCurrentPage(tests, params);
          
          dev.log('LoadTestsUseCase: Successfully loaded ${tests.length} tests');

          return ApiResult.success(TestsLoadResult(
            tests: tests,
            hasMore: hasMoreResult,
            currentPage: currentPage,
            isFromCache: _isFromCache(result),
            totalCount: tests.length,
          ));
        },
        onFailure: (message, type) {
          dev.log('LoadTestsUseCase: Failed to load tests - $message');
          return ApiResult.failure(message, type);
        },
      );
    } catch (e) {
      dev.log('LoadTestsUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load tests: $e', FailureType.unknown);
    }
  }

  Future<ApiResult<List<TestItem>>> _executeRefresh(LoadTestsParams params) async {
    if (params.category != null) {
      return await repository.hardRefreshTestsByCategory(
        params.category!,
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    } else {
      return await repository.hardRefreshTests(
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    }
  }

  Future<ApiResult<List<TestItem>>> _executeNormalLoad(LoadTestsParams params) async {
    if (params.category != null) {
      return await repository.getTestsByCategory(
        params.category!,
        page: params.page,
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    } else {
      return await repository.getTests(
        page: params.page,
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    }
  }

  Future<bool> _calculateHasMore(List<TestItem> tests, LoadTestsParams params) async {
    try {
      if (params.category != null) {
        final result = await repository.hasMoreTestsByCategory(
          params.category!,
          tests.length,
          params.sortType,
        );
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      } else {
        final result = await repository.hasMoreTests(tests.length, params.sortType);
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      }
    } catch (e) {
      dev.log('LoadTestsUseCase: Error calculating hasMore - $e');
      return false;
    }
  }

  int _calculateCurrentPage(List<TestItem> tests, LoadTestsParams params) {
    if (params.loadMore) {
      return (tests.length / params.pageSize).floor();
    }
    return params.page;
  }

  bool _isFromCache(ApiResult<List<TestItem>> result) {
    // This would need to be determined from the repository implementation
    // For now, we'll return false as we don't have this information
    // In a real implementation, you might want to extend ApiResult to include this info
    return false;
  }
}