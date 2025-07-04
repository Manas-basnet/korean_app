import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class LoadBooksParams extends Equatable {
  final int page;
  final int pageSize;
  final TestSortType sortType;
  final CourseCategory? category;
  final bool forceRefresh;
  final bool loadMore;

  const LoadBooksParams({
    this.page = 0,
    this.pageSize = 5,
    this.sortType = TestSortType.recent,
    this.category,
    this.forceRefresh = false,
    this.loadMore = false,
  });

  LoadBooksParams copyWith({
    int? page,
    int? pageSize,
    TestSortType? sortType,
    CourseCategory? category,
    bool? forceRefresh,
    bool? loadMore,
  }) {
    return LoadBooksParams(
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

class BooksLoadResult extends Equatable {
  final List<BookItem> books;
  final bool hasMore;
  final int currentPage;
  final bool isFromCache;
  final int totalCount;

  const BooksLoadResult({
    required this.books,
    required this.hasMore,
    required this.currentPage,
    required this.isFromCache,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [books, hasMore, currentPage, isFromCache, totalCount];
}

class LoadBooksUseCase implements UseCase<BooksLoadResult, LoadBooksParams> {
  final BooksRepository repository;
  final AuthService authService;

  LoadBooksUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BooksLoadResult>> execute(LoadBooksParams params) async {
    try {
      debugPrint('LoadBooksUseCase: Loading books with params - page: ${params.page}, '
          'pageSize: ${params.pageSize}, sortType: ${params.sortType.name}, '
          'category: ${params.category?.name}, forceRefresh: ${params.forceRefresh}');

      if (params.page < 0) {
        return ApiResult.failure('Page number cannot be negative', FailureType.validation);
      }

      if (params.pageSize <= 0 || params.pageSize > 50) {
        return ApiResult.failure('Page size must be between 1 and 50', FailureType.validation);
      }

      ApiResult<List<BookItem>> result;

      if (params.forceRefresh) {
        result = await _executeRefresh(params);
      } else {
        result = await _executeNormalLoad(params);
      }

      return result.fold(
        onSuccess: (books) async {
          final hasMoreResult = await _calculateHasMore(books, params);
          final currentPage = _calculateCurrentPage(books, params);
          
          debugPrint('LoadBooksUseCase: Successfully loaded ${books.length} books, hasMore: $hasMoreResult, currentPage: $currentPage');

          return ApiResult.success(BooksLoadResult(
            books: books,
            hasMore: hasMoreResult,
            currentPage: currentPage,
            isFromCache: _isFromCache(result),
            totalCount: books.length,
          ));
        },
        onFailure: (message, type) {
          debugPrint('LoadBooksUseCase: Failed to load books - $message');
          return ApiResult.failure(message, type);
        },
      );
    } catch (e) {
      debugPrint('LoadBooksUseCase: Unexpected error - $e');
      return ApiResult.failure('Failed to load books: $e', FailureType.unknown);
    }
  }

  int _calculateCurrentPage(List<BookItem> books, LoadBooksParams params) {
    return params.page;
  }

  Future<bool> _calculateHasMore(List<BookItem> books, LoadBooksParams params) async {
    try {
      if (books.length < params.pageSize) {
        return false;
      }
      
      if (params.category != null) {
        final result = await repository.hasMoreBooksByCategory(
          params.category!,
          books.length,
          params.sortType,
        );
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      } else {
        final result = await repository.hasMoreBooks(books.length, params.sortType);
        return result.fold(
          onSuccess: (hasMore) => hasMore,
          onFailure: (_, __) => false,
        );
      }
    } catch (e) {
      debugPrint('LoadBooksUseCase: Error calculating hasMore - $e');
      return false;
    }
  }

  Future<ApiResult<List<BookItem>>> _executeRefresh(LoadBooksParams params) async {
    if (params.category != null) {
      return await repository.hardRefreshBooksByCategory(
        params.category!,
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    } else {
      return await repository.hardRefreshBooks(
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    }
  }

  Future<ApiResult<List<BookItem>>> _executeNormalLoad(LoadBooksParams params) async {
    if (params.category != null) {
      return await repository.getBooksByCategory(
        params.category!,
        page: params.page,
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    } else {
      return await repository.getBooks(
        page: params.page,
        pageSize: params.pageSize,
        sortType: params.sortType,
      );
    }
  }

  bool _isFromCache(ApiResult<List<BookItem>> result) {
    return false;
  }
}