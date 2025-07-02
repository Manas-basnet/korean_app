import 'package:korean_language_app/shared/models/test_related/test_result.dart';

abstract class TestResultsLocalDataSource {
  Future<List<TestResult>> getUserResults(String userId);
  Future<void> saveUserResults(String userId, List<TestResult> results);
  Future<TestResult?> getLatestResult(String userId, String testId);
  Future<void> saveTestResult(TestResult result);
  Future<void> clearUserResults(String userId);
  Future<void> clearAllResults();
}