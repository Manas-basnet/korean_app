import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

abstract class VocabulariesRepository {
  Future<ApiResult<List<VocabularyItem>>> getVocabularies({
    int page = 0,
    int pageSize = 5,
    BookLevel? level,
    SupportedLanguage? language,
  });
  
  Future<ApiResult<List<VocabularyItem>>> getVocabulariesByLevel(
    BookLevel level, {
    int page = 0,
    int pageSize = 5,
  });
  
  Future<ApiResult<List<VocabularyItem>>> getVocabulariesByLanguage(
    SupportedLanguage language, {
    int page = 0,
    int pageSize = 5,
  });
  
  Future<ApiResult<bool>> hasMoreVocabularies(int currentCount);
  Future<ApiResult<bool>> hasMoreVocabulariesByLevel(BookLevel level, int currentCount);
  Future<ApiResult<bool>> hasMoreVocabulariesByLanguage(SupportedLanguage language, int currentCount);
  
  Future<ApiResult<List<VocabularyItem>>> hardRefreshVocabularies({int pageSize = 5});
  Future<ApiResult<List<VocabularyItem>>> hardRefreshVocabulariesByLevel(BookLevel level, {int pageSize = 5});
  Future<ApiResult<List<VocabularyItem>>> hardRefreshVocabulariesByLanguage(SupportedLanguage language, {int pageSize = 5});
  
  Future<ApiResult<List<VocabularyItem>>> searchVocabularies(String query);
  Future<ApiResult<VocabularyItem?>> getVocabularyById(String vocabularyId);
  
  Future<ApiResult<void>> recordVocabularyView(String vocabularyId, String userId);
  Future<ApiResult<void>> rateVocabulary(String vocabularyId, String userId, double rating);
}