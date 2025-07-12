import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

abstract class VocabulariesLocalDataSource {
  Future<List<VocabularyItem>> getAllVocabularies();
  Future<void> saveVocabularies(List<VocabularyItem> vocabularies);
  Future<void> addVocabulary(VocabularyItem vocabulary);
  Future<void> updateVocabulary(VocabularyItem vocabulary);
  Future<void> removeVocabulary(String vocabularyId);
  Future<void> clearAllVocabularies();
  Future<bool> hasAnyVocabularies();
  Future<int> getVocabulariesCount();
  
  Future<void> setLastSyncTime(DateTime dateTime);
  Future<DateTime?> getLastSyncTime();
  Future<void> setVocabularyHashes(Map<String, String> hashes);
  Future<Map<String, String>> getVocabularyHashes();
  
  Future<List<VocabularyItem>> getVocabulariesPage(int page, int pageSize);
  Future<List<VocabularyItem>> getVocabulariesByLevelPage(BookLevel level, int page, int pageSize);
  Future<List<VocabularyItem>> getVocabulariesByLanguagePage(SupportedLanguage language, int page, int pageSize);
  
  Future<void> setTotalVocabulariesCount(int count);
  Future<int?> getTotalVocabulariesCount();
  Future<void> setLevelVocabulariesCount(BookLevel level, int count);
  Future<int?> getLevelVocabulariesCount(BookLevel level);
  Future<void> setLanguageVocabulariesCount(SupportedLanguage language, int count);
  Future<int?> getLanguageVocabulariesCount(SupportedLanguage language);

  Future<void> cacheImage(String imageUrl, String vocabularyId, String imageType);
  Future<void> cacheAudio(String audioUrl, String vocabularyId, String audioType);
  Future<void> cachePdf(String pdfUrl, String vocabularyId, String filename);
  
  Future<String?> getCachedImagePath(String imageUrl, String vocabularyId, String imageType);
  Future<String?> getCachedAudioPath(String audioUrl, String vocabularyId, String audioType);
  Future<String?> getCachedPdfPath(String pdfUrl, String vocabularyId, String filename);

}