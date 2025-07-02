import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class SearchTestsParams extends Equatable {
  final String query;
  final int limit;

  const SearchTestsParams({
    required this.query,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [query, limit];
}

class TestSearchResult extends Equatable {
  final List<TestItem> tests;
  final String query;
  final int resultCount;
  final bool isFromCache;

  const TestSearchResult({
    required this.tests,
    required this.query,
    required this.resultCount,
    required this.isFromCache,
  });

  @override
  List<Object?> get props => [tests, query, resultCount, isFromCache];
}

class SearchTestsUseCase implements UseCase<TestSearchResult, SearchTestsParams> {
  final TestsRepository repository;
  final AuthService authService;

  SearchTestsUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<TestSearchResult>> execute(SearchTestsParams params) async {
    try {
      debugPrint('SearchTestsUseCase: Searching tests with query "${params.query}"');

      // Business Rule: Validate search query
      final trimmedQuery = params.query.trim();
      if (trimmedQuery.isEmpty) {
        debugPrint('SearchTestsUseCase: Empty search query');
        return ApiResult.success(TestSearchResult(
          tests: const [],
          query: trimmedQuery,
          resultCount: 0,
          isFromCache: false,
        ));
      }

      // Business Rule: Minimum query length
      if (trimmedQuery.length < 2) {
        debugPrint('SearchTestsUseCase: Query too short (${trimmedQuery.length} characters)');
        return ApiResult.failure(
          'Search query must be at least 2 characters long',
          FailureType.validation,
        );
      }

      // Business Rule: Maximum query length
      if (trimmedQuery.length > 100) {
        debugPrint('SearchTestsUseCase: Query too long (${trimmedQuery.length} characters)');
        return ApiResult.failure(
          'Search query cannot exceed 100 characters',
          FailureType.validation,
        );
      }

      // Business Rule: Validate limit
      if (params.limit <= 0 || params.limit > 50) {
        return ApiResult.failure(
          'Search limit must be between 1 and 50',
          FailureType.validation,
        );
      }

      // Business Rule: Sanitize query (remove special characters that might cause issues)
      final sanitizedQuery = _sanitizeQuery(trimmedQuery);
      if (sanitizedQuery.isEmpty) {
        return ApiResult.failure(
          'Search query contains only invalid characters',
          FailureType.validation,
        );
      }

      // Execute search
      final result = await repository.searchTests(sanitizedQuery);

      return result.fold(
        onSuccess: (tests) {
          // Business Rule: Apply limit
          final limitedTests = tests.take(params.limit).toList();
          
          debugPrint('SearchTestsUseCase: Found ${limitedTests.length} tests for query "$sanitizedQuery"');

          return ApiResult.success(TestSearchResult(
            tests: limitedTests,
            query: sanitizedQuery,
            resultCount: limitedTests.length,
            isFromCache: false, // This would need to be determined from repository
          ));
        },
        onFailure: (message, type) {
          debugPrint('SearchTestsUseCase: Search failed - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('SearchTestsUseCase: Unexpected error - $e');
      return ApiResult.failure('Search failed: $e', FailureType.unknown);
    }
  }

  String _sanitizeQuery(String query) {
    // Business Rule: Remove potentially harmful characters
    // Keep alphanumeric, spaces, and common punctuation
    final sanitized = query.replaceAll(RegExp(r'[^\w\s\-_.가-힣]'), '').trim();
    
    // Business Rule: Collapse multiple spaces
    return sanitized.replaceAll(RegExp(r'\s+'), ' ');
  }
}