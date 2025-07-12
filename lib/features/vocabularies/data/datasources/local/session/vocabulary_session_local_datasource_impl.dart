import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/session/vocabulary_session_local_datasource.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_progress.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_study_session.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';

class VocabularySessionLocalDataSourceImpl implements VocabularySessionLocalDataSource {

  VocabularySessionLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  final StorageService _storageService;

  static const String currentSessionKey = 'CURRENT_VOCABULARY_SESSION';
  static const String vocabularyProgressPrefix = 'VOCABULARY_PROGRESS_';
  static const String recentlyStudiedKey = 'RECENTLY_STUDIED_VOCABULARIES';
  static const String studiedWordsPrefix = 'STUDIED_WORDS_';
  static const String completedChaptersPrefix = 'COMPLETED_CHAPTERS_';
  static const String studyStatsKey = 'VOCABULARY_STUDY_STATS';
  

  @override
  Future<VocabularyStudySession?> getCurrentStudySession() async {
    try {
      final sessionJson = _storageService.getString(currentSessionKey);
      if (sessionJson == null) return null;
      
      final sessionData = json.decode(sessionJson) as Map<String, dynamic>;
      return VocabularyStudySession.fromJson(sessionData);
    } catch (e) {
      debugPrint('Error reading current study session: $e');
      return null;
    }
  }

  @override
  Future<void> saveCurrentStudySession(VocabularyStudySession session) async {
    try {
      final sessionJson = json.encode(session.toJson());
      await _storageService.setString(currentSessionKey, sessionJson);
      debugPrint('Saved current study session for vocabulary: ${session.vocabularyId}');
    } catch (e) {
      debugPrint('Error saving current study session: $e');
      throw Exception('Failed to save current study session: $e');
    }
  }

  @override
  Future<void> clearCurrentStudySession() async {
    try {
      await _storageService.remove(currentSessionKey);
      debugPrint('Cleared current study session');
    } catch (e) {
      debugPrint('Error clearing current study session: $e');
    }
  }

  // Progress Management Methods
  @override
  Future<VocabularyProgress?> getVocabularyProgress(String vocabularyId) async {
    try {
      final progressJson = _storageService.getString('$vocabularyProgressPrefix$vocabularyId');
      if (progressJson == null) return null;
      
      final progressData = json.decode(progressJson) as Map<String, dynamic>;
      return VocabularyProgress.fromJson(progressData);
    } catch (e) {
      debugPrint('Error reading vocabulary progress for $vocabularyId: $e');
      return null;
    }
  }

  @override
  Future<void> saveVocabularyProgress(VocabularyProgress progress) async {
    try {
      final progressJson = json.encode(progress.toJson());
      await _storageService.setString('$vocabularyProgressPrefix${progress.vocabularyId}', progressJson);
      debugPrint('Saved progress for vocabulary: ${progress.vocabularyId}');
    } catch (e) {
      debugPrint('Error saving vocabulary progress: $e');
      throw Exception('Failed to save vocabulary progress: $e');
    }
  }

  @override
  Future<void> deleteVocabularyProgress(String vocabularyId) async {
    try {
      await _storageService.remove('$vocabularyProgressPrefix$vocabularyId');
      await _storageService.remove('$studiedWordsPrefix$vocabularyId');
      await _storageService.remove('$completedChaptersPrefix$vocabularyId');
      debugPrint('Deleted progress for vocabulary: $vocabularyId');
    } catch (e) {
      debugPrint('Error deleting vocabulary progress: $e');
    }
  }

  // Recently Studied Methods
  @override
  Future<List<VocabularyProgress>> getRecentlyStudiedVocabularies({int limit = 10}) async {
    try {
      final recentlyStudiedJson = _storageService.getString(recentlyStudiedKey);
      if (recentlyStudiedJson == null) return [];
      
      final List<dynamic> recentlyStudiedList = json.decode(recentlyStudiedJson);
      final vocabularyProgresses = recentlyStudiedList
          .map((item) => VocabularyProgress.fromJson(item as Map<String, dynamic>))
          .take(limit)
          .toList();
      
      return vocabularyProgresses;
    } catch (e) {
      debugPrint('Error reading recently studied vocabularies: $e');
      return [];
    }
  }

  @override
  Future<void> addToRecentlyStudied(VocabularyProgress progress) async {
    try {
      final recentList = await getRecentlyStudiedVocabularies(limit: 50);
      
      recentList.removeWhere((existing) => existing.vocabularyId == progress.vocabularyId);
      recentList.insert(0, progress);
      
      final limitedList = recentList.take(20).toList();
      
      final recentlyStudiedJson = json.encode(limitedList.map((p) => p.toJson()).toList());
      await _storageService.setString(recentlyStudiedKey, recentlyStudiedJson);
      
      debugPrint('Added vocabulary ${progress.vocabularyId} to recently studied');
    } catch (e) {
      debugPrint('Error adding to recently studied: $e');
    }
  }

  @override
  Future<void> removeFromRecentlyStudied(String vocabularyId) async {
    try {
      final recentList = await getRecentlyStudiedVocabularies(limit: 50);
      recentList.removeWhere((progress) => progress.vocabularyId == vocabularyId);
      
      final recentlyStudiedJson = json.encode(recentList.map((p) => p.toJson()).toList());
      await _storageService.setString(recentlyStudiedKey, recentlyStudiedJson);
      
      debugPrint('Removed vocabulary $vocabularyId from recently studied');
    } catch (e) {
      debugPrint('Error removing from recently studied: $e');
    }
  }

  @override
  Future<void> clearRecentlyStudied() async {
    try {
      await _storageService.remove(recentlyStudiedKey);
      debugPrint('Cleared recently studied vocabularies');
    } catch (e) {
      debugPrint('Error clearing recently studied: $e');
    }
  }

  // Word Progress Tracking Methods
  @override
  Future<void> markWordAsStudied(String vocabularyId, int chapterIndex, String wordId) async {
    try {
      final studiedWords = await getStudiedWordsForChapter(vocabularyId, chapterIndex);
      if (!studiedWords.contains(wordId)) {
        studiedWords.add(wordId);
        
        final studiedWordsJson = json.encode(studiedWords);
        await _storageService.setString('$studiedWordsPrefix${vocabularyId}_$chapterIndex', studiedWordsJson);
        
        debugPrint('Marked word $wordId as studied in vocabulary $vocabularyId, chapter $chapterIndex');
      }
    } catch (e) {
      debugPrint('Error marking word as studied: $e');
    }
  }

  @override
  Future<void> markChapterAsCompleted(String vocabularyId, int chapterIndex) async {
    try {
      final completedChaptersJson = _storageService.getString('$completedChaptersPrefix$vocabularyId');
      Set<int> completedChapters = {};
      
      if (completedChaptersJson != null) {
        final List<dynamic> completedList = json.decode(completedChaptersJson);
        completedChapters = completedList.cast<int>().toSet();
      }
      
      completedChapters.add(chapterIndex);
      
      final updatedJson = json.encode(completedChapters.toList());
      await _storageService.setString('$completedChaptersPrefix$vocabularyId', updatedJson);
      
      debugPrint('Marked chapter $chapterIndex as completed for vocabulary $vocabularyId');
    } catch (e) {
      debugPrint('Error marking chapter as completed: $e');
    }
  }

  @override
  Future<List<String>> getStudiedWordsForChapter(String vocabularyId, int chapterIndex) async {
    try {
      final studiedWordsJson = _storageService.getString('$studiedWordsPrefix${vocabularyId}_$chapterIndex');
      if (studiedWordsJson == null) return [];
      
      final List<dynamic> studiedWordsList = json.decode(studiedWordsJson);
      return studiedWordsList.cast<String>();
    } catch (e) {
      debugPrint('Error reading studied words for chapter: $e');
      return [];
    }
  }

  // Study Statistics Methods
  @override
  Future<Duration> getTotalStudyTime() async {
    try {
      final allKeys = _storageService.getAllKeys();
      Duration totalTime = Duration.zero;
      
      for (final key in allKeys) {
        if (key.startsWith(vocabularyProgressPrefix)) {
          final progressJson = _storageService.getString(key);
          if (progressJson != null) {
            final progressData = json.decode(progressJson) as Map<String, dynamic>;
            final progress = VocabularyProgress.fromJson(progressData);
            totalTime += progress.totalStudyTime;
          }
        }
      }
      
      return totalTime;
    } catch (e) {
      debugPrint('Error calculating total study time: $e');
      return Duration.zero;
    }
  }

  @override
  Future<int> getTotalStudiedWords() async {
    try {
      final allKeys = _storageService.getAllKeys();
      int totalWords = 0;
      
      for (final key in allKeys) {
        if (key.startsWith(studiedWordsPrefix)) {
          final studiedWordsJson = _storageService.getString(key);
          if (studiedWordsJson != null) {
            final List<dynamic> studiedWordsList = json.decode(studiedWordsJson);
            totalWords += studiedWordsList.length;
          }
        }
      }
      
      return totalWords;
    } catch (e) {
      debugPrint('Error calculating total studied words: $e');
      return 0;
    }
  }

  @override
  Future<int> getTotalCompletedChapters() async {
    try {
      final allKeys = _storageService.getAllKeys();
      int totalChapters = 0;
      
      for (final key in allKeys) {
        if (key.startsWith(completedChaptersPrefix)) {
          final completedChaptersJson = _storageService.getString(key);
          if (completedChaptersJson != null) {
            final List<dynamic> completedList = json.decode(completedChaptersJson);
            totalChapters += completedList.length;
          }
        }
      }
      
      return totalChapters;
    } catch (e) {
      debugPrint('Error calculating total completed chapters: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, int>> getStudyStreakData() async {
    try {
      final recentVocabularies = await getRecentlyStudiedVocabularies(limit: 30);
      final Map<String, int> streakData = {};
      
      for (final progress in recentVocabularies) {
        final dateKey = _formatDateKey(progress.lastStudiedTime);
        streakData[dateKey] = (streakData[dateKey] ?? 0) + 1;
      }
      
      return streakData;
    } catch (e) {
      debugPrint('Error getting study streak data: $e');
      return {};
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

}