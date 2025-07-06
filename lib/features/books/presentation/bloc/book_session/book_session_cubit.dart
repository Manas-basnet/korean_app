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
        emit(BookSessionActive(
          currentSession: currentSession,
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
      emit(BookSessionActive(
        currentSession: session,
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

      emit(currentState.copyWith(currentSession: updatedSession));
      
      debugPrint('Updated reading progress: Chapter $chapterIndex, Page $currentPage/$totalPages');
    } catch (e) {
      debugPrint('Error updating reading progress: $e');
    }
  }

  Future<int> loadLastReadPosition(int chapterIndex) async {
    try {
      final currentState = state;
      if (currentState is! BookSessionActive) return 1;

      final bookProgress = await localDataSource.getBookProgress(currentState.currentSession.bookId);
      if (bookProgress != null && bookProgress.chapters.containsKey(chapterIndex)) {
        final chapterProgress = bookProgress.chapters[chapterIndex]!;
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

      emit(BookSessionPaused(
        pausedSession: pausedSession,
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
      return await localDataSource.getBookProgress(bookId);
    } catch (e) {
      debugPrint('Error getting book progress: $e');
      return null;
    }
  }

  Future<List<BookProgress>> getRecentlyReadBooks() async {
    try {
      return await localDataSource.getRecentlyReadBooks();
    } catch (e) {
      debugPrint('Error getting recently read books: $e');
      return [];
    }
  }

  Future<void> markChapterCompleted(String bookId, int chapterIndex) async {
    try {
      final bookProgress = await localDataSource.getBookProgress(bookId);
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