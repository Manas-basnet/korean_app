import 'dart:developer' as dev;
import 'dart:io';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/core/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/books/data/datasources/korean_books_local_datasource.dart';
import 'package:korean_language_app/features/books/data/datasources/korean_books_remote_data_source.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/features/books/data/models/book_item.dart';
import 'package:path_provider/path_provider.dart';

class KoreanBookRepositoryImpl extends BaseRepository implements KoreanBookRepository {
  final KoreanBooksRemoteDataSource remoteDataSource;
  final KoreanBooksLocalDataSource localDataSource;
  
  static const Duration cacheValidityDuration = Duration(hours: 1);

  KoreanBookRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<List<BookItem>>> getBooks(
    CourseCategory category, {
    int page = 0,
    int pageSize = 5,
  }) async {
    if (category != CourseCategory.korean) {
      return ApiResult.success([]);
    }

    if (page > 0) {
      return handleRepositoryCall<List<BookItem>>(
        () async {
          final remoteBooks = await remoteDataSource.getKoreanBooks(page: page, pageSize: pageSize);
          return ApiResult.success(remoteBooks);
        },
        cacheCall: () async {
          return ApiResult.failure('No internet connection for pagination', FailureType.network);
        },
      );
    }

    final result = await handleCacheFirstCall<List<BookItem>>(
      () async {
        if (await _isCacheValid()) {
          final cachedBooks = await localDataSource.getAllBooks();
          if (cachedBooks.isNotEmpty && _areValidBooks(cachedBooks)) {
            dev.log('Returning ${cachedBooks.length} books from valid cache');
            return ApiResult.success(cachedBooks);
          }
        }
        return ApiResult.failure('Cache invalid or empty', FailureType.cache);
      },
      () async {
        final remoteBooks = await remoteDataSource.getKoreanBooks(page: 0, pageSize: pageSize);
        return ApiResult.success(remoteBooks);
      },
      cacheData: (remoteBooks) async {
        final deletedIds = await _getDeletedBookIds(remoteBooks);
        for (final deletedId in deletedIds) {
          await localDataSource.removeBook(deletedId);
        }
        await _cacheBooks(remoteBooks);
      },
    );

    if (result.isSuccess && result.data != null) {
      return ApiResult.success(_filterValidBooks(result.data!));
    }
    
    return result;
  }

  @override
  Future<ApiResult<bool>> hasMoreBooks(CourseCategory category, int currentCount) async {
    if (category != CourseCategory.korean) {
      return ApiResult.success(false);
    }
    
    return handleCacheFirstCall<bool>(
      () async {
        try {
          final totalCached = await localDataSource.getBooksCount();
          return ApiResult.success(currentCount < totalCached);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
      () async {
        final hasMore = await remoteDataSource.hasMoreBooks(currentCount);
        return ApiResult.success(hasMore);
      },
    );
  }

  @override
  Future<ApiResult<List<BookItem>>> hardRefreshBooks(
    CourseCategory category, {
    int pageSize = 5,
  }) async {
    if (category != CourseCategory.korean) {
      return ApiResult.success([]);
    }

    final result = await handleRepositoryCall<List<BookItem>>(
      () async {
        await _invalidateCache();
        final remoteBooks = await remoteDataSource.getKoreanBooks(page: 0, pageSize: pageSize);
        return ApiResult.success(remoteBooks);
      },
      cacheCall: () async {
        final cachedBooks = await localDataSource.getAllBooks();
        if (cachedBooks.isNotEmpty) {
          return ApiResult.success(_filterValidBooks(cachedBooks));
        }
        return ApiResult.failure('No cached data for offline refresh', FailureType.cache);
      },
      cacheData: (remoteBooks) async {
        final deletedIds = await _getDeletedBookIds(remoteBooks);
        for (final deletedId in deletedIds) {
          await localDataSource.removeBook(deletedId);
        }
        await _cacheBooks(remoteBooks);
      },
    );

    if (result.isSuccess && result.data != null) {
      return ApiResult.success(_filterValidBooks(result.data!));
    }
    
    return result;
  }

  @override
  Future<ApiResult<List<BookItem>>> searchBooks(CourseCategory category, String query) async {
    if (category != CourseCategory.korean || query.trim().length < 2) {
      return ApiResult.success([]);
    }

    try {
      final cachedBooks = await localDataSource.getAllBooks();
      final cachedResults = _searchInBooks(cachedBooks, query);
      
      if (await networkInfo.isConnected) {
        try {
          final remoteResults = await remoteDataSource.searchKoreanBooks(query);
          
          if (remoteResults.isNotEmpty) {
            await _updateCacheWithNewBooks(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          dev.log('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          return ApiResult.success(combinedResults);
          
        } catch (e) {
          dev.log('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            return ApiResult.success(cachedResults);
          }
          throw e;
        }
      } else {
        dev.log('Offline search returned ${cachedResults.length} cached results');
        return ApiResult.success(cachedResults);
      }
      
    } catch (e) {
      try {
        final cachedBooks = await localDataSource.getAllBooks();
        final cachedResults = _searchInBooks(cachedBooks, query);
        return ApiResult.success(cachedResults);
      } catch (cacheError) {
        return ExceptionMapper.mapExceptionToApiResult(e as Exception);
      }
    }
  }

  @override
  Future<ApiResult<File?>> getBookPdf(String bookId) async {
    final result = await handleCacheFirstCall<File?>(
      () async {
        final cachedPdf = await localDataSource.getPdfFile(bookId);
        if (cachedPdf != null) {
          return ApiResult.success(cachedPdf);
        }
        return ApiResult.failure('No cached PDF', FailureType.cache);
      },
      () async {
        final downloadedPdf = await _downloadAndCachePdf(bookId);
        return ApiResult.success(downloadedPdf);
      },
    );

    return result;
  }

  @override
  Future<ApiResult<String?>> regenerateImageUrl(BookItem book) async {
    if (book.bookImagePath == null || book.bookImagePath!.isEmpty) {
      return ApiResult.success(null);
    }

    return handleRepositoryCall<String?>(
      () async {
        final newUrl = await remoteDataSource.regenerateUrlFromPath(book.bookImagePath!);
        return ApiResult.success(newUrl);
      },
      cacheCall: () async {
        return ApiResult.failure('No internet connection', FailureType.network);
      },
      cacheData: (newUrl) async {
        if (newUrl != null && newUrl.isNotEmpty) {
          final updatedBook = book.copyWith(bookImage: newUrl);
          
          try {
            await localDataSource.updateBook(updatedBook);
            await remoteDataSource.updateBook(book.id, updatedBook);
            await _updateBookHash(updatedBook);
          } catch (e) {
            dev.log('Failed to update book with new image URL: $e');
          }
        }
      },
    );
  }

  Future<bool> _isCacheValid() async {
    try {
      final lastSyncTime = await localDataSource.getLastSyncTime();
      if (lastSyncTime == null) return false;
      
      final cacheAge = DateTime.now().difference(lastSyncTime);
      return cacheAge < cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }

  Future<void> _invalidateCache() async {
    await localDataSource.clearAllBooks();
  }

  Future<void> _cacheBooks(List<BookItem> books) async {
    try {
      final existingBooks = await localDataSource.getAllBooks();
      final mergedBooks = _mergeBooks(existingBooks, books);
      
      await localDataSource.saveBooks(mergedBooks);
      await _updateLastSyncTime();
      await _updateBooksHashes(mergedBooks);
    } catch (e) {
      dev.log('Failed to cache books: $e');
    }
  }

  Future<void> _updateCacheWithNewBooks(List<BookItem> newBooks) async {
    try {
      for (final book in newBooks) {
        await localDataSource.addBook(book);
        await _updateBookHash(book);
      }
    } catch (e) {
      dev.log('Failed to update cache with new books: $e');
    }
  }

  Future<void> _updateLastSyncTime() async {
    await localDataSource.setLastSyncTime(DateTime.now());
  }

  Future<void> _updateBooksHashes(List<BookItem> books) async {
    final hashes = <String, String>{};
    for (final book in books) {
      hashes[book.id] = _generateBookHash(book);
    }
    await localDataSource.setBookHashes(hashes);
  }

  Future<void> _updateBookHash(BookItem book) async {
    final currentHashes = await localDataSource.getBookHashes();
    currentHashes[book.id] = _generateBookHash(book);
    await localDataSource.setBookHashes(currentHashes);
  }

  Future<List<String>> _getDeletedBookIds(List<BookItem> remoteBooks) async {
    try {
      final cachedBooks = await localDataSource.getAllBooks();
      final remoteBookIds = remoteBooks.map((book) => book.id).toSet();
      
      final deletedIds = cachedBooks
          .where((book) => !remoteBookIds.contains(book.id))
          .map((book) => book.id)
          .toList();
      
      return deletedIds;
    } catch (e) {
      dev.log('Error detecting deleted books: $e');
      return [];
    }
  }

  List<BookItem> _mergeBooks(List<BookItem> existing, List<BookItem> newBooks) {
    final Map<String, BookItem> bookMap = {};
    
    for (final book in existing) {
      bookMap[book.id] = book;
    }
    
    for (final book in newBooks) {
      bookMap[book.id] = book;
    }
    
    final mergedBooks = bookMap.values.toList();
    mergedBooks.sort((a, b) => a.title.compareTo(b.title));
    
    return mergedBooks;
  }

  List<BookItem> _searchInBooks(List<BookItem> books, String query) {
    final normalizedQuery = query.toLowerCase();
    
    return books.where((book) {
      return book.title.toLowerCase().contains(normalizedQuery) ||
             book.description.toLowerCase().contains(normalizedQuery) ||
             book.category.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  List<BookItem> _combineAndDeduplicateResults(
    List<BookItem> cachedBooks,
    List<BookItem> remoteBooks,
  ) {
    final Map<String, BookItem> uniqueBooks = {};
    
    for (final book in cachedBooks) {
      uniqueBooks[book.id] = book;
    }
    
    for (final book in remoteBooks) {
      uniqueBooks[book.id] = book;
    }
    
    return uniqueBooks.values.toList();
  }

  List<BookItem> _filterValidBooks(List<BookItem> books) {
    return books.where((book) => 
      book.id.isNotEmpty && 
      book.title.isNotEmpty && 
      book.description.isNotEmpty
    ).toList();
  }

  bool _areValidBooks(List<BookItem> books) {
    return books.every((book) => 
      book.id.isNotEmpty && 
      book.title.isNotEmpty && 
      book.description.isNotEmpty
    );
  }

  String _generateBookHash(BookItem book) {
    final content = '${book.title}_${book.description}_${book.updatedAt?.millisecondsSinceEpoch ?? 0}';
    return content.hashCode.toString();
  }

  Future<File?> _downloadAndCachePdf(String bookId) async {
    try {
      final pdfUrl = await remoteDataSource.getPdfDownloadUrl(bookId);
      if (pdfUrl == null || pdfUrl.isEmpty) {
        throw Exception('PDF URL not found for book');
      }

      final directory = await getApplicationDocumentsDirectory();
      final tempPath = '${directory.path}/temp_${bookId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final downloadedFile = await remoteDataSource.downloadPdfToLocal(bookId, tempPath);
      if (downloadedFile == null) {
        throw Exception('Failed to download PDF');
      }

      if (!await downloadedFile.exists() || await downloadedFile.length() == 0) {
        throw Exception('Downloaded PDF is invalid');
      }

      if (!await _isValidPDF(downloadedFile)) {
        throw Exception('Downloaded file is not a valid PDF');
      }

      try {
        await localDataSource.savePdfFile(bookId, downloadedFile);
      } catch (e) {
        dev.log('Failed to cache PDF: $e');
      }

      try {
        await downloadedFile.delete();
      } catch (e) {
        dev.log('Failed to delete temp file: $e');
      }

      return await localDataSource.getPdfFile(bookId);
    } catch (e) {
      throw Exception('Error downloading PDF: $e');
    }
  }

  Future<bool> _isValidPDF(File pdfFile) async {
    try {
      if (!await pdfFile.exists()) return false;
      
      final fileSize = await pdfFile.length();
      if (fileSize < 1024) return false;
      
      final bytes = await pdfFile.readAsBytes();
      if (bytes.length < 4) return false;
      
      final header = String.fromCharCodes(bytes.take(4));
      return header == '%PDF';
      
    } catch (e) {
      return false;
    }
  }
}