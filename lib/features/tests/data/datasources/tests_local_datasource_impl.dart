import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:korean_language_app/core/services/storage_service.dart';
import 'package:korean_language_app/features/tests/data/datasources/tests_local_datasource.dart';
import 'package:korean_language_app/core/shared/models/test_item.dart';
import 'package:korean_language_app/core/enums/book_level.dart';
import 'package:korean_language_app/core/enums/test_category.dart';

class TestsLocalDataSourceImpl implements TestsLocalDataSource {
  final StorageService _storageService;
  
  static const String testsKey = 'CACHED_TESTS';
  static const String lastSyncKey = 'LAST_TESTS_SYNC_TIME';
  static const String testHashesKey = 'TEST_HASHES';
  static const String totalCountKey = 'TOTAL_TESTS_COUNT';
  static const String categoryCountPrefix = 'CATEGORY_COUNT_';
  static const String imageMetadataKey = 'IMAGE_METADATA';
  
  Directory? _imagesCacheDir;

  TestsLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  Future<Directory> get _imagesCacheDirectory async {
    if (_imagesCacheDir != null) return _imagesCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _imagesCacheDir = Directory('${appDir.path}/tests_images_cache');
    
    if (!await _imagesCacheDir!.exists()) {
      await _imagesCacheDir!.create(recursive: true);
    }
    
    return _imagesCacheDir!;
  }

  @override
  Future<List<TestItem>> getAllTests() async {
    try {
      final jsonString = _storageService.getString(testsKey);
      if (jsonString == null) return [];
      
      final List<dynamic> decodedJson = json.decode(jsonString);
      final tests = decodedJson.map((item) => TestItem.fromJson(item)).toList();
      
      return tests;
    } catch (e) {
      dev.log('Error reading tests from storage: $e');
      return [];
    }
  }

  @override
  Future<void> saveTests(List<TestItem> tests) async {
    try {
      final jsonList = tests.map((test) => test.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _storageService.setString(testsKey, jsonString);
      
      dev.log('Saved ${tests.length} tests to cache');
    } catch (e) {
      dev.log('Error saving tests to storage: $e');
      throw Exception('Failed to save tests: $e');
    }
  }

  @override
  Future<void> addTest(TestItem test) async {
    try {
      final tests = await getAllTests();
      final existingIndex = tests.indexWhere((t) => t.id == test.id);
      
      if (existingIndex != -1) {
        tests[existingIndex] = test;
      } else {
        tests.add(test);
      }
      
      await saveTests(tests);
    } catch (e) {
      dev.log('Error adding test to storage: $e');
      throw Exception('Failed to add test: $e');
    }
  }

  @override
  Future<void> updateTest(TestItem test) async {
    try {
      final tests = await getAllTests();
      final testIndex = tests.indexWhere((t) => t.id == test.id);
      
      if (testIndex != -1) {
        tests[testIndex] = test;
        await saveTests(tests);
      } else {
        throw Exception('Test not found for update: ${test.id}');
      }
    } catch (e) {
      dev.log('Error updating test in storage: $e');
      throw Exception('Failed to update test: $e');
    }
  }

  @override
  Future<void> removeTest(String testId) async {
    try {
      final tests = await getAllTests();
      final testToRemove = tests.firstWhere((test) => test.id == testId, orElse: () => const TestItem(
        id: '', title: '', description: '', questions: [],
        level: BookLevel.beginner, category: TestCategory.practice,
      ));
      
      if (testToRemove.id.isNotEmpty) {
        await _removeTestImages(testToRemove);
      }
      
      final updatedTests = tests.where((test) => test.id != testId).toList();
      await saveTests(updatedTests);
    } catch (e) {
      dev.log('Error removing test from storage: $e');
      throw Exception('Failed to remove test: $e');
    }
  }

  @override
  Future<void> clearAllTests() async {
    try {
      await _storageService.remove(testsKey);
      await _storageService.remove(lastSyncKey);
      await _storageService.remove(testHashesKey);
      await _storageService.remove(totalCountKey);
      await _storageService.remove(imageMetadataKey);
      
      final allKeys = _storageService.getAllKeys();
      for (final key in allKeys) {
        if (key.startsWith(categoryCountPrefix)) {
          await _storageService.remove(key);
        }
      }
      
      await _clearAllImages();
      
      dev.log('Cleared all tests cache and images');
    } catch (e) {
      dev.log('Error clearing all tests from storage: $e');
    }
  }

  @override
  Future<bool> hasAnyTests() async {
    try {
      final tests = await getAllTests();
      return tests.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getTestsCount() async {
    try {
      final tests = await getAllTests();
      return tests.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> setLastSyncTime(DateTime dateTime) async {
    await _storageService.setInt(lastSyncKey, dateTime.millisecondsSinceEpoch);
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _storageService.getInt(lastSyncKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  @override
  Future<void> setTestHashes(Map<String, String> hashes) async {
    await _storageService.setString(testHashesKey, json.encode(hashes));
  }

  @override
  Future<Map<String, String>> getTestHashes() async {
    try {
      final hashesJson = _storageService.getString(testHashesKey);
      if (hashesJson == null) return {};
      
      final Map<String, dynamic> decoded = json.decode(hashesJson);
      return decoded.cast<String, String>();
    } catch (e) {
      dev.log('Error reading test hashes: $e');
      return {};
    }
  }

  @override
  Future<List<TestItem>> getTestsPage(int page, int pageSize) async {
    try {
      final allTests = await getAllTests();
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, allTests.length);
      
      if (startIndex >= allTests.length) return [];
      
      return allTests.sublist(startIndex, endIndex);
    } catch (e) {
      dev.log('Error getting tests page: $e');
      return [];
    }
  }

  @override
  Future<List<TestItem>> getTestsByCategoryPage(String category, int page, int pageSize) async {
    try {
      final allTests = await getAllTests();
      final categoryTests = allTests.where((test) => 
        test.category.toString().split('.').last == category
      ).toList();
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, categoryTests.length);
      
      if (startIndex >= categoryTests.length) return [];
      
      return categoryTests.sublist(startIndex, endIndex);
    } catch (e) {
      dev.log('Error getting category tests page: $e');
      return [];
    }
  }

  @override
  Future<void> setTotalTestsCount(int count) async {
    await _storageService.setInt(totalCountKey, count);
  }

  @override
  Future<int?> getTotalTestsCount() async {
    return _storageService.getInt(totalCountKey);
  }

  @override
  Future<void> setCategoryTestsCount(String category, int count) async {
    await _storageService.setInt('$categoryCountPrefix$category', count);
  }

  @override
  Future<int?> getCategoryTestsCount(String category) async {
    return _storageService.getInt('$categoryCountPrefix$category');
  }

  Future<void> cacheImage(String imageUrl, String testId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, testId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        dev.log('Image already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        dev.log('Cached image: $fileName (${response.data.length} bytes)');
        
        await _updateImageMetadata(testId, imageType, imageUrl);
      } else {
        dev.log('Failed to download image: $imageUrl (${response.statusCode})');
      }
    } catch (e) {
      dev.log('Error caching image $imageUrl: $e');
    }
  }

  @override
  Future<String?> getCachedImagePath(String imageUrl, String testId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, testId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      dev.log('Error getting cached image path: $e');
    }
    return null;
  }

  String _generateImageFileName(String imageUrl, String testId, String imageType) {
    final urlHash = md5.convert(utf8.encode(imageUrl)).toString().substring(0, 8);
    return '${testId}_${imageType}_$urlHash.jpg';
  }

  Future<void> _updateImageMetadata(String testId, String imageType, String imageUrl) async {
    try {
      final imageMetadata = await _getImageMetadata();
      imageMetadata['${testId}_$imageType'] = {
        'url': imageUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      dev.log('Error updating image metadata: $e');
    }
  }

  Future<void> _removeTestImages(TestItem test) async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      final imageMetadata = await _getImageMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(test.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = imageMetadata.keys.where((key) => key.startsWith(test.id)).toList();
      for (final key in keysToRemove) {
        imageMetadata.remove(key);
      }
      
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      dev.log('Error removing test images: $e');
    }
  }

  Future<void> _clearAllImages() async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      dev.log('Cleared all cached images');
    } catch (e) {
      dev.log('Error clearing all images: $e');
    }
  }

  Future<Map<String, dynamic>> _getImageMetadata() async {
    try {
      final metadataJson = _storageService.getString(imageMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      dev.log('Error reading image metadata: $e');
      return {};
    }
  }

  Future<void> _saveImageMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(imageMetadataKey, json.encode(metadata));
    } catch (e) {
      dev.log('Error saving image metadata: $e');
    }
  }
}