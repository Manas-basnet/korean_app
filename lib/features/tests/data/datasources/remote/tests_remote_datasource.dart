import 'package:korean_language_app/features/tests/domain/entities/user_test_interation.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/test_item.dart';

abstract class TestsRemoteDataSource {
  Future<List<TestItem>> getTests({
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<List<TestItem>> getTestsByCategory(
    TestCategory category, {
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<bool> hasMoreTests(int currentCount, [TestSortType? sortType]);
  Future<bool> hasMoreTestsByCategory(TestCategory category, int currentCount, [TestSortType? sortType]);
  Future<List<TestItem>> searchTests(String query);
  Future<TestItem?> getTestById(String testId);
  
  Future<void> recordTestView(String testId, String userId);
  Future<void> rateTest(String testId, String userId, double rating);
  Future<UserTestInteraction?> getUserTestInteraction(String testId, String userId);
}