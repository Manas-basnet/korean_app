import 'dart:developer' as dev;
import 'dart:io';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/core/enums/course_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/shared/services/image_cache_service.dart';
import 'package:korean_language_app/features/books/data/datasources/local/korean_books_local_datasource.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/korean_books_remote_data_source.dart';
import 'package:korean_language_app/features/books/domain/repositories/korean_book_repository.dart';
import 'package:korean_language_app/features/books/data/models/book_item.dart';
import 'package:path_provider/path_provider.dart';

class KoreanBookRepositoryImpl extends BaseRepository implements KoreanBookRepository {
  final KoreanBooksRemoteDataSource remoteDataSource;
  final KoreanBooksLocalDataSource localDataSource;
  final ImageCacheService imageCacheService;
  
  static const Duration cacheValidityDuration = Duration(hours: 1, minutes: 30);

  KoreanBookRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.imageCacheService,
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

    dev.log('Getting books - page: $page, pageSize: $pageSize');
    
    if (page == 0) {
      return _getInitialBooks(pageSize);
    } else {
      return _getMoreBooks(page, pageSize);
    }
  }

  Future<ApiResult<List<BookItem>>> _getInitialBooks(int pageSize) async {
    await _manageCacheValidity();

    final result = await handleCacheFirstCall<List<BookItem>>(
      () async {
        final cachedBooks = await localDataSource.getBooksPage(0, pageSize);
        if (cachedBooks.isNotEmpty) {
          dev.log('Returning ${cachedBooks.length} books from cache (page 0)');
          final processedBooks = await _processBooksWithMedia(cachedBooks);
          return ApiResult.success(processedBooks);
        }
        return ApiResult.failure('No cached data available', FailureType.cache);
      },
      () async {
        final remoteBooks = await remoteDataSource.getKoreanBooks(page: 0, pageSize: pageSize);
        return ApiResult.success(remoteBooks);
      },
      cacheData: (remoteBooks) async {
        await _cacheBooksDataOnly(remoteBooks);
        _cacheBookImagesInBackground(remoteBooks);
      },
    );

    if (result.isSuccess && result.data != null) {
      final processedBooks = await _processBooksWithMedia(result.data!);
      return ApiResult.success(processedBooks);
    }
    
    return result;
  }

  Future<ApiResult<List<BookItem>>> _getMoreBooks(int page, int pageSize) async {
    final result = await handleCacheFirstCall<List<BookItem>>(
      () async {
        final cachedBooks = await localDataSource.getBooksPage(page, pageSize);
        if (cachedBooks.isNotEmpty) {
          dev.log('Returning ${cachedBooks.length} books from cache (page $page)');
          final processedBooks = await _processBooksWithMedia(cachedBooks);
          return ApiResult.success(processedBooks);
        }
        return ApiResult.failure('No cached data for page $page', FailureType.cache);
      },
      () async {
        final remoteBooks = await remoteDataSource.getKoreanBooks(
          page: page, 
          pageSize: pageSize,
        );
        
        dev.log('Loaded ${remoteBooks.length} more books from remote (page $page)');
        return ApiResult.success(remoteBooks);
      },
      cacheData: (remoteBooks) async {
        if (remoteBooks.isNotEmpty) {
          for (final book in remoteBooks) {
            await localDataSource.addBook(book);
            await _updateBookHash(book);
          }
          _cacheBookImagesInBackground(remoteBooks);
          dev.log('Cached ${remoteBooks.length} new books from page $page');
        }
      },
    );

    if (result.isSuccess && result.data != null) {
      final processedBooks = await _processBooksWithMedia(result.data!);
      return ApiResult.success(processedBooks);
    }
    
    return result;
  }

  @override
  Future<ApiResult<bool>> hasMoreBooks(CourseCategory category, int currentCount) async {
    if (category != CourseCategory.korean) {
      return ApiResult.success(false);
    }
    
    return handleRepositoryCall<bool>(
      () async {
        final hasMore = await remoteDataSource.hasMoreBooks(currentCount);
        dev.log('hasMoreBooks from remote: $currentCount < ? = $hasMore');
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        final cachedTotalCount = await localDataSource.getTotalBooksCount();
        final totalCached = await localDataSource.getBooksCount();
        
        if (cachedTotalCount != null && cachedTotalCount > 0) {
          final hasMore = currentCount < cachedTotalCount;
          dev.log('hasMoreBooks from cached total count: $currentCount < $cachedTotalCount = $hasMore');
          return ApiResult.success(hasMore);
        } else if (totalCached > currentCount) {
          dev.log('hasMoreBooks from cached books count: $currentCount < $totalCached = true');
          return ApiResult.success(true);
        }
        
        return ApiResult.failure('No reliable cached count data', FailureType.cache);
      },
      cacheData: (hasMoreResult) async {
        if (!hasMoreResult && currentCount > 0) {
          await localDataSource.setTotalBooksCount(currentCount);
          dev.log('Cached total books count: $currentCount');
        }
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

    dev.log('Hard refresh books requested');

    final result = await handleRepositoryCall<List<BookItem>>(
      () async {
        await localDataSource.clearAllBooks();
        
        final remoteBooks = await remoteDataSource.getKoreanBooks(page: 0, pageSize: pageSize);
        return ApiResult.success(remoteBooks);
      },
      cacheCall: () async {
        dev.log('Hard refresh requested but offline - returning cached data');
        final cachedBooks = await localDataSource.getBooksPage(0, pageSize);
        final processedBooks = await _processBooksWithMedia(cachedBooks);
        return ApiResult.success(processedBooks);
      },
      cacheData: (remoteBooks) async {
        await _cacheBooksDataOnly(remoteBooks);
        _cacheBookImagesInBackground(remoteBooks);
      },
    );
    
    if (result.isSuccess && result.data != null) {
      final processedBooks = await _processBooksWithMedia(result.data!);
      return ApiResult.success(processedBooks);
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
            await _updateCacheWithNewBooksDataOnly(remoteResults);
            _cacheBookImagesInBackground(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          dev.log('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processBooksWithMedia(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          dev.log('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processBooksWithMedia(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        dev.log('Offline search returned ${cachedResults.length} cached results');
        final processedResults = await _processBooksWithMedia(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedBooks = await localDataSource.getAllBooks();
        final cachedResults = _searchInBooks(cachedBooks, query);
        final processedResults = await _processBooksWithMedia(cachedResults);
        return ApiResult.success(processedResults);
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
          dev.log('Returning cached PDF for book: $bookId');
          return ApiResult.success(cachedPdf);
        }
        return ApiResult.failure('No cached PDF', FailureType.cache);
      },
      () async {
        dev.log('Downloading PDF for book: $bookId');
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
            
            if (newUrl.isNotEmpty) {
              _cacheBookImagesInBackground([updatedBook]);
            }
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
      final isValid = cacheAge < cacheValidityDuration;
      
      if (!isValid) {
        dev.log('Cache expired: age=${cacheAge.inMinutes}min, limit=${cacheValidityDuration.inMinutes}min');
      }
      
      return isValid;
    } catch (e) {
      dev.log('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> _manageCacheValidity() async {
    try {
      final isValid = await _isCacheValid();
      if (!isValid) {
        if (await networkInfo.isConnected) {
          dev.log('Cache expired and online, clearing cache and resetting pagination');
          await localDataSource.clearAllBooks();
          await imageCacheService.clearAllImages();
        } else {
          dev.log('Cache expired but offline, keeping expired cache for offline access');
        }
      }
    } catch (e) {
      dev.log('Error managing cache validity: $e');
    }
  }

  Future<void> _cacheBooksDataOnly(List<BookItem> books) async {
    try {
      await localDataSource.saveBooks(books);
      await localDataSource.setLastSyncTime(DateTime.now());
      await _updateBooksHashes(books);
      
      dev.log('Cached ${books.length} books data only');
    } catch (e) {
      dev.log('Failed to cache books data: $e');
    }
  }

  Future<void> _updateCacheWithNewBooksDataOnly(List<BookItem> newBooks) async {
    try {
      for (final book in newBooks) {
        await localDataSource.addBook(book);
        await _updateBookHash(book);
      }
      
      dev.log('Added ${newBooks.length} new books data to cache');
    } catch (e) {
      dev.log('Failed to update cache with new books data: $e');
    }
  }

  void _cacheBookImagesInBackground(List<BookItem> books) {
    Future.microtask(() async {
      try {
        dev.log('Starting background image caching for ${books.length} books...');
        await _cacheBookImages(books);
        dev.log('Completed background image caching for ${books.length} books');
      } catch (e) {
        dev.log('Background image caching failed: $e');
      }
    });
  }

  Future<void> _cacheBookImages(List<BookItem> books) async {
    try {
      for (final book in books) {
        if (book.bookImage != null && book.bookImage!.isNotEmpty) {
          await imageCacheService.cacheImage(book.bookImage!, book.id);
        }
      }
    } catch (e) {
      dev.log('Error caching book images: $e');
    }
  }

  Future<List<BookItem>> _processBooksWithMedia(List<BookItem> books) async {
    try {
      final processedBooks = <BookItem>[];
      
      for (final book in books) {
        BookItem updatedBook = book;
        
        if (book.bookImage != null && book.bookImage!.isNotEmpty) {
          final cachedPath = await imageCacheService.getCachedImagePath(book.bookImage!, book.id);
          if (cachedPath != null && (book.bookImagePath == null || book.bookImagePath!.isEmpty)) {
            updatedBook = updatedBook.copyWith(bookImagePath: cachedPath);
          }
        }
        
        processedBooks.add(updatedBook);
      }
      
      return processedBooks;
    } catch (e) {
      dev.log('Error processing books with media: $e');
      return books;
    }
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

  String _generateBookHash(BookItem book) {
    final content = '${book.title}_${book.description}_${book.updatedAt?.millisecondsSinceEpoch ?? 0}';
    return content.hashCode.toString();
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