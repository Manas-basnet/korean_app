import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabularies/domain/repositories/vocabularies_repository.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class LoadVocabulariesParams extends Equatable {
  final int page;
  final int pageSize;
  final BookLevel? level;
  final SupportedLanguage? language;
  final bool forceRefresh;
  final bool loadMore;

  const LoadVocabulariesParams({
    this.page = 0,
    this.pageSize = 5,
    this.level,
    this.language,
    this.forceRefresh = false,
    this.loadMore = false,
  });

  LoadVocabulariesParams copyWith({
    int? page,
    int? pageSize,
    BookLevel? level,
    SupportedLanguage? language,
    bool? forceRefresh,
    bool? loadMore,
  }) {
    return LoadVocabulariesParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      level: level ?? this.level,
      language: language ?? this.language,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      loadMore: loadMore ?? this.loadMore,
    );
  }

  @override
  List<Object?> get props => [page, pageSize, level, language, forceRefresh, loadMore];
}

class VocabulariesLoadResult extends Equatable {
  final List<VocabularyItem> vocabularies;
  final bool hasMore;
  final int currentPage;
  final bool isFromCache;
  final int totalCount;

  const VocabulariesLoadResult({
    required this.vocabularies,
    required this.hasMore,
    required this.currentPage,
    required this.isFromCache,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [vocabularies, hasMore, currentPage, isFromCache, totalCount];
}

class LoadVocabulariesUseCase implements UseCase<VocabulariesLoadResult, LoadVocabulariesParams> {
  final VocabulariesRepository repository;
  final AuthService authService;

  LoadVocabulariesUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<VocabulariesLoadResult>> execute(LoadVocabulariesParams params) async {
    try {
      debugPrint('LoadVocabulariesUseCase: Loading vocabularies with params - page: ${params.page}, '
          'pageSize: ${params.pageSize}, level: ${params.level?.name}, '
          'language: ${params.language?.name}, forceRefresh: ${params.forceRefresh}');

      if (params.page < 0) {
        return ApiResult.failure('Page number cannot be negative', FailureType.validation);
      }

      if (params.pageSize <= 0 || params.pageSize > 50) {
        return ApiResult.failure('Page size must be between 1 and 50', FailureType.validation);
      }

      ApiResult<List<VocabularyItem>> result;

      if (params.forceRefresh) {
        result = await _executeRefresh(params);
      } else {
        result = await _executeNormalLoad(params);
      }

      return result.fold(
        onSuccess: (vocabularies) async {
          final hasMoreResult = await _calculateHasMore(vocabularies, params);
          final currentPage = _calculateCurrentPage(vocabularies, params);
          
          debugPrint('LoadVocabulariesUseCase: Successfully loaded ${vocabularies.length} vocabularies, hasMore: $hasMoreResult, currentPage: $currentPage');

          return ApiResult.success(VocabulariesLoadResult(
            vocabularies: vocabularies,
            hasMore: hasMoreResult,
            currentPage: currentPage,
            isFromCache: _isFromCache(result),
            totalCount: vocabularies.length,
          ));
        },
        onFailure: (message, type) {
          debugPrint('LoadVocabulariesUseCase: Failed to load vocabularies - $message');
          return ApiResult.failure(message, type);
        },
      );
    } catch (e) {
      debugPrint('LoadVocabulariesUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load vocabularies: $e', FailureType.unknown);
    }
  }

  int _calculateCurrentPage(List<VocabularyItem> vocabularies, LoadVocabulariesParams params) {
    return params.page;
  }

  Future<bool> _calculateHasMore(List<VocabularyItem> vocabularies, LoadVocabulariesParams params) async {
    try {
      if (vocabularies.length < params.pageSize) {
        return false;
      }
      
      if (params.level != null) {
        final result = await repository.hasMoreVocabulariesByLevel(
          params.level!,
          vocabularies.length,
        );
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      } else if (params.language != null) {
        final result = await repository.hasMoreVocabulariesByLanguage(
          params.language!,
          vocabularies.length,
        );
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      } else {
        final result = await repository.hasMoreVocabularies(vocabularies.length);
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      }
    } catch (e) {
      debugPrint('LoadVocabulariesUseCase: Error calculating hasMore - $e');
      return false;
    }
  }

  Future<ApiResult<List<VocabularyItem>>> _executeRefresh(LoadVocabulariesParams params) async {
    if (params.level != null) {
      return await repository.hardRefreshVocabulariesByLevel(
        params.level!,
        pageSize: params.pageSize,
      );
    } else if (params.language != null) {
      return await repository.hardRefreshVocabulariesByLanguage(
        params.language!,
        pageSize: params.pageSize,
      );
    } else {
      return await repository.hardRefreshVocabularies(
        pageSize: params.pageSize,
      );
    }
  }

  Future<ApiResult<List<VocabularyItem>>> _executeNormalLoad(LoadVocabulariesParams params) async {
    if (params.level != null) {
      return await repository.getVocabulariesByLevel(
        params.level!,
        page: params.page,
        pageSize: params.pageSize,
      );
    } else if (params.language != null) {
      return await repository.getVocabulariesByLanguage(
        params.language!,
        page: params.page,
        pageSize: params.pageSize,
      );
    } else {
      return await repository.getVocabularies(
        page: params.page,
        pageSize: params.pageSize,
        level: params.level,
        language: params.language,
      );
    }
  }

  bool _isFromCache(ApiResult<List<VocabularyItem>> result) {
    return false;
  }
}