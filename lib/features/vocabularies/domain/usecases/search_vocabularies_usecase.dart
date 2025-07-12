import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabularies/domain/repositories/vocabularies_repository.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class SearchVocabulariesParams extends Equatable {
  final String query;
  final int limit;

  const SearchVocabulariesParams({
    required this.query,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [query, limit];
}

class VocabularySearchResult extends Equatable {
  final List<VocabularyItem> vocabularies;
  final String query;
  final int resultCount;
  final bool isFromCache;

  const VocabularySearchResult({
    required this.vocabularies,
    required this.query,
    required this.resultCount,
    required this.isFromCache,
  });

  @override
  List<Object?> get props => [vocabularies, query, resultCount, isFromCache];
}

class SearchVocabulariesUseCase implements UseCase<VocabularySearchResult, SearchVocabulariesParams> {
  final VocabulariesRepository repository;
  final AuthService authService;

  SearchVocabulariesUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<VocabularySearchResult>> execute(SearchVocabulariesParams params) async {
    try {
      debugPrint('SearchVocabulariesUseCase: Searching vocabularies with query "${params.query}"');

      final trimmedQuery = params.query.trim();
      if (trimmedQuery.isEmpty) {
        debugPrint('SearchVocabulariesUseCase: Empty search query');
        return ApiResult.success(VocabularySearchResult(
          vocabularies: const [],
          query: trimmedQuery,
          resultCount: 0,
          isFromCache: false,
        ));
      }

      if (trimmedQuery.length < 2) {
        debugPrint('SearchVocabulariesUseCase: Query too short (${trimmedQuery.length} characters)');
        return ApiResult.failure(
          'Search query must be at least 2 characters long',
          FailureType.validation,
        );
      }

      if (trimmedQuery.length > 100) {
        debugPrint('SearchVocabulariesUseCase: Query too long (${trimmedQuery.length} characters)');
        return ApiResult.failure(
          'Search query cannot exceed 100 characters',
          FailureType.validation,
        );
      }

      if (params.limit <= 0 || params.limit > 50) {
        return ApiResult.failure(
          'Search limit must be between 1 and 50',
          FailureType.validation,
        );
      }

      final sanitizedQuery = _sanitizeQuery(trimmedQuery);
      if (sanitizedQuery.isEmpty) {
        return ApiResult.failure(
          'Search query contains only invalid characters',
          FailureType.validation,
        );
      }

      final result = await repository.searchVocabularies(sanitizedQuery);

      return result.fold(
        onSuccess: (vocabularies) {
          final limitedVocabularies = vocabularies.take(params.limit).toList();
          
          debugPrint('SearchVocabulariesUseCase: Found ${limitedVocabularies.length} vocabularies for query "$sanitizedQuery"');

          return ApiResult.success(VocabularySearchResult(
            vocabularies: limitedVocabularies,
            query: sanitizedQuery,
            resultCount: limitedVocabularies.length,
            isFromCache: false,
          ));
        },
        onFailure: (message, type) {
          debugPrint('SearchVocabulariesUseCase: Search failed - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('SearchVocabulariesUseCase: Unexpected error - $e');
      return ApiResult.failure('Search failed: $e', FailureType.unknown);
    }
  }

  String _sanitizeQuery(String query) {
    final sanitized = query.replaceAll(RegExp(r'[^\w\s\-_.가-힣]'), '').trim();
    return sanitized.replaceAll(RegExp(r'\s+'), ' ');
  }
}