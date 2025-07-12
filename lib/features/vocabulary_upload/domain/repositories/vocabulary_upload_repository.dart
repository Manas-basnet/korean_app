import 'dart:io';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

abstract class VocabularyUploadRepository {
  Future<ApiResult<VocabularyItem>> createVocabulary(VocabularyItem vocabulary, {File? imageFile, List<File>? pdfFiles});
  
  Future<ApiResult<VocabularyItem>> updateVocabulary(String vocabularyId, VocabularyItem updatedVocabulary, {File? imageFile, List<File>? pdfFiles});
  
  Future<ApiResult<bool>> deleteVocabulary(String vocabularyId);
  
  Future<ApiResult<String?>> regenerateImageUrl(VocabularyItem vocabulary);
  
  Future<ApiResult<VocabularyItem?>> regenerateAllImageUrls(VocabularyItem vocabulary);
  
  Future<ApiResult<bool>> verifyImageUrls(VocabularyItem vocabulary);
  
  Future<ApiResult<bool>> hasEditPermission(String vocabularyId, String userId);
}