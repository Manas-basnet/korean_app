import 'dart:developer' as dev;
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_params.dart';
import 'package:korean_language_app/features/tests/domain/entities/usecase_results.dart';
import 'package:korean_language_app/features/tests/domain/repositories/tests_repository.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

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
      dev.log('SearchTestsUseCase: Searching tests with query "${params.query}"');

      // Business Rule: Validate search query
      final trimmedQuery = params.query.trim();
      if (trimmedQuery.isEmpty) {
        dev.log('SearchTestsUseCase: Empty search query');
        return ApiResult.success(TestSearchResult(
          tests: const [],
          query: trimmedQuery,
          resultCount: 0,
          isFromCache: false,
        ));
      }

      // Business Rule: Minimum query length
      if (trimmedQuery.length < 2) {
        dev.log('SearchTestsUseCase: Query too short (${trimmedQuery.length} characters)');
        return ApiResult.failure(
          'Search query must be at least 2 characters long',
          FailureType.validation,
        );
      }

      // Business Rule: Maximum query length
      if (trimmedQuery.length > 100) {
        dev.log('SearchTestsUseCase: Query too long (${trimmedQuery.length} characters)');
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
          
          dev.log('SearchTestsUseCase: Found ${limitedTests.length} tests for query "$sanitizedQuery"');

          return ApiResult.success(TestSearchResult(
            tests: limitedTests,
            query: sanitizedQuery,
            resultCount: limitedTests.length,
            isFromCache: false, // This would need to be determined from repository
          ));
        },
        onFailure: (message, type) {
          dev.log('SearchTestsUseCase: Search failed - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      dev.log('SearchTestsUseCase: Unexpected error - $e');
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