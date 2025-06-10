import 'package:korean_language_app/core/shared/models/test_item.dart';

abstract class TestsLocalDataSource {
  // Basic test operations
  Future<List<TestItem>> getAllTests();
  Future<void> saveTests(List<TestItem> tests);
  Future<void> addTest(TestItem test);
  Future<void> updateTest(TestItem test);
  Future<void> removeTest(String testId);
  Future<void> clearAllTests();
  Future<bool> hasAnyTests();
  Future<int> getTestsCount();
  
  // Metadata operations
  Future<void> setLastSyncTime(DateTime dateTime);
  Future<DateTime?> getLastSyncTime();
  Future<void> setTestHashes(Map<String, String> hashes);
  Future<Map<String, String>> getTestHashes();
  
  Future<List<TestItem>> getTestsPage(int page, int pageSize);
  Future<List<TestItem>> getTestsByCategoryPage(String category, int page, int pageSize);
  
  // Count management
  Future<void> setTotalTestsCount(int count);
  Future<int?> getTotalTestsCount();
  Future<void> setCategoryTestsCount(String category, int count);
  Future<int?> getCategoryTestsCount(String category);
  
  // Image caching operations
  Future<String?> getCachedImagePath(String imageUrl, String testId, String imageType);
}