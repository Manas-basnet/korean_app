import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/data/datasources/local/book_local_datasource.dart';
import 'package:korean_language_app/features/books/data/model/book_progress.dart';
import 'package:korean_language_app/features/books/data/model/chapter_progress.dart';
import 'package:korean_language_app/features/books/data/model/reading_session.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

part 'book_session_state.dart';

class BookSessionCubit extends Cubit<BookSessionState> {
  final BooksLocalDataSource localDataSource;
  
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  
  BookSessionCubit({
    required this.localDataSource,
  }) : super(const BookSessionInitial()) {
    _loadCurrentSession();
  }

  Future<void> _loadCurrentSession() async {
    try {
      final currentSession = await localDataSource.getCurrentReadingSession();
      final recentBooks = await localDataSource.getRecentlyReadBooks();
      
      if (currentSession != null) {
        final currentBookProgress = await localDataSource.getBookProgress(currentSession.bookId);
        emit(BookSessionActive(
          currentSession: currentSession,
          currentBookProgress: currentBookProgress,
          recentlyReadBooks: recentBooks,
        ));
      } else {
        emit(BookSessionIdle(recentlyReadBooks: recentBooks));
      }
    } catch (e) {
      debugPrint('Error loading current session: $e');
      emit(const BookSessionIdle(recentlyReadBooks: []));
    }
  }

  Future<void> startReadingSession(
    String bookId,
    String bookTitle,
    int chapterIndex,
    String chapterTitle, {
    BookItem? bookItem,
  }) async {
    try {
      _sessionStartTime = DateTime.now();
      
      final session = ReadingSession(
        bookId: bookId,
        bookTitle: bookTitle,
        chapterTitle: chapterTitle,
        chapterIndex: chapterIndex,
        startTime: _sessionStartTime!,
        lastActiveTime: _sessionStartTime!,
        isActive: true,
      );

      await localDataSource.saveCurrentReadingSession(session);
      
      if (bookItem != null) {
        await _updateBookProgress(session, bookItem: bookItem);
      }
      
      _startSessionTimer();

      final recentBooks = await localDataSource.getRecentlyReadBooks();
      final currentBookProgress = await localDataSource.getBookProgress(bookId);
      
      emit(BookSessionActive(
        currentSession: session,
        currentBookProgress: currentBookProgress,
        recentlyReadBooks: recentBooks,
      ));
      
      debugPrint('Started reading session: $bookTitle - Chapter ${chapterIndex + 1}');
    } catch (e) {
      debugPrint('Error starting reading session: $e');
      emit(BookSessionError('Failed to start reading session: $e', FailureType.unknown));
    }
  }

  Future<void> updateReadingProgress(
    int chapterIndex,
    int currentPage,
    int totalPages,
  ) async {
    final currentState = state;
    if (currentState is! BookSessionActive) return;

    try {
      final now = DateTime.now();
      final readingTime = _sessionStartTime != null 
          ? now.difference(_sessionStartTime!)
          : Duration.zero;

      final updatedSession = currentState.currentSession.copyWith(
        currentPage: currentPage,
        totalPages: totalPages,
        lastActiveTime: now,
        totalReadingTime: readingTime,
      );

      await localDataSource.saveCurrentReadingSession(updatedSession);
      await _updateBookProgress(updatedSession);

      final updatedBookProgress = await localDataSource.getBookProgress(updatedSession.bookId);

      emit(currentState.copyWith(
        currentSession: updatedSession,
        currentBookProgress: updatedBookProgress,
      ));
      
      debugPrint('Updated reading progress: Chapter $chapterIndex, Page $currentPage/$totalPages');
    } catch (e) {
      debugPrint('Error updating reading progress: $e');
    }
  }

  Future<int> loadLastReadPosition(int chapterIndex) async {
    try {
      final currentState = state;
      if (currentState is! BookSessionActive) return 1;

      if (currentState.currentBookProgress != null && 
          currentState.currentBookProgress!.chapters.containsKey(chapterIndex)) {
        final chapterProgress = currentState.currentBookProgress!.chapters[chapterIndex]!;
        return chapterProgress.currentPage;
      }
    } catch (e) {
      debugPrint('Error loading last read position: $e');
    }
    return 1;
  }

  Future<void> pauseSession() async {
    final currentState = state;
    if (currentState is! BookSessionActive) return;

    try {
      _sessionTimer?.cancel();
      
      final now = DateTime.now();
      final readingTime = _sessionStartTime != null 
          ? now.difference(_sessionStartTime!)
          : Duration.zero;

      final pausedSession = currentState.currentSession.copyWith(
        lastActiveTime: now,
        totalReadingTime: readingTime,
        isActive: false,
      );

      await localDataSource.saveCurrentReadingSession(pausedSession);
      await _updateBookProgress(pausedSession);

      final updatedBookProgress = await localDataSource.getBookProgress(pausedSession.bookId);

      emit(BookSessionPaused(
        pausedSession: pausedSession,
        currentBookProgress: updatedBookProgress,
        recentlyReadBooks: currentState.recentlyReadBooks,
      ));
      
      debugPrint('Paused reading session');
    } catch (e) {
      debugPrint('Error pausing session: $e');
    }
  }

  Future<void> resumeSession() async {
    final currentState = state;
    if (currentState is! BookSessionPaused) return;

    try {
      _sessionStartTime = DateTime.now();
      
      final resumedSession = currentState.pausedSession.copyWith(
        startTime: _sessionStartTime!,
        lastActiveTime: _sessionStartTime!,
        isActive: true,
      );

      await localDataSource.saveCurrentReadingSession(resumedSession);
      
      _startSessionTimer();

      emit(BookSessionActive(
        currentSession: resumedSession,
        currentBookProgress: currentState.currentBookProgress,
        recentlyReadBooks: currentState.recentlyReadBooks,
      ));
      
      debugPrint('Resumed reading session');
    } catch (e) {
      debugPrint('Error resuming session: $e');
    }
  }

  Future<void> endSession() async {
    try {
      _sessionTimer?.cancel();
      _sessionStartTime = null;

      await localDataSource.clearCurrentReadingSession();
      
      final recentBooks = await localDataSource.getRecentlyReadBooks();
      emit(BookSessionIdle(recentlyReadBooks: recentBooks));
      
      debugPrint('Ended reading session');
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  Future<BookProgress?> getBookProgress(String bookId) async {
    try {
      final currentState = state;
      
      if ((currentState is BookSessionActive || currentState is BookSessionPaused) &&
          currentState is BookSessionActive && currentState.currentSession.bookId == bookId) {
        return currentState.currentBookProgress;
      }
      
      if (currentState is BookSessionPaused && currentState.pausedSession.bookId == bookId) {
        return currentState.currentBookProgress;
      }
      
      final progress = currentState is BookSessionIdle 
          ? currentState.recentlyReadBooks.where((book) => book.bookId == bookId).firstOrNull
          : null;
      
      return progress ?? await localDataSource.getBookProgress(bookId);
    } catch (e) {
      debugPrint('Error getting book progress: $e');
      return null;
    }
  }

  Future<List<BookProgress>> getRecentlyReadBooks() async {
    try {
      final currentState = state;
      if (currentState is BookSessionIdle) {
        return currentState.recentlyReadBooks;
      } else if (currentState is BookSessionActive) {
        return currentState.recentlyReadBooks;
      } else if (currentState is BookSessionPaused) {
        return currentState.recentlyReadBooks;
      }
      
      return await localDataSource.getRecentlyReadBooks();
    } catch (e) {
      debugPrint('Error getting recently read books: $e');
      return [];
    }
  }

  Future<void> markChapterCompleted(String bookId, int chapterIndex) async {
    try {
      final currentState = state;
      BookProgress? bookProgress;

      if ((currentState is BookSessionActive || currentState is BookSessionPaused) &&
          ((currentState is BookSessionActive && currentState.currentSession.bookId == bookId) ||
           (currentState is BookSessionPaused && currentState.pausedSession.bookId == bookId))) {
        bookProgress = currentState is BookSessionActive 
            ? currentState.currentBookProgress
            : (currentState as BookSessionPaused).currentBookProgress;
      } else {
        bookProgress = await localDataSource.getBookProgress(bookId);
      }

      if (bookProgress != null && bookProgress.chapters.containsKey(chapterIndex)) {
        final updatedChapters = Map<int, ChapterProgress>.from(bookProgress.chapters);
        final chapterProgress = updatedChapters[chapterIndex]!;
        updatedChapters[chapterIndex] = chapterProgress.copyWith(
          isCompleted: true,
          currentPage: chapterProgress.totalPages,
        );

        final updatedBookProgress = bookProgress.copyWith(
          chapters: updatedChapters,
          lastReadTime: DateTime.now(),
        );

        await localDataSource.saveBookProgress(updatedBookProgress);
        
        if (currentState is BookSessionActive && currentState.currentSession.bookId == bookId) {
          emit(currentState.copyWith(currentBookProgress: updatedBookProgress));
        } else if (currentState is BookSessionPaused && currentState.pausedSession.bookId == bookId) {
          emit(currentState.copyWith(currentBookProgress: updatedBookProgress));
        }
        
        debugPrint('Marked chapter $chapterIndex as completed for book $bookId');
      }
    } catch (e) {
      debugPrint('Error marking chapter completed: $e');
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final currentState = state;
      if (currentState is BookSessionActive) {
        updateReadingProgress(
          currentState.currentSession.chapterIndex,
          currentState.currentSession.currentPage,
          currentState.currentSession.totalPages,
        );
      }
    });
  }

  Future<void> _updateBookProgress(ReadingSession session, {BookItem? bookItem}) async {
    try {
      final existingProgress = await localDataSource.getBookProgress(session.bookId);
      
      final chapterProgress = ChapterProgress(
        chapterIndex: session.chapterIndex,
        chapterTitle: session.chapterTitle,
        currentPage: session.currentPage,
        totalPages: session.totalPages,
        lastReadTime: session.lastActiveTime,
        readingTime: session.totalReadingTime,
        isCompleted: session.totalPages > 0 && session.currentPage >= session.totalPages,
      );

      final updatedChapters = existingProgress?.chapters ?? <int, ChapterProgress>{};
      updatedChapters[session.chapterIndex] = chapterProgress;

      final totalReadingTime = existingProgress?.totalReadingTime ?? Duration.zero;
      final newTotalReadingTime = totalReadingTime + session.totalReadingTime;

      final bookProgressItem = bookItem ?? existingProgress?.bookItem;

      final bookProgress = BookProgress(
        bookId: session.bookId,
        bookTitle: session.bookTitle,
        bookItem: bookProgressItem,
        chapters: updatedChapters,
        lastReadTime: session.lastActiveTime,
        totalReadingTime: newTotalReadingTime,
        lastChapterIndex: session.chapterIndex,
        lastChapterTitle: session.chapterTitle,
      );

      await localDataSource.saveBookProgress(bookProgress);
      await localDataSource.addToRecentlyRead(bookProgress);
    } catch (e) {
      debugPrint('Error updating book progress: $e');
    }
  }

  @override
  Future<void> close() {
    _sessionTimer?.cancel();
    debugPrint('Book session cubit closed');
    return super.close();
  }
}