import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_progress.dart';
import 'package:korean_language_app/features/vocabularies/data/models/vocabulary_study_session.dart';

abstract class VocabularySessionLocalDataSource {
  // Session Management
  Future<VocabularyStudySession?> getCurrentStudySession();
  Future<void> saveCurrentStudySession(VocabularyStudySession session);
  Future<void> clearCurrentStudySession();
  
  // Progress Management
  Future<VocabularyProgress?> getVocabularyProgress(String vocabularyId);
  Future<void> saveVocabularyProgress(VocabularyProgress progress);
  Future<void> deleteVocabularyProgress(String vocabularyId);
  
  // Recently Studied
  Future<List<VocabularyProgress>> getRecentlyStudiedVocabularies({int limit = 10});
  Future<void> addToRecentlyStudied(VocabularyProgress progress);
  Future<void> removeFromRecentlyStudied(String vocabularyId);
  Future<void> clearRecentlyStudied();
  
  // Word Progress Tracking
  Future<void> markWordAsStudied(String vocabularyId, int chapterIndex, String wordId);
  Future<void> markChapterAsCompleted(String vocabularyId, int chapterIndex);
  Future<List<String>> getStudiedWordsForChapter(String vocabularyId, int chapterIndex);
  
  // Study Statistics
  Future<Duration> getTotalStudyTime();
  Future<int> getTotalStudiedWords();
  Future<int> getTotalCompletedChapters();
  Future<Map<String, int>> getStudyStreakData();
}