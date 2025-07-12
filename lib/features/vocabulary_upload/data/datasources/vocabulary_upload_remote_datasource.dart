import 'dart:io';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

abstract class VocabularyUploadRemoteDataSource {
  Future<VocabularyItem> uploadVocabulary(VocabularyItem vocabulary, {File? imageFile, List<File>? pdfFiles});
  
  Future<VocabularyItem> updateVocabulary(String vocabularyId, VocabularyItem updatedVocabulary, {File? imageFile, List<File>? pdfFiles});
  
  Future<bool> deleteVocabulary(String vocabularyId);
  
  Future<DateTime?> getVocabularyLastUpdated(String vocabularyId);
  
  Future<String?> regenerateUrlFromPath(String storagePath);
  
  Future<bool> verifyUrlIsWorking(String url);
}