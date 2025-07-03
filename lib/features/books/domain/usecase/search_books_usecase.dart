import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:korean_language_app/core/usecases/usecase.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';

class SearchBooksParams extends Equatable {
  final String query;
  final int limit;

  const SearchBooksParams({
    required this.query,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [query, limit];
}

class BookSearchResult extends Equatable {
  final List<BookItem> books;
  final String query;
  final int resultCount;
  final bool isFromCache;

  const BookSearchResult({
    required this.books,
    required this.query,
    required this.resultCount,
    required this.isFromCache,
  });

  @override
  List<Object?> get props => [books, query, resultCount, isFromCache];
}

class SearchBooksUseCase implements UseCase<BookSearchResult, SearchBooksParams> {
  final BooksRepository repository;
  final AuthService authService;

  SearchBooksUseCase({
    required this.repository,
    required this.authService,
  });

  @override
  Future<ApiResult<BookSearchResult>> execute(SearchBooksParams params) async {
    try {
      debugPrint('SearchBooksUseCase: Searching books with query "${params.query}"');

      final trimmedQuery = params.query.trim();
      if (trimmedQuery.isEmpty) {
        debugPrint('SearchBooksUseCase: Empty search query');
        return ApiResult.success(BookSearchResult(
          books: const [],
          query: trimmedQuery,
          resultCount: 0,
          isFromCache: false,
        ));
      }

      if (trimmedQuery.length < 2) {
        debugPrint('SearchBooksUseCase: Query too short (${trimmedQuery.length} characters)');
        return ApiResult.failure(
          'Search query must be at least 2 characters long',
          FailureType.validation,
        );
      }

      if (trimmedQuery.length > 100) {
        debugPrint('SearchBooksUseCase: Query too long (${trimmedQuery.length} characters)');
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

      final result = await repository.searchBooks(sanitizedQuery);

      return result.fold(
        onSuccess: (books) {
          final limitedBooks = books.take(params.limit).toList();
          
          debugPrint('SearchBooksUseCase: Found ${limitedBooks.length} books for query "$sanitizedQuery"');

          return ApiResult.success(BookSearchResult(
            books: limitedBooks,
            query: sanitizedQuery,
            resultCount: limitedBooks.length,
            isFromCache: false,
          ));
        },
        onFailure: (message, type) {
          debugPrint('SearchBooksUseCase: Search failed - $message');
          return ApiResult.failure(message, type);
        },
      );

    } catch (e) {
      debugPrint('SearchBooksUseCase: Unexpected error - $e');
      return ApiResult.failure('Search failed: $e', FailureType.unknown);
    }
  }

  String _sanitizeQuery(String query) {
    final sanitized = query.replaceAll(RegExp(r'[^\w\s\-_.가-힣]'), '').trim();
    return sanitized.replaceAll(RegExp(r'\s+'), ' ');
  }
}