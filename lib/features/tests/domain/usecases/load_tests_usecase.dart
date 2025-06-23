// lib/features/tests/domain/usecases/load_tests_usecase.dart

import 'dart:developer' as dev;
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class LoadTestsParams extends Equatable {
  final int page;
  final int pageSize;
  final TestSortType sortType;
  final TestCategory? category;
  final bool forceRefresh;
  final bool loadMore;

  const LoadTestsParams({
    this.page = 0,
    this.pageSize = 5,
    this.sortType = TestSortType.recent,
    this.category,
    this.forceRefresh = false,
    this.loadMore = false,
  });

  LoadTestsParams copyWith({
    int? page,
    int? pageSize,
    TestSortType? sortType,
    TestCategory? category,
    bool? forceRefresh,
    bool? loadMore,
  }) {
    return LoadTestsParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortType: sortType ?? this.sortType,
      category: category ?? this.category,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      loadMore: loadMore ?? this.loadMore,
    );
  }

  @override
  List<Object?> get props => [page, pageSize, sortType, category, forceRefresh, loadMore];
}

class TestsLoadResult extends Equatable {
  final List<TestItem> tests;
  final bool hasMore;
  final int currentPage;
  final bool isFromCache;
  final int totalCount;

  const TestsLoadResult({
    required this.tests,
    required this.hasMore,
    required this.currentPage,
    required this.isFromCache,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [tests, hasMore, currentPage, isFromCache, totalCount];
}

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

      if (params.page < 0) {
        return ApiResult.failure('Page number cannot be negative', FailureType.validation);
      }

      if (params.pageSize <= 0 || params.pageSize > 50) {
        return ApiResult.failure('Page size must be between 1 and 50', FailureType.validation);
      }

      ApiResult<List<TestItem>> result;

      if (params.forceRefresh) {
        result = await _executeRefresh(params);
      } else {
        result = await _executeNormalLoad(params);
      }

      return result.fold(
        onSuccess: (tests) async {
          final hasMoreResult = await _calculateHasMore(tests, params);
          final currentPage = _calculateCurrentPage(tests, params);
          
          dev.log('LoadTestsUseCase: Successfully loaded ${tests.length} tests, hasMore: $hasMoreResult, currentPage: $currentPage');

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

  int _calculateCurrentPage(List<TestItem> tests, LoadTestsParams params) {
    return params.page;
  }

  Future<bool> _calculateHasMore(List<TestItem> tests, LoadTestsParams params) async {
    try {
      if (tests.length < params.pageSize) {
        return false;
      }
      
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

  bool _isFromCache(ApiResult<List<TestItem>> result) {
    // This would need to be determined from the repository implementation
    // For now, we'll return false as we don't have this information
    // In a real implementation, you might want to extend ApiResult to include this info
    return false;
  }
}