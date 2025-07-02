import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/features/tests/domain/entities/user_test_interation.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

abstract class TestsRepository {
  Future<ApiResult<List<TestItem>>> getTests({
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<List<TestItem>>> getTestsByCategory(
    TestCategory category, {
    int page = 0, 
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<bool>> hasMoreTests(int currentCount, [TestSortType? sortType]);
  Future<ApiResult<bool>> hasMoreTestsByCategory(TestCategory category, int currentCount, [TestSortType? sortType]);
  
  Future<ApiResult<List<TestItem>>> hardRefreshTests({
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<List<TestItem>>> hardRefreshTestsByCategory(
    TestCategory category, {
    int pageSize = 5, 
    TestSortType sortType = TestSortType.recent
  });
  
  Future<ApiResult<List<TestItem>>> searchTests(String query);
  Future<ApiResult<TestItem?>> getTestById(String testId);
  
  Future<ApiResult<void>> recordTestView(String testId, String userId);
  Future<ApiResult<void>> rateTest(String testId, String userId, double rating);
  Future<ApiResult<UserTestInteraction?>> completeTestWithViewAndRating(String testId, String userId, double? rating, UserTestInteraction? userInteraction);
  Future<ApiResult<UserTestInteraction?>> getUserTestInteraction(String testId, String userId);
}