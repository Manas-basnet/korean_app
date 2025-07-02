import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

abstract class UnpublishedTestsRepository {
  Future<ApiResult<List<TestItem>>> getUnpublishedTests({int page = 0, int pageSize = 5});
  Future<ApiResult<List<TestItem>>> getUnpublishedTestsByCategory(TestCategory category, {int page = 0, int pageSize = 5});
  Future<ApiResult<bool>> hasMoreUnpublishedTests(int currentCount);
  Future<ApiResult<bool>> hasMoreUnpublishedTestsByCategory(TestCategory category, int currentCount);
  Future<ApiResult<List<TestItem>>> hardRefreshUnpublishedTests({int pageSize = 5});
  Future<ApiResult<List<TestItem>>> hardRefreshUnpublishedTestsByCategory(TestCategory category, {int pageSize = 5});
  Future<ApiResult<List<TestItem>>> searchUnpublishedTests(String query);
}