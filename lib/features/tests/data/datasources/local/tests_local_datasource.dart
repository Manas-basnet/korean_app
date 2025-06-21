import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';

abstract class TestsLocalDataSource {
  Future<List<TestItem>> getAllTests();
  Future<void> saveTests(List<TestItem> tests);
  Future<void> addTest(TestItem test);
  Future<void> updateTest(TestItem test);
  Future<void> removeTest(String testId);
  Future<void> clearAllTests();
  Future<bool> hasAnyTests();
  Future<int> getTestsCount();
  
  Future<void> setLastSyncTime(DateTime dateTime);
  Future<DateTime?> getLastSyncTime();
  Future<void> setTestHashes(Map<String, String> hashes);
  Future<Map<String, String>> getTestHashes();
  
  Future<List<TestItem>> getTestsPage(int page, int pageSize, {TestSortType sortType = TestSortType.recent});
  Future<List<TestItem>> getTestsByCategoryPage(String category, int page, int pageSize, {TestSortType sortType = TestSortType.recent});
  
  Future<void> setTotalTestsCount(int count);
  Future<int?> getTotalTestsCount();
  Future<void> setCategoryTestsCount(String category, int count);
  Future<int?> getCategoryTestsCount(String category);

  Future<void> cacheImage(String imageUrl, String testId, String imageType);
  Future<void> cacheAudio(String audioUrl, String testId, String audioType);
  
  Future<String?> getCachedImagePath(String imageUrl, String testId, String imageType);
  Future<String?> getCachedAudioPath(String audioUrl, String testId, String audioType);
}