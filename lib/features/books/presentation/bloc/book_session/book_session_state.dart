part of 'book_session_cubit.dart';

class BookSession {
  final BookItem book;
  final String userId;
  final int currentChapterIndex;
  final DateTime startTime;
  final DateTime? lastReadTime;
  final double readingProgress; // 0.0 to 1.0
  final Map<int, double> chapterProgress; // chapter index -> progress (0.0 to 1.0)
  final bool isPaused;

  const BookSession({
    required this.book,
    required this.userId,
    required this.currentChapterIndex,
    required this.startTime,
    this.lastReadTime,
    this.readingProgress = 0.0,
    this.chapterProgress = const {},
    this.isPaused = false,
  });

  BookSession copyWith({
    BookItem? book,
    String? userId,
    int? currentChapterIndex,
    DateTime? startTime,
    DateTime? lastReadTime,
    double? readingProgress,
    Map<int, double>? chapterProgress,
    bool? isPaused,
  }) {
    return BookSession(
      book: book ?? this.book,
      userId: userId ?? this.userId,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      startTime: startTime ?? this.startTime,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      readingProgress: readingProgress ?? this.readingProgress,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  bool get isCompleted => readingProgress >= 1.0;
  int get totalChapters => book.chapters.length;
  double get progressPercentage => readingProgress * 100;
  
  String get formattedProgress => '${progressPercentage.toStringAsFixed(1)}%';
  
  BookChapter get currentChapter => book.chapters[currentChapterIndex];
  
  bool get isFirstChapter => currentChapterIndex == 0;
  bool get isLastChapter => currentChapterIndex == totalChapters - 1;
  
  double getCurrentChapterProgress() {
    return chapterProgress[currentChapterIndex] ?? 0.0;
  }
  
  Duration get readingDuration {
    if (lastReadTime == null) return Duration.zero;
    return lastReadTime!.difference(startTime);
  }
  
  String get formattedReadingDuration {
    final duration = readingDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

abstract class BookSessionState extends BaseState {
  const BookSessionState({
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  });
}

class BookSessionInitial extends BookSessionState {
  const BookSessionInitial();

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return const BookSessionInitial();
  }

  @override
  List<Object?> get props => [];
}

class BookSessionInProgress extends BookSessionState {
  final BookSession session;

  const BookSessionInProgress(this.session);

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionInProgress(session);
  }

  @override
  List<Object?> get props => [session];
}

class BookSessionPaused extends BookSessionState {
  final BookSession session;

  const BookSessionPaused(this.session);

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionPaused(session);
  }

  @override
  List<Object?> get props => [session];
}

class BookSessionError extends BookSessionState {
  const BookSessionError(String message, FailureType errorType)
      : super(error: message, errorType: errorType);

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionError(
      error ?? this.error ?? 'Unknown error',
      errorType ?? this.errorType ?? FailureType.unknown,
    );
  }

  @override
  List<Object?> get props => [error, errorType];
}