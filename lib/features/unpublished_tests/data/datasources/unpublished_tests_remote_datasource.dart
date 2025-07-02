import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

abstract class UnpublishedTestsRemoteDataSource {
  Future<List<TestItem>> getUnpublishedTests(String userId, {int page = 0, int pageSize = 5});
  Future<List<TestItem>> getUnpublishedTestsByCategory(String userId, TestCategory category, {int page = 0, int pageSize = 5});
  Future<bool> hasMoreUnpublishedTests(String userId, int currentCount);
  Future<bool> hasMoreUnpublishedTestsByCategory(String userId, TestCategory category, int currentCount);
  Future<List<TestItem>> searchUnpublishedTests(String userId, String query);
}