import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/books/data/datasources/local/book_local_datasource.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

part 'book_session_state.dart';

class ReadingSession {
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final int currentPage;
  final int totalPages;
  final DateTime startTime;
  final DateTime lastActiveTime;
  final Duration totalReadingTime;
  final bool isActive;

  const ReadingSession({
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    this.currentPage = 1,
    this.totalPages = 0,
    required this.startTime,
    required this.lastActiveTime,
    this.totalReadingTime = Duration.zero,
    this.isActive = false,
  });

  ReadingSession copyWith({
    String? bookId,
    String? bookTitle,
    String? chapterTitle,
    int? chapterIndex,
    int? currentPage,
    int? totalPages,
    DateTime? startTime,
    DateTime? lastActiveTime,
    Duration? totalReadingTime,
    bool? isActive,
  }) {
    return ReadingSession(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      startTime: startTime ?? this.startTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
      isActive: isActive ?? this.isActive,
    );
  }

  double get chapterProgress {
    if (totalPages <= 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  String get formattedReadingTime {
    final hours = totalReadingTime.inHours;
    final minutes = totalReadingTime.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'startTime': startTime.millisecondsSinceEpoch,
      'lastActiveTime': lastActiveTime.millisecondsSinceEpoch,
      'totalReadingTime': totalReadingTime.inMilliseconds,
      'isActive': isActive,
    };
  }

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      bookId: json['bookId'] as String,
      bookTitle: json['bookTitle'] as String,
      chapterTitle: json['chapterTitle'] as String,
      chapterIndex: json['chapterIndex'] as int,
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      lastActiveTime: DateTime.fromMillisecondsSinceEpoch(json['lastActiveTime'] as int),
      totalReadingTime: Duration(milliseconds: json['totalReadingTime'] as int? ?? 0),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class BookProgress {
  final String bookId;
  final String bookTitle;
  final BookItem? bookItem;
  final Map<int, ChapterProgress> chapters;
  final DateTime lastReadTime;
  final Duration totalReadingTime;
  final int lastChapterIndex;
  final String? lastChapterTitle;

  const BookProgress({
    required this.bookId,
    required this.bookTitle,
    this.bookItem,
    this.chapters = const {},
    required this.lastReadTime,
    this.totalReadingTime = Duration.zero,
    this.lastChapterIndex = 0,
    this.lastChapterTitle,
  });

  BookProgress copyWith({
    String? bookId,
    String? bookTitle,
    BookItem? bookItem,
    Map<int, ChapterProgress>? chapters,
    DateTime? lastReadTime,
    Duration? totalReadingTime,
    int? lastChapterIndex,
    String? lastChapterTitle,
  }) {
    return BookProgress(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookItem: bookItem ?? this.bookItem,
      chapters: chapters ?? this.chapters,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
    );
  }

  double get overallProgress {
    if (chapters.isEmpty) return 0.0;
    
    final totalProgress = chapters.values.fold(0.0, (sum, chapter) => sum + chapter.progress);
    return (totalProgress / chapters.length).clamp(0.0, 1.0);
  }

  int get completedChapters {
    return chapters.values.where((chapter) => chapter.isCompleted).length;
  }

  String get formattedProgress {
    return '${(overallProgress * 100).toStringAsFixed(1)}%';
  }

  String get formattedReadingTime {
    final hours = totalReadingTime.inHours;
    final minutes = totalReadingTime.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookItem': bookItem?.toJson(),
      'chapters': chapters.map((key, value) => MapEntry(key.toString(), value.toJson())),
      'lastReadTime': lastReadTime.millisecondsSinceEpoch,
      'totalReadingTime': totalReadingTime.inMilliseconds,
      'lastChapterIndex': lastChapterIndex,
      'lastChapterTitle': lastChapterTitle,
    };
  }

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as Map<String, dynamic>? ?? {};
    final chapters = <int, ChapterProgress>{};
    
    chaptersJson.forEach((key, value) {
      final chapterIndex = int.tryParse(key);
      if (chapterIndex != null) {
        chapters[chapterIndex] = ChapterProgress.fromJson(value as Map<String, dynamic>);
      }
    });

    BookItem? bookItem;
    if (json['bookItem'] != null) {
      try {
        bookItem = BookItem.fromJson(json['bookItem'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error parsing BookItem from BookProgress: $e');
      }
    }

    return BookProgress(
      bookId: json['bookId'] as String,
      bookTitle: json['bookTitle'] as String,
      bookItem: bookItem,
      chapters: chapters,
      lastReadTime: DateTime.fromMillisecondsSinceEpoch(json['lastReadTime'] as int),
      totalReadingTime: Duration(milliseconds: json['totalReadingTime'] as int? ?? 0),
      lastChapterIndex: json['lastChapterIndex'] as int? ?? 0,
      lastChapterTitle: json['lastChapterTitle'] as String?,
    );
  }
}

class ChapterProgress {
  final int chapterIndex;
  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final DateTime lastReadTime;
  final Duration readingTime;
  final bool isCompleted;

  const ChapterProgress({
    required this.chapterIndex,
    required this.chapterTitle,
    this.currentPage = 1,
    this.totalPages = 0,
    required this.lastReadTime,
    this.readingTime = Duration.zero,
    this.isCompleted = false,
  });

  ChapterProgress copyWith({
    int? chapterIndex,
    String? chapterTitle,
    int? currentPage,
    int? totalPages,
    DateTime? lastReadTime,
    Duration? readingTime,
    bool? isCompleted,
  }) {
    return ChapterProgress(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      readingTime: readingTime ?? this.readingTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  double get progress {
    if (totalPages <= 0) return 0.0;
    if (isCompleted) return 1.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  String get formattedProgress {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'lastReadTime': lastReadTime.millisecondsSinceEpoch,
      'readingTime': readingTime.inMilliseconds,
      'isCompleted': isCompleted,
    };
  }

  factory ChapterProgress.fromJson(Map<String, dynamic> json) {
    return ChapterProgress(
      chapterIndex: json['chapterIndex'] as int,
      chapterTitle: json['chapterTitle'] as String,
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      lastReadTime: DateTime.fromMillisecondsSinceEpoch(json['lastReadTime'] as int),
      readingTime: Duration(milliseconds: json['readingTime'] as int? ?? 0),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

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