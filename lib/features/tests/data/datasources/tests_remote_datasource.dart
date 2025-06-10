import 'package:korean_language_app/core/enums/test_category.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';

abstract class TestsRemoteDataSource {
  Future<List<TestItem>> getTests({int page = 0, int pageSize = 5});
  Future<List<TestItem>> getTestsByCategory(TestCategory category, {int page = 0, int pageSize = 5});
  Future<bool> hasMoreTests(int currentCount);
  Future<bool> hasMoreTestsByCategory(TestCategory category, int currentCount);
  Future<List<TestItem>> searchTests(String query);
  Future<TestItem?> getTestById(String testId);
  
  Future<List<TestItem>> getUnpublishedTests(String userId, {int page = 0, int pageSize = 5});
  Future<List<TestItem>> getUnpublishedTestsByCategory(String userId, TestCategory category, {int page = 0, int pageSize = 5});
  Future<bool> hasMoreUnpublishedTests(String userId, int currentCount);
  Future<bool> hasMoreUnpublishedTestsByCategory(String userId, TestCategory category, int currentCount);
  Future<List<TestItem>> searchUnpublishedTests(String userId, String query);
}