import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

abstract class VocabulariesRemoteDataSource {
  Future<List<VocabularyItem>> getVocabularies({
    int page = 0,
    int pageSize = 5,
    BookLevel? level,
    SupportedLanguage? language,
  });
  
  Future<List<VocabularyItem>> getVocabulariesByLevel(
    BookLevel level, {
    int page = 0,
    int pageSize = 5,
  });
  
  Future<List<VocabularyItem>> getVocabulariesByLanguage(
    SupportedLanguage language, {
    int page = 0,
    int pageSize = 5,
  });
  
  Future<bool> hasMoreVocabularies(int currentCount);
  Future<bool> hasMoreVocabulariesByLevel(BookLevel level, int currentCount);
  Future<bool> hasMoreVocabulariesByLanguage(SupportedLanguage language, int currentCount);
  
  Future<List<VocabularyItem>> searchVocabularies(String query);
  Future<VocabularyItem?> getVocabularyById(String vocabularyId);
  
  Future<void> recordVocabularyView(String vocabularyId, String userId);
  Future<void> rateVocabulary(String vocabularyId, String userId, double rating);
}