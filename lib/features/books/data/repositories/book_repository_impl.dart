import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:korean_language_app/core/data/base_repository.dart';
import 'package:korean_language_app/features/books/data/datasources/local/book_local_datasource.dart';
import 'package:korean_language_app/features/books/data/datasources/remote/book_remote_datasource.dart';
import 'package:korean_language_app/features/books/domain/repositories/book_repository.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/shared/services/auth_service.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';
import 'package:korean_language_app/features/books/domain/entities/user_book_interaction.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';

class BookMediaItem {
  final String url;
  final int chapterIndex;
  final int trackIndex;
  
  BookMediaItem({
    required this.url,
    required this.chapterIndex,
    required this.trackIndex,
  });
}

class FullBookMediaCheckData {
  final String bookId;
  final List<BookMediaItem> chapterImageItems;
  final List<BookMediaItem> chapterPdfItems;
  final List<BookMediaItem> audioTrackItems;
  final BooksLocalDataSource localDataSource;
  final RootIsolateToken token;

  FullBookMediaCheckData({
    required this.bookId,
    required this.chapterImageItems,
    required this.chapterPdfItems,
    required this.audioTrackItems,
    required this.localDataSource,
    required this.token,
  });
}

class BookMediaProcessingData {
  final List<BookItem> books;
  final BooksLocalDataSource localDataSource;
  final bool processFullMedia;
  final RootIsolateToken token;

  BookMediaProcessingData({
    required this.books,
    required this.localDataSource,
    required this.processFullMedia,
    required this.token,
  });
}

Future<bool> _checkFullBookMediaCached(FullBookMediaCheckData data) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  
  for (final item in data.chapterImageItems) {
    final cachedPath = await data.localDataSource.getCachedImagePath(item.url, data.bookId, 'chapter_${item.chapterIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  for (final item in data.chapterPdfItems) {
    final cachedPath = await data.localDataSource.getCachedPdfPath(item.url, data.bookId, 'chapter_pdf_${item.chapterIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  for (final item in data.audioTrackItems) {
    final cachedPath = await data.localDataSource.getCachedAudioPath(item.url, data.bookId, 'audio_track_${item.chapterIndex}_${item.trackIndex}');
    if (cachedPath == null) {
      return false;
    }
  }
  
  return true;
}

Future<List<BookItem>> _processBooksInIsolate(BookMediaProcessingData data) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(data.token);
  
  final processedBooks = <BookItem>[];
  
  for (int bookIndex = 0; bookIndex < data.books.length; bookIndex++) {
    final book = data.books[bookIndex];
    BookItem updatedBook = book;
    
    if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
      final cachedPath = await data.localDataSource.getCachedImagePath(book.imageUrl!, book.id, 'main');
      if (cachedPath != null) {
        updatedBook = updatedBook.copyWith(
          imagePath: cachedPath,
          imageUrl: null
        );
      } else {
        updatedBook = updatedBook.copyWith(imagePath: null);
      }
    }
    
    if (data.processFullMedia) {
      final updatedChapters = <BookChapter>[];
      for (int i = 0; i < book.chapters.length; i++) {
        final chapter = book.chapters[i];
        BookChapter updatedChapter = chapter;
        
        if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
          final cachedPath = await data.localDataSource.getCachedImagePath(chapter.imageUrl!, book.id, 'chapter_$i');
          if (cachedPath != null) {
            updatedChapter = updatedChapter.copyWith(
              imagePath: cachedPath,
              imageUrl: null,
            );
          } else {
            updatedChapter = updatedChapter.copyWith(imagePath: null);
          }
        }

        if (chapter.pdfUrl != null && chapter.pdfUrl!.isNotEmpty) {
          final cachedPath = await data.localDataSource.getCachedPdfPath(chapter.pdfUrl!, book.id, 'chapter_pdf_$i');
          if (cachedPath != null) {
            updatedChapter = updatedChapter.copyWith(
              pdfPath: cachedPath,
              pdfUrl: null,
            );
          } else {
            updatedChapter = updatedChapter.copyWith(pdfPath: null);
          }
        }
        
        final updatedAudioTracks = <AudioTrack>[];
        for (int j = 0; j < chapter.audioTracks.length; j++) {
          final track = chapter.audioTracks[j];
          AudioTrack updatedTrack = track;
          
          if (track.audioUrl != null && track.audioUrl!.isNotEmpty) {
            final cachedPath = await data.localDataSource.getCachedAudioPath(track.audioUrl!, book.id, 'audio_track_${i}_$j');
            if (cachedPath != null) {
              updatedTrack = updatedTrack.copyWith(
                audioPath: cachedPath,
                audioUrl: null,
              );
            } else {
              updatedTrack = updatedTrack.copyWith(audioPath: null);
            }
          }
          
          updatedAudioTracks.add(updatedTrack);
        }
        
        updatedChapter = updatedChapter.copyWith(audioTracks: updatedAudioTracks);
        updatedChapters.add(updatedChapter);
        
        if (i % 2 == 0 && i > 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
      
      updatedBook = updatedBook.copyWith(chapters: updatedChapters);
    }
    
    processedBooks.add(updatedBook);
    
    if (bookIndex % 5 == 0 && bookIndex > 0) {
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }
  
  return processedBooks;
}

class BooksRepositoryImpl extends BaseRepository implements BooksRepository {
  final BooksRemoteDataSource remoteDataSource;
  final BooksLocalDataSource localDataSource;
  final AuthService authService;
  
  static const Duration cacheValidityDuration = Duration(days: 3);

  BooksRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authService,
    required NetworkInfo networkInfo,
  }) : super(networkInfo);

  @override
  Future<ApiResult<List<BookItem>>> getBooks({
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    debugPrint('Getting books - page: $page, pageSize: $pageSize, sortType: ${sortType.name}');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<BookItem>>(
      () async {
        final cachedBooks = await localDataSource.getBooksPage(page, pageSize, sortType: sortType);
        if (cachedBooks.isNotEmpty) {
          debugPrint('Returning ${cachedBooks.length} books from cache (page $page, sortType: ${sortType.name})');
          final processedBooks = await _processBooksWithCoverImages(cachedBooks);
          return ApiResult.success(processedBooks);
        }
        
        if (page > 0) {
          final totalCached = await localDataSource.getBooksCount();
          final currentCount = page * pageSize;

          if(totalCached > currentCount) {
            debugPrint('Requested page $page is within cached range but no data found');
            return ApiResult.success(<BookItem>[]);
          }
        }
        
        return ApiResult.failure('No cached data available', FailureType.cache);
      },
      () async {
        final remoteBooks = await remoteDataSource.getBooks(
          page: page, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteBooks);
      },
      cacheData: (remoteBooks) async {
        if (page == 0) {
          await _cacheBooksDataOnly(remoteBooks);
          _cacheCoverImagesInBackground(remoteBooks);
        } else {
          await _updateCacheWithNewBooksDataOnly(remoteBooks);
          _cacheCoverImagesInBackground(remoteBooks);
        }
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<BookItem>>> getBooksByCategory(
    TestCategory category, {
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    final categoryString = category.toString().split('.').last;
    debugPrint('Getting books by category: $categoryString - page: $page, pageSize: $pageSize, sortType: ${sortType.name}');
    
    await _manageCacheValidity();
    
    final result = await handleCacheFirstCall<List<BookItem>>(
      () async {
        final cachedBooks = await localDataSource.getBooksByCategoryPage(categoryString, page, pageSize, sortType: sortType);
        if (cachedBooks.isNotEmpty) {
          debugPrint('Returning ${cachedBooks.length} category books from cache (page $page, sortType: ${sortType.name})');
          final processedBooks = await _processBooksWithCoverImages(cachedBooks);
          return ApiResult.success(processedBooks);
        }
        
        if (page > 0) {
          final allCachedBooks = await localDataSource.getAllBooks();
          final categoryBooks = allCachedBooks.where((book) => book.category == category).toList();
          final requestedEndIndex = (page + 1) * pageSize;
          
          if (requestedEndIndex <= categoryBooks.length) {
            debugPrint('Requested category page $page is within cached range but no data found');
            return ApiResult.success(<BookItem>[]);
          }
        }
        
        return ApiResult.failure('No cached category data available', FailureType.cache);
      },
      () async {
        final remoteBooks = await remoteDataSource.getBooksByCategory(
          category, 
          page: page, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteBooks);
      },
      cacheData: (remoteBooks) async {
        await _updateCacheWithNewBooksDataOnly(remoteBooks);
        _cacheCoverImagesInBackground(remoteBooks);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<bool>> hasMoreBooks(int currentCount, [TestSortType? sortType]) async {
    return handleRepositoryCall(
      () async {
        final hasMore = await remoteDataSource.hasMoreBooks(currentCount, sortType);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        final totalCached = await localDataSource.getBooksCount();
        return ApiResult.success(currentCount < totalCached);
      },
    );
  }

  @override
  Future<ApiResult<bool>> hasMoreBooksByCategory(
    TestCategory category, 
    int currentCount, 
    [TestSortType? sortType]
  ) async {
    final categoryString = category.toString().split('.').last;
    
    return handleRepositoryCall<bool>(
      () async {
        final hasMore = await remoteDataSource.hasMoreBooksByCategory(category, currentCount, sortType);
        return ApiResult.success(hasMore);
      },
      cacheCall: () async {
        try {
          final cachedTotal = await localDataSource.getCategoryBooksCount(categoryString);
          if (cachedTotal != null && await _isCacheValid()) {
            return ApiResult.success(currentCount < cachedTotal);
          }
          
          final cachedBooks = await localDataSource.getAllBooks();
          final categoryBooks = cachedBooks.where((book) => book.category == category).length;
          return ApiResult.success(currentCount < categoryBooks);
        } catch (e) {
          return ApiResult.failure('Cache check failed', FailureType.cache);
        }
      },
    );
  }

  @override
  Future<ApiResult<List<BookItem>>> hardRefreshBooks({
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    debugPrint('Hard refresh requested with sortType: ${sortType.name}');

    final result = await handleRepositoryCall<List<BookItem>>(
      () async {
        await _clearBooksDataOnly();
        
        final remoteBooks = await remoteDataSource.getBooks(
          page: 0, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteBooks);
      },
      cacheCall: () async {
        debugPrint('Hard refresh requested but offline - returning cached data with sortType: ${sortType.name}');
        final cachedBooks = await localDataSource.getBooksPage(0, pageSize, sortType: sortType);
        final processedBooks = await _processBooksWithCoverImages(cachedBooks);
        return ApiResult.success(processedBooks);
      },
      cacheData: (remoteBooks) async {
        await _cacheBooksDataOnly(remoteBooks);
        _cacheCoverImagesInBackground(remoteBooks);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<BookItem>>> hardRefreshBooksByCategory(
    TestCategory category, {
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  }) async {
    debugPrint('Hard refresh category requested with sortType: ${sortType.name}');
    
    final result = await handleRepositoryCall<List<BookItem>>(
      () async {
        await _clearBooksDataOnly();

        final remoteBooks = await remoteDataSource.getBooksByCategory(
          category, 
          page: 0, 
          pageSize: pageSize, 
          sortType: sortType
        );
        return ApiResult.success(remoteBooks);
      },
      cacheCall: () async {
        debugPrint('Hard refresh category requested but offline - returning cached data with sortType: ${sortType.name}');
        final categoryString = category.toString().split('.').last;
        final cachedBooks = await localDataSource.getBooksByCategoryPage(categoryString, 0, pageSize, sortType: sortType);
        final processedBooks = await _processBooksWithCoverImages(cachedBooks);
        return ApiResult.success(processedBooks);
      },
      cacheData: (remoteBooks) async {
        await _updateCacheWithNewBooksDataOnly(remoteBooks);
        _cacheCoverImagesInBackground(remoteBooks);
      },
    );
    
    return result;
  }

  @override
  Future<ApiResult<List<BookItem>>> searchBooks(String query) async {
    if (query.trim().length < 2) {
      return ApiResult.success([]);
    }

    try {
      final cachedBooks = await localDataSource.getAllBooks();
      final cachedResults = _searchInBooks(cachedBooks, query);
      
      if (await networkInfo.isConnected) {
        try {
          final remoteResults = await remoteDataSource.searchBooks(query);
          
          if (remoteResults.isNotEmpty) {
            await _updateCacheWithNewBooksDataOnly(remoteResults);
            _cacheCoverImagesInBackground(remoteResults);
          }
          
          final combinedResults = _combineAndDeduplicateResults(cachedResults, remoteResults);
          debugPrint('Search returned ${combinedResults.length} combined results (${cachedResults.length} cached + ${remoteResults.length} remote)');
          
          final processedResults = await _processBooksWithCoverImages(combinedResults);
          return ApiResult.success(processedResults);
          
        } catch (e) {
          debugPrint('Remote search failed, returning ${cachedResults.length} cached results: $e');
          if (cachedResults.isNotEmpty) {
            final processedResults = await _processBooksWithCoverImages(cachedResults);
            return ApiResult.success(processedResults);
          }
          rethrow;
        }
      } else {
        debugPrint('Offline search returned ${cachedResults.length} cached results');
        final processedResults = await _processBooksWithCoverImages(cachedResults);
        return ApiResult.success(processedResults);
      }
      
    } catch (e) {
      try {
        final cachedBooks = await localDataSource.getAllBooks();
        final cachedResults = _searchInBooks(cachedBooks, query);
        final processedResults = await _processBooksWithCoverImages(cachedResults);
        return ApiResult.success(processedResults);
      } catch (cacheError) {
        return ExceptionMapper.mapExceptionToApiResult(e as Exception);
      }
    }
  }

  @override
  Future<ApiResult<BookItem?>> getBookById(String bookId) async {
    try {
      final result = await handleCacheFirstCall<BookItem?>(
        () async {
          final cachedBooks = await localDataSource.getAllBooks();
          final cachedBook = cachedBooks.where((b) => b.id == bookId).firstOrNull;
          
          if (cachedBook == null) {
            return ApiResult.failure('No cached book found', FailureType.cache);
          }
          
          final hasAllMedia = await _hasAllMediaCachedForBook(cachedBook);
          
          if (await _isCacheValid() && hasAllMedia) {
            final processedBooks = await _processBookWithAllMedia([cachedBook]);
            return ApiResult.success(processedBooks.isNotEmpty ? processedBooks.first : null);
          }
          
          debugPrint('Cache expired or media missing for book ${cachedBook.id}, will refresh from remote');
          return ApiResult.failure('Cache expired or media missing', FailureType.cache);
        },
        () async {
          final remoteBook = await remoteDataSource.getBookById(bookId);
          return ApiResult.success(remoteBook);
        },
        cacheData: (remoteBook) async {
          if (remoteBook != null) {
            await localDataSource.updateBook(remoteBook);
            await _updateBookHash(remoteBook);
            debugPrint('Caching full media for individual book: ${remoteBook.id}');
            _cacheFullBookMediaInBackground([remoteBook]);
          }
        },
      );
      
      return result;
    } catch (e) {
      return ExceptionMapper.mapExceptionToApiResult(e as Exception);
    }
  }

  @override
  Future<ApiResult<void>> recordBookView(String bookId, String userId) async {
    return handleRepositoryCall<void>(
      () async {
        await remoteDataSource.recordBookView(bookId, userId);
        return ApiResult.success(null);
      },
      cacheCall: () async {
        debugPrint('Cannot record book view offline');
        return ApiResult.success(null);
      },
    );
  }

  @override
  Future<ApiResult<void>> rateBook(String bookId, String userId, double rating) async {
    return handleRepositoryCall<void>(
      () async {
        await remoteDataSource.rateBook(bookId, userId, rating);
        return ApiResult.success(null);
      },
      cacheCall: () async {
        debugPrint('Cannot rate book offline');
        return ApiResult.success(null);
      },
    );
  }

  @override
  Future<ApiResult<UserBookInteraction?>> completeBookWithViewAndRating(String bookId, String userId, double? rating, UserBookInteraction? userInteraction) async {
    return handleRepositoryCall<UserBookInteraction?>(
      () async {
        final updatedInteractionData = await remoteDataSource.completeBookWithViewAndRating(bookId, userId, rating, userInteraction);
        return ApiResult.success(updatedInteractionData);
      },
      cacheCall: () async {
        debugPrint('Cannot complete book with view and rating offline');
        return ApiResult.success(null);
      },
      cacheData: (interaction) async {
        if (interaction != null) {
          localDataSource.saveUserBookInteraction(interaction);
        }
      },
    );
  }

  @override
  Future<ApiResult<UserBookInteraction?>> getUserBookInteraction(String bookId, String userId) async {
    return handleCacheFirstCall<UserBookInteraction?>(
      () async {
        final interaction = await localDataSource.getUserBookInteraction(bookId, userId);
        if(interaction == null) {
          return ApiResult.failure('No cached interaction found', FailureType.cache);
        } else {
          return ApiResult.success(interaction);
        }
      },
      () async {
        final interaction = await remoteDataSource.getUserBookInteraction(bookId, userId);
        return ApiResult.success(interaction);
      },
      cacheData: (interaction) async {
        if (interaction != null) {
          await localDataSource.saveUserBookInteraction(interaction);
        }
      },
    );
  }

  Future<List<BookItem>> _processBooksWithCoverImages(List<BookItem> books) async {
    if (books.isEmpty) return books;

    final processData = BookMediaProcessingData(
      books: books,
      localDataSource: localDataSource,
      processFullMedia: false,
      token: RootIsolateToken.instance!,
    );
    
    return await compute(_processBooksInIsolate, processData);
  }

  Future<List<BookItem>> _processBookWithAllMedia(List<BookItem> books) async {
    if (books.isEmpty) return books;

    final processData = BookMediaProcessingData(
      books: books,
      localDataSource: localDataSource,
      processFullMedia: true,
      token: RootIsolateToken.instance!,
    );
    
    return await compute(_processBooksInIsolate, processData);
  }

  Future<bool> _hasAllMediaCachedForBook(BookItem book) async {
    try {
      final chapterImageItems = <BookMediaItem>[];
      final chapterPdfItems = <BookMediaItem>[];
      final audioTrackItems = <BookMediaItem>[];

      for (int i = 0; i < book.chapters.length; i++) {
        final chapter = book.chapters[i];
        
        if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
          chapterImageItems.add(BookMediaItem(
            url: chapter.imageUrl!,
            chapterIndex: i,
            trackIndex: -1,
          ));
        }

        if (chapter.pdfUrl != null && chapter.pdfUrl!.isNotEmpty) {
          chapterPdfItems.add(BookMediaItem(
            url: chapter.pdfUrl!,
            chapterIndex: i,
            trackIndex: -1,
          ));
        }
        
        for (int j = 0; j < chapter.audioTracks.length; j++) {
          final track = chapter.audioTracks[j];
          if (track.audioUrl != null && track.audioUrl!.isNotEmpty) {
            audioTrackItems.add(BookMediaItem(
              url: track.audioUrl!,
              chapterIndex: i,
              trackIndex: j,
            ));
          }
        }
      }

      final mediaCheckData = FullBookMediaCheckData(
        bookId: book.id,
        chapterImageItems: chapterImageItems,
        chapterPdfItems: chapterPdfItems,
        audioTrackItems: audioTrackItems,
        localDataSource: localDataSource,
        token: RootIsolateToken.instance!,
      );
      
      final hasAllMedia = await compute(_checkFullBookMediaCached, mediaCheckData);
      
      if (hasAllMedia) {
        debugPrint('All media cached for book: ${book.id}');
      } else {
        debugPrint('Some media missing for book: ${book.id}');
      }
      
      return hasAllMedia;
    } catch (e) {
      debugPrint('Error checking cached media for book: ${book.id}, error: $e');
      return false;
    }
  }

  Future<bool> _isCacheValid() async {
    try {
      final lastSyncTime = await localDataSource.getLastSyncTime();
      if (lastSyncTime == null) return false;
      
      final cacheAge = DateTime.now().difference(lastSyncTime);
      final isValid = cacheAge < cacheValidityDuration;
      
      if (!isValid) {
        debugPrint('Cache expired: age=${cacheAge.inMinutes}min, limit=${cacheValidityDuration.inMinutes}min');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> _manageCacheValidity() async {
    try {
      final isValid = await _isCacheValid();
      if (!isValid) {
        if (await networkInfo.isConnected) {
          debugPrint('Cache expired and online, clearing book data only (keeping media files for reuse)');
          await _clearBooksDataOnly();
        } else {
          debugPrint('Cache expired but offline, keeping expired cache for offline access');
        }
      }
    } catch (e) {
      debugPrint('Error managing cache validity: $e');
    }
  }

  Future<void> _cacheBooksDataOnly(List<BookItem> books) async {
    try {
      await localDataSource.saveBooks(books);
      await localDataSource.setLastSyncTime(DateTime.now());
      await _updateBooksHashes(books);
      
      debugPrint('Cached ${books.length} books data only (media cached separately based on URLs)');
    } catch (e) {
      debugPrint('Failed to cache books data: $e');
    }
  }

  Future<void> _updateCacheWithNewBooksDataOnly(List<BookItem> newBooks) async {
    try {
      for (final book in newBooks) {
        await localDataSource.addBook(book);
        await _updateBookHash(book);
      }
      
      debugPrint('Added ${newBooks.length} new books data to cache (media cached separately based on URLs)');
    } catch (e) {
      debugPrint('Failed to update cache with new books data: $e');
    }
  }
  
  void _cacheFullBookMediaInBackground(List<BookItem> books) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background full media caching for ${books.length} books...');
        await _cacheFullBookMedia(books);
        debugPrint('Completed background full media caching for ${books.length} books');
      } catch (e) {
        debugPrint('Background full media caching failed: $e');
      }
    });
  }

  void _cacheCoverImagesInBackground(List<BookItem> books) {
    Future.microtask(() async {
      try {
        debugPrint('Starting background cover image caching for ${books.length} books...');
        await _cacheCoverImages(books);
        debugPrint('Completed background cover image caching for ${books.length} books');
      } catch (e) {
        debugPrint('Background cover image caching failed: $e');
      }
    });
  }

  Future<void> _cacheCoverImages(List<BookItem> books) async {
    try {
      for (int i = 0; i < books.length; i++) {
        final book = books[i];
        if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(book.imageUrl!, book.id, 'main');
          if (cachedPath == null) {
            debugPrint('Caching cover image for book: ${book.id}');
            await localDataSource.cacheImage(book.imageUrl!, book.id, 'main');
          }
        }
        
        if (i % 3 == 0 && i > 0) {
          await Future.delayed(const Duration(milliseconds: 15));
        }
      }
    } catch (e) {
      debugPrint('Error caching cover images: $e');
    }
  }

  Future<void> _cacheFullBookMedia(List<BookItem> books) async {
    try {
      for (int bookIndex = 0; bookIndex < books.length; bookIndex++) {
        final book = books[bookIndex];
        
        if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
          final cachedPath = await localDataSource.getCachedImagePath(book.imageUrl!, book.id, 'main');
          if (cachedPath == null) {
            await localDataSource.cacheImage(book.imageUrl!, book.id, 'main');
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }
        
        for (int i = 0; i < book.chapters.length; i++) {
          final chapter = book.chapters[i];
          
          if (chapter.imageUrl != null && chapter.imageUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedImagePath(chapter.imageUrl!, book.id, 'chapter_$i');
            if (cachedPath == null) {
              await localDataSource.cacheImage(chapter.imageUrl!, book.id, 'chapter_$i');
              await Future.delayed(const Duration(milliseconds: 10));
            }
          }

          if (chapter.pdfUrl != null && chapter.pdfUrl!.isNotEmpty) {
            final cachedPath = await localDataSource.getCachedPdfPath(chapter.pdfUrl!, book.id, 'chapter_pdf_$i');
            if (cachedPath == null) {
              await localDataSource.cachePdf(chapter.pdfUrl!, book.id, 'chapter_pdf_$i');
              await Future.delayed(const Duration(milliseconds: 30));
            }
          }

          for (int j = 0; j < chapter.audioTracks.length; j++) {
            final track = chapter.audioTracks[j];
            
            if (track.audioUrl != null && track.audioUrl!.isNotEmpty) {
              final cachedPath = await localDataSource.getCachedAudioPath(track.audioUrl!, book.id, 'audio_track_${i}_$j');
              if (cachedPath == null) {
                await localDataSource.cacheAudio(track.audioUrl!, book.id, 'audio_track_${i}_$j');
                await Future.delayed(const Duration(milliseconds: 20));
              }
            }
          }
          
          if (i % 2 == 0 && i > 0) {
            await Future.delayed(const Duration(milliseconds: 25));
          }
        }
        
        if (bookIndex % 1 == 0 && bookIndex > 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      debugPrint('Error caching full book media: $e');
    }
  }

  Future<void> _clearBooksDataOnly() async {
    try {
      await localDataSource.saveBooks([]);
      await localDataSource.setBookHashes({});
      await localDataSource.setTotalBooksCount(0);
      
      final allKeys = await _getAllCategoryKeys();
      for (final key in allKeys) {
        await localDataSource.setCategoryBooksCount(key, 0);
      }
      
      debugPrint('Cleared book data only, preserving media files for URL-based reuse');
    } catch (e) {
      debugPrint('Failed to clear book data: $e');
      try {
        await localDataSource.clearAllBooks();
        debugPrint('Fallback: cleared all books including media');
      } catch (fallbackError) {
        debugPrint('Fallback clear also failed: $fallbackError');
      }
    }
  }

  Future<List<String>> _getAllCategoryKeys() async {
    final categoryKeys = <String>[];
    for (final category in TestCategory.values) {
      if (category != TestCategory.all) {
        categoryKeys.add(category.toString().split('.').last);
      }
    }
    return categoryKeys;
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
    final content = '${book.title}_${book.description}_${book.chapters.length}_${book.updatedAt?.millisecondsSinceEpoch ?? 0}';
    return content.hashCode.toString();
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

  List<BookItem> _searchInBooks(List<BookItem> books, String query) {
    final normalizedQuery = query.toLowerCase();
    
    return books.where((book) {
      return book.title.toLowerCase().contains(normalizedQuery) ||
             book.description.toLowerCase().contains(normalizedQuery) ||
             book.language.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}