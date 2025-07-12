import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/core/data/base_state.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/session/vocabulary_session_local_datasource.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_progress.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_chapter_progress.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_study_session.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

part 'vocabulary_session_state.dart';

class VocabularySessionCubit extends Cubit<VocabularySessionState> {
  final VocabularySessionLocalDataSource localDataSource;
  
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  
  VocabularySessionCubit({
    required this.localDataSource,
  }) : super(const VocabularySessionInitial()) {
    _loadCurrentSession();
  }

  Future<void> _loadCurrentSession() async {
    try {
      final currentSession = await localDataSource.getCurrentStudySession();
      final recentVocabularies = await localDataSource.getRecentlyStudiedVocabularies();
      
      if (currentSession != null) {
        final currentVocabularyProgress = await localDataSource.getVocabularyProgress(currentSession.vocabularyId);
        emit(VocabularySessionActive(
          currentSession: currentSession,
          currentVocabularyProgress: currentVocabularyProgress,
          recentlyStudiedVocabularies: recentVocabularies,
        ));
      } else {
        emit(VocabularySessionIdle(recentlyStudiedVocabularies: recentVocabularies));
      }
    } catch (e) {
      debugPrint('Error loading current vocabulary session: $e');
      emit(const VocabularySessionIdle(recentlyStudiedVocabularies: []));
    }
  }

  Future<void> startStudySession(
    String vocabularyId,
    String vocabularyTitle,
    int chapterIndex,
    String chapterTitle, {
    VocabularyItem? vocabularyItem,
    int totalWords = 0,
  }) async {
    try {
      _sessionStartTime = DateTime.now();
      
      final session = VocabularyStudySession(
        vocabularyId: vocabularyId,
        vocabularyTitle: vocabularyTitle,
        chapterTitle: chapterTitle,
        chapterIndex: chapterIndex,
        currentWordIndex: 0,
        totalWords: totalWords,
        startTime: _sessionStartTime!,
        lastActiveTime: _sessionStartTime!,
        isActive: true,
      );

      await localDataSource.saveCurrentStudySession(session);
      
      if (vocabularyItem != null) {
        await _updateVocabularyProgress(session, vocabularyItem: vocabularyItem);
      }
      
      _startSessionTimer();

      final recentVocabularies = await localDataSource.getRecentlyStudiedVocabularies();
      final currentVocabularyProgress = await localDataSource.getVocabularyProgress(vocabularyId);
      
      emit(VocabularySessionActive(
        currentSession: session,
        currentVocabularyProgress: currentVocabularyProgress,
        recentlyStudiedVocabularies: recentVocabularies,
      ));
      
      debugPrint('Started vocabulary study session: $vocabularyTitle - Chapter ${chapterIndex + 1}');
    } catch (e) {
      debugPrint('Error starting vocabulary study session: $e');
      emit(VocabularySessionError('Failed to start study session: $e', FailureType.unknown));
    }
  }

  Future<void> updateStudyProgress(
    int chapterIndex,
    int currentWordIndex,
    int totalWords, {
    String? studiedWordId,
  }) async {
    final currentState = state;
    if (currentState is! VocabularySessionActive) return;

    try {
      final now = DateTime.now();
      final studyTime = _sessionStartTime != null 
          ? now.difference(_sessionStartTime!)
          : Duration.zero;

      final updatedSession = currentState.currentSession.copyWith(
        currentWordIndex: currentWordIndex,
        totalWords: totalWords,
        lastActiveTime: now,
        totalStudyTime: studyTime,
      );

      await localDataSource.saveCurrentStudySession(updatedSession);
      
      if (studiedWordId != null) {
        await localDataSource.markWordAsStudied(
          updatedSession.vocabularyId,
          chapterIndex,
          studiedWordId,
        );
      }
      
      await _updateVocabularyProgress(updatedSession);

      final updatedVocabularyProgress = await localDataSource.getVocabularyProgress(updatedSession.vocabularyId);

      emit(currentState.copyWith(
        currentSession: updatedSession,
        currentVocabularyProgress: updatedVocabularyProgress,
      ));
      
      debugPrint('Updated study progress: Chapter $chapterIndex, Word $currentWordIndex/$totalWords');
    } catch (e) {
      debugPrint('Error updating study progress: $e');
    }
  }

  Future<int> loadLastStudyPosition(int chapterIndex) async {
    try {
      final currentState = state;
      if (currentState is! VocabularySessionActive) return 0;

      if (currentState.currentVocabularyProgress != null && 
          currentState.currentVocabularyProgress!.chapters.containsKey(chapterIndex)) {
        final chapterProgress = currentState.currentVocabularyProgress!.chapters[chapterIndex]!;
        return chapterProgress.currentWordIndex;
      }
    } catch (e) {
      debugPrint('Error loading last study position: $e');
    }
    return 0;
  }

  Future<void> pauseSession() async {
    final currentState = state;
    if (currentState is! VocabularySessionActive) return;

    try {
      _sessionTimer?.cancel();
      
      final now = DateTime.now();
      final studyTime = _sessionStartTime != null 
          ? now.difference(_sessionStartTime!)
          : Duration.zero;

      final pausedSession = currentState.currentSession.copyWith(
        lastActiveTime: now,
        totalStudyTime: studyTime,
        isActive: false,
      );

      await localDataSource.saveCurrentStudySession(pausedSession);
      await _updateVocabularyProgress(pausedSession);

      final updatedVocabularyProgress = await localDataSource.getVocabularyProgress(pausedSession.vocabularyId);

      emit(VocabularySessionPaused(
        pausedSession: pausedSession,
        currentVocabularyProgress: updatedVocabularyProgress,
        recentlyStudiedVocabularies: currentState.recentlyStudiedVocabularies,
      ));
      
      debugPrint('Paused vocabulary study session');
    } catch (e) {
      debugPrint('Error pausing session: $e');
    }
  }

  Future<void> resumeSession() async {
    final currentState = state;
    if (currentState is! VocabularySessionPaused) return;

    try {
      _sessionStartTime = DateTime.now();
      
      final resumedSession = currentState.pausedSession.copyWith(
        startTime: _sessionStartTime!,
        lastActiveTime: _sessionStartTime!,
        isActive: true,
      );

      await localDataSource.saveCurrentStudySession(resumedSession);
      
      _startSessionTimer();

      emit(VocabularySessionActive(
        currentSession: resumedSession,
        currentVocabularyProgress: currentState.currentVocabularyProgress,
        recentlyStudiedVocabularies: currentState.recentlyStudiedVocabularies,
      ));
      
      debugPrint('Resumed vocabulary study session');
    } catch (e) {
      debugPrint('Error resuming session: $e');
    }
  }

  Future<void> endSession() async {
    try {
      _sessionTimer?.cancel();
      _sessionStartTime = null;

      await localDataSource.clearCurrentStudySession();
      
      final recentVocabularies = await localDataSource.getRecentlyStudiedVocabularies();
      emit(VocabularySessionIdle(recentlyStudiedVocabularies: recentVocabularies));
      
      debugPrint('Ended vocabulary study session');
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  Future<VocabularyProgress?> getVocabularyProgress(String vocabularyId) async {
    try {
      final currentState = state;
      
      if ((currentState is VocabularySessionActive || currentState is VocabularySessionPaused) &&
          currentState is VocabularySessionActive && currentState.currentSession.vocabularyId == vocabularyId) {
        return currentState.currentVocabularyProgress;
      }
      
      if (currentState is VocabularySessionPaused && currentState.pausedSession.vocabularyId == vocabularyId) {
        return currentState.currentVocabularyProgress;
      }
      
      final progress = currentState is VocabularySessionIdle 
          ? currentState.recentlyStudiedVocabularies.where((vocab) => vocab.vocabularyId == vocabularyId).firstOrNull
          : null;
      
      return progress ?? await localDataSource.getVocabularyProgress(vocabularyId);
    } catch (e) {
      debugPrint('Error getting vocabulary progress: $e');
      return null;
    }
  }

  Future<List<VocabularyProgress>> getRecentlyStudiedVocabularies() async {
    try {
      final currentState = state;
      if (currentState is VocabularySessionIdle) {
        return currentState.recentlyStudiedVocabularies;
      } else if (currentState is VocabularySessionActive) {
        return currentState.recentlyStudiedVocabularies;
      } else if (currentState is VocabularySessionPaused) {
        return currentState.recentlyStudiedVocabularies;
      }
      
      return await localDataSource.getRecentlyStudiedVocabularies();
    } catch (e) {
      debugPrint('Error getting recently studied vocabularies: $e');
      return [];
    }
  }

  Future<void> markChapterCompleted(String vocabularyId, int chapterIndex) async {
    try {
      final currentState = state;
      VocabularyProgress? vocabularyProgress;

      if ((currentState is VocabularySessionActive || currentState is VocabularySessionPaused) &&
          ((currentState is VocabularySessionActive && currentState.currentSession.vocabularyId == vocabularyId) ||
           (currentState is VocabularySessionPaused && currentState.pausedSession.vocabularyId == vocabularyId))) {
        vocabularyProgress = currentState is VocabularySessionActive 
            ? currentState.currentVocabularyProgress
            : (currentState as VocabularySessionPaused).currentVocabularyProgress;
      } else {
        vocabularyProgress = await localDataSource.getVocabularyProgress(vocabularyId);
      }

      if (vocabularyProgress != null && vocabularyProgress.chapters.containsKey(chapterIndex)) {
        await localDataSource.markChapterAsCompleted(vocabularyId, chapterIndex);
        
        final updatedProgress = await localDataSource.getVocabularyProgress(vocabularyId);
        
        if (currentState is VocabularySessionActive && currentState.currentSession.vocabularyId == vocabularyId) {
          emit(currentState.copyWith(currentVocabularyProgress: updatedProgress));
        } else if (currentState is VocabularySessionPaused && currentState.pausedSession.vocabularyId == vocabularyId) {
          emit(currentState.copyWith(currentVocabularyProgress: updatedProgress));
        }
        
        debugPrint('Marked chapter $chapterIndex as completed for vocabulary $vocabularyId');
      }
    } catch (e) {
      debugPrint('Error marking chapter completed: $e');
    }
  }

  Future<void> markWordAsStudied(String vocabularyId, int chapterIndex, String wordId) async {
    try {
      await localDataSource.markWordAsStudied(vocabularyId, chapterIndex, wordId);
      
      final currentState = state;
      if ((currentState is VocabularySessionActive && currentState.currentSession.vocabularyId == vocabularyId) ||
          (currentState is VocabularySessionPaused && currentState.pausedSession.vocabularyId == vocabularyId)) {
        final updatedProgress = await localDataSource.getVocabularyProgress(vocabularyId);
        
        if (currentState is VocabularySessionActive) {
          emit(currentState.copyWith(currentVocabularyProgress: updatedProgress));
        } else if (currentState is VocabularySessionPaused) {
          emit(currentState.copyWith(currentVocabularyProgress: updatedProgress));
        }
      }
      
      debugPrint('Marked word $wordId as studied in chapter $chapterIndex for vocabulary $vocabularyId');
    } catch (e) {
      debugPrint('Error marking word as studied: $e');
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final currentState = state;
      if (currentState is VocabularySessionActive) {
        updateStudyProgress(
          currentState.currentSession.chapterIndex,
          currentState.currentSession.currentWordIndex,
          currentState.currentSession.totalWords,
        );
      }
    });
  }

  Future<void> _updateVocabularyProgress(VocabularyStudySession session, {VocabularyItem? vocabularyItem}) async {
    try {
      final existingProgress = await localDataSource.getVocabularyProgress(session.vocabularyId);
      
      final chapterProgress = VocabularyChapterProgress(
        chapterIndex: session.chapterIndex,
        chapterTitle: session.chapterTitle,
        currentWordIndex: session.currentWordIndex,
        totalWords: session.totalWords,
        lastStudiedTime: session.lastActiveTime,
        studyTime: session.totalStudyTime,
        isCompleted: session.totalWords > 0 && session.currentWordIndex >= session.totalWords,
        studiedWordIds: existingProgress?.chapters[session.chapterIndex]?.studiedWordIds ?? [],
      );

      final updatedChapters = existingProgress?.chapters ?? <int, VocabularyChapterProgress>{};
      updatedChapters[session.chapterIndex] = chapterProgress;

      final totalStudyTime = existingProgress?.totalStudyTime ?? Duration.zero;
      final newTotalStudyTime = totalStudyTime + session.totalStudyTime;

      final vocabularyProgressItem = vocabularyItem ?? existingProgress?.vocabularyItem;

      final vocabularyProgress = VocabularyProgress(
        vocabularyId: session.vocabularyId,
        vocabularyTitle: session.vocabularyTitle,
        vocabularyItem: vocabularyProgressItem,
        chapters: updatedChapters,
        lastStudiedTime: session.lastActiveTime,
        totalStudyTime: newTotalStudyTime,
        lastChapterIndex: session.chapterIndex,
        lastChapterTitle: session.chapterTitle,
      );

      await localDataSource.saveVocabularyProgress(vocabularyProgress);
      await localDataSource.addToRecentlyStudied(vocabularyProgress);
    } catch (e) {
      debugPrint('Error updating vocabulary progress: $e');
    }
  }

  @override
  Future<void> close() {
    _sessionTimer?.cancel();
    debugPrint('Vocabulary session cubit closed');
    return super.close();
  }
}