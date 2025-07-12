part of 'vocabulary_session_cubit.dart';

abstract class VocabularySessionState extends BaseState {
  const VocabularySessionState({
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  @override
  VocabularySessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  });
}

class VocabularySessionInitial extends VocabularySessionState {
  const VocabularySessionInitial();

  @override
  VocabularySessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return const VocabularySessionInitial();
  }

  @override
  List<Object?> get props => [];
}

class VocabularySessionIdle extends VocabularySessionState {
  final List<VocabularyProgress> recentlyStudiedVocabularies;

  const VocabularySessionIdle({
    required this.recentlyStudiedVocabularies,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  VocabularySessionIdle copyWith({
    List<VocabularyProgress>? recentlyStudiedVocabularies,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionIdle(
      recentlyStudiedVocabularies: recentlyStudiedVocabularies ?? this.recentlyStudiedVocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  VocabularySessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionIdle(
      recentlyStudiedVocabularies: recentlyStudiedVocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [recentlyStudiedVocabularies, isLoading, error, errorType];
}

class VocabularySessionActive extends VocabularySessionState {
  final VocabularyStudySession currentSession;
  final VocabularyProgress? currentVocabularyProgress;
  final List<VocabularyProgress> recentlyStudiedVocabularies;

  const VocabularySessionActive({
    required this.currentSession,
    this.currentVocabularyProgress,
    required this.recentlyStudiedVocabularies,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  VocabularySessionActive copyWith({
    VocabularyStudySession? currentSession,
    VocabularyProgress? currentVocabularyProgress,
    List<VocabularyProgress>? recentlyStudiedVocabularies,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionActive(
      currentSession: currentSession ?? this.currentSession,
      currentVocabularyProgress: currentVocabularyProgress ?? this.currentVocabularyProgress,
      recentlyStudiedVocabularies: recentlyStudiedVocabularies ?? this.recentlyStudiedVocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  VocabularySessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionActive(
      currentSession: currentSession,
      currentVocabularyProgress: currentVocabularyProgress,
      recentlyStudiedVocabularies: recentlyStudiedVocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [currentSession, currentVocabularyProgress, recentlyStudiedVocabularies, isLoading, error, errorType];
}

class VocabularySessionPaused extends VocabularySessionState {
  final VocabularyStudySession pausedSession;
  final VocabularyProgress? currentVocabularyProgress;
  final List<VocabularyProgress> recentlyStudiedVocabularies;

  const VocabularySessionPaused({
    required this.pausedSession,
    this.currentVocabularyProgress,
    required this.recentlyStudiedVocabularies,
    super.isLoading = false,
    super.error,
    super.errorType,
  });

  VocabularySessionPaused copyWith({
    VocabularyStudySession? pausedSession,
    VocabularyProgress? currentVocabularyProgress,
    List<VocabularyProgress>? recentlyStudiedVocabularies,
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionPaused(
      pausedSession: pausedSession ?? this.pausedSession,
      currentVocabularyProgress: currentVocabularyProgress ?? this.currentVocabularyProgress,
      recentlyStudiedVocabularies: recentlyStudiedVocabularies ?? this.recentlyStudiedVocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  VocabularySessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionPaused(
      pausedSession: pausedSession,
      currentVocabularyProgress: currentVocabularyProgress,
      recentlyStudiedVocabularies: recentlyStudiedVocabularies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      errorType: errorType,
    );
  }

  @override
  List<Object?> get props => [pausedSession, currentVocabularyProgress, recentlyStudiedVocabularies, isLoading, error, errorType];
}

class VocabularySessionError extends VocabularySessionState {
  const VocabularySessionError(String message, FailureType errorType)
      : super(error: message, errorType: errorType);

  @override
  VocabularySessionState copyWithBaseState({
    bool? isLoading,
    String? error,
    FailureType? errorType,
  }) {
    return VocabularySessionError(
      error ?? this.error ?? 'Unknown error',
      errorType ?? this.errorType ?? FailureType.unknown,
    );
  }

  @override
  List<Object?> get props => [error, errorType];
}