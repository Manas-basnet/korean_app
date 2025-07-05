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
  final List<BookProgress> recentlyReadBooks;

  const BookSessionActive({
    required this.currentSession,
    required this.recentlyReadBooks,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  BookSessionActive copyWith({
    ReadingSession? currentSession,
    List<BookProgress>? recentlyReadBooks,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionActive(
      currentSession: currentSession ?? this.currentSession,
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
      recentlyReadBooks: recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [currentSession, recentlyReadBooks, isLoading, error, errorType];
}

class BookSessionPaused extends BookSessionState {
  final ReadingSession pausedSession;
  final List<BookProgress> recentlyReadBooks;

  const BookSessionPaused({
    required this.pausedSession,
    required this.recentlyReadBooks,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  BookSessionPaused copyWith({
    ReadingSession? pausedSession,
    List<BookProgress>? recentlyReadBooks,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return BookSessionPaused(
      pausedSession: pausedSession ?? this.pausedSession,
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
      recentlyReadBooks: recentlyReadBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [pausedSession, recentlyReadBooks, isLoading, error, errorType];
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