part of 'book_session_cubit.dart';

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

class BookSessionIdle extends BookSessionState {
  final List<BookProgress> recentlyReadBooks;

  const BookSessionIdle({
    required this.recentlyReadBooks,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  BookSessionIdle copyWith({
    List<BookProgress>? recentlyReadBooks,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionIdle(
      recentlyReadBooks: recentlyReadBooks ?? this.recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionIdle(
      recentlyReadBooks: recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [recentlyReadBooks, isLoading, error, errorType];
}

class BookSessionActive extends BookSessionState {
  final ReadingSession currentSession;
  final BookProgress? currentBookProgress;
  final List<BookProgress> recentlyReadBooks;

  const BookSessionActive({
    required this.currentSession,
    this.currentBookProgress,
    required this.recentlyReadBooks,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  BookSessionActive copyWith({
    ReadingSession? currentSession,
    BookProgress? currentBookProgress,
    List<BookProgress>? recentlyReadBooks,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionActive(
      currentSession: currentSession ?? this.currentSession,
      currentBookProgress: currentBookProgress ?? this.currentBookProgress,
      recentlyReadBooks: recentlyReadBooks ?? this.recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionActive(
      currentSession: currentSession,
      currentBookProgress: currentBookProgress,
      recentlyReadBooks: recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [currentSession, currentBookProgress, recentlyReadBooks, isLoading, error, errorType];
}

class BookSessionPaused extends BookSessionState {
  final ReadingSession pausedSession;
  final BookProgress? currentBookProgress;
  final List<BookProgress> recentlyReadBooks;

  const BookSessionPaused({
    required this.pausedSession,
    this.currentBookProgress,
    required this.recentlyReadBooks,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  BookSessionPaused copyWith({
    ReadingSession? pausedSession,
    BookProgress? currentBookProgress,
    List<BookProgress>? recentlyReadBooks,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionPaused(
      pausedSession: pausedSession ?? this.pausedSession,
      currentBookProgress: currentBookProgress ?? this.currentBookProgress,
      recentlyReadBooks: recentlyReadBooks ?? this.recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  BookSessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionPaused(
      pausedSession: pausedSession,
      currentBookProgress: currentBookProgress,
      recentlyReadBooks: recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [pausedSession, currentBookProgress, recentlyReadBooks, isLoading, error, errorType];
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