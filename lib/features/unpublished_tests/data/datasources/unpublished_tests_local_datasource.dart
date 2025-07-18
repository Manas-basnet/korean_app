import 'package:korean_language_app/shared/models/test_related/test_item.dart';

abstract class UnpublishedTestsLocalDataSource {
  Future<List<TestItem>> getAllUnpublishedTests(String userId);
  Future<void> saveUnpublishedTests(String userId, List<TestItem> tests);
  Future<void> addUnpublishedTest(String userId, TestItem test);
  Future<void> updateUnpublishedTest(String userId, TestItem test);
  Future<void> removeUnpublishedTest(String userId, String testId);
  Future<void> clearAllUnpublishedTests(String userId);
  Future<bool> hasAnyUnpublishedTests(String userId);
  Future<int> getUnpublishedTestsCount(String userId);
  
  Future<void> setLastUnpublishedSyncTime(String userId, DateTime dateTime);
  Future<DateTime?> getLastUnpublishedSyncTime(String userId);
  Future<void> setUnpublishedTestHashes(String userId, Map<String, String> hashes);
  Future<Map<String, String>> getUnpublishedTestHashes(String userId);
  
  Future<List<TestItem>> getUnpublishedTestsPage(String userId, int page, int pageSize);
  Future<List<TestItem>> getUnpublishedTestsByCategoryPage(String userId, String category, int page, int pageSize);
  
  Future<void> setTotalUnpublishedTestsCount(String userId, int count);
  Future<int?> getTotalUnpublishedTestsCount(String userId);
  Future<void> setUnpublishedCategoryTestsCount(String userId, String category, int count);
  Future<int?> getUnpublishedCategoryTestsCount(String userId, String category);
  
  Future<String?> getCachedImagePath(String imageUrl, String testId, String imageType);
  Future<void> cacheImage(String imageUrl, String testId, String imageType);
  
  Future<String?> getCachedAudioPath(String audioUrl, String testId, String audioType);
  Future<void> cacheAudio(String audioUrl, String testId, String audioType);
}