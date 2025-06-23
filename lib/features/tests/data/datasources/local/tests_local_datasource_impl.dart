import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:korean_language_app/features/tests/domain/entities/user_test_interation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';
import 'package:korean_language_app/features/tests/data/datasources/local/tests_local_datasource.dart';
import 'package:korean_language_app/shared/models/test_item.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/enums/test_sort_type.dart';

class TestsLocalDataSourceImpl implements TestsLocalDataSource {
  final StorageService _storageService;
  
  static const String testsKey = 'CACHED_TESTS';
  static const String userInteractionKey = 'USER_INTERACTION';
  static const String lastSyncKey = 'LAST_TESTS_SYNC_TIME';
  static const String testHashesKey = 'TEST_HASHES';
  static const String totalCountKey = 'TOTAL_TESTS_COUNT';
  static const String categoryCountPrefix = 'CATEGORY_COUNT_';
  static const String imageMetadataKey = 'IMAGE_METADATA';
  static const String audioMetadataKey = 'AUDIO_METADATA';
  
  Directory? _imagesCacheDir;
  Directory? _audioCacheDir;

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

  Future<Directory> get _audioCacheDirectory async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _audioCacheDir = Directory('${appDir.path}/tests_audio_cache');
    
    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
    }
    
    return _audioCacheDir!;
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
        await _removeTestAudio(testToRemove);
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
      await _storageService.remove(audioMetadataKey);
      
      final allKeys = _storageService.getAllKeys();
      for (final key in allKeys) {
        if (key.startsWith(categoryCountPrefix)) {
          await _storageService.remove(key);
        }
      }
      
      await _clearAllImages();
      await _clearAllAudio();
      
      dev.log('Cleared all tests cache, images, and audio');
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
  Future<List<TestItem>> getTestsPage(int page, int pageSize, {TestSortType sortType = TestSortType.recent}) async {
    try {
      final allTests = await getAllTests();
      final sortedTests = _applySorting(allTests, sortType);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedTests.length);
      
      if (startIndex >= sortedTests.length) return [];
      
      final result = sortedTests.sublist(startIndex, endIndex);
      dev.log('Retrieved ${result.length} tests (page $page, sortType: ${sortType.name})');
      
      return result;
    } catch (e) {
      dev.log('Error getting tests page: $e');
      return [];
    }
  }

  @override
  Future<List<TestItem>> getTestsByCategoryPage(String category, int page, int pageSize, {TestSortType sortType = TestSortType.recent}) async {
    try {
      final allTests = await getAllTests();
      final categoryTests = allTests.where((test) => 
        test.category.toString().split('.').last == category
      ).toList();
      
      final sortedTests = _applySorting(categoryTests, sortType);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedTests.length);
      
      if (startIndex >= sortedTests.length) return [];
      
      final result = sortedTests.sublist(startIndex, endIndex);
      dev.log('Retrieved ${result.length} category tests (page $page, category: $category, sortType: ${sortType.name})');
      
      return result;
    } catch (e) {
      dev.log('Error getting category tests page: $e');
      return [];
    }
  }

  List<TestItem> _applySorting(List<TestItem> tests, TestSortType sortType) {
    final sortedTests = List<TestItem>.from(tests);
    
    switch (sortType) {
      case TestSortType.recent:
        sortedTests.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime); // Descending (most recent first)
        });
        break;
        
      case TestSortType.popular:
        sortedTests.sort((a, b) {
          return b.popularity.compareTo(a.popularity); // Descending (most popular first)
        });
        break;
        
      case TestSortType.rating:
        sortedTests.sort((a, b) {
          return b.rating.compareTo(a.rating); // Descending (highest rating first)
        });
        break;
        
      case TestSortType.viewCount:
        sortedTests.sort((a, b) {
          return b.viewCount.compareTo(a.viewCount); // Descending (most viewed first)
        });
        break;
    }
    
    return sortedTests;
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

  @override
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
  Future<void> cacheAudio(String audioUrl, String testId, String audioType) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, testId, audioType);
      final cacheDir = await _audioCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        dev.log('Audio already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        dev.log('Cached audio: $fileName (${response.data.length} bytes)');
        
        await _updateAudioMetadata(testId, audioType, audioUrl);
      } else {
        dev.log('Failed to download audio: $audioUrl (${response.statusCode})');
      }
    } catch (e) {
      dev.log('Error caching audio $audioUrl: $e');
    }
  }

  @override
  Future<String?> getCachedImagePath(String imageUrl, String testId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, testId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        dev.log('Found cached image: $absolutePath');
        return absolutePath;
      } else {
        dev.log('Cached image not found: ${file.path}');
      }
    } catch (e) {
      dev.log('Error getting cached image path: $e');
    }
    return null;
  }

  @override
  Future<String?> getCachedAudioPath(String audioUrl, String testId, String audioType) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, testId, audioType);
      final cacheDir = await _audioCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        dev.log('Found cached audio: $absolutePath');
        return absolutePath;
      } else {
        dev.log('Cached audio not found: ${file.path}');
      }
    } catch (e) {
      dev.log('Error getting cached audio path: $e');
    }
    return null;
  }


  @override
  Future<UserTestInteraction?> getUserTestInteraction(String testId, String userId) async {
    try {
      final data = _storageService.getString(userInteractionKey);
      
      if(data == null) {
        return null;
      }
      if(data.isEmpty) {
        return null;
      }

      final jsonData = json.decode(data);
      final userInteraction = UserTestInteraction.fromJson(jsonData);

      return userInteraction;

    } catch (e) {
      dev.log('Error getting user interaction: $e');
      return null;
    }
  }

  @override
  Future<bool> saveUserTestInteraction(UserTestInteraction userInteraction) async{
    try {
      await _storageService.setString(userInteractionKey, json.encode(userInteraction.toJson()));
      return true;
    } catch (e) {
      dev.log('Error saving user interaction: $e');
      return false;
    }
  }

  String _generateImageFileName(String imageUrl, String testId, String imageType) {
    final urlHash = md5.convert(utf8.encode(imageUrl)).toString().substring(0, 8);
    return '${testId}_${imageType}_$urlHash.jpg';
  }

  String _generateAudioFileName(String audioUrl, String testId, String audioType) {
    final urlHash = md5.convert(utf8.encode(audioUrl)).toString().substring(0, 8);
    final extension = _getAudioExtensionFromUrl(audioUrl);
    return '${testId}_${audioType}_$urlHash$extension';
  }

  String _getAudioExtensionFromUrl(String audioUrl) {
    final uri = Uri.parse(audioUrl);
    final path = uri.path.toLowerCase();
    
    if (path.endsWith('.mp3')) return '.mp3';
    if (path.endsWith('.m4a')) return '.m4a';
    if (path.endsWith('.wav')) return '.wav';
    if (path.endsWith('.aac')) return '.aac';
    
    return '.m4a';
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

  Future<void> _updateAudioMetadata(String testId, String audioType, String audioUrl) async {
    try {
      final audioMetadata = await _getAudioMetadata();
      audioMetadata['${testId}_$audioType'] = {
        'url': audioUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      dev.log('Error updating audio metadata: $e');
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

  Future<void> _removeTestAudio(TestItem test) async {
    try {
      final cacheDir = await _audioCacheDirectory;
      final audioMetadata = await _getAudioMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(test.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = audioMetadata.keys.where((key) => key.startsWith(test.id)).toList();
      for (final key in keysToRemove) {
        audioMetadata.remove(key);
      }
      
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      dev.log('Error removing test audio: $e');
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

  Future<void> _clearAllAudio() async {
    try {
      final cacheDir = await _audioCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      dev.log('Cleared all cached audio');
    } catch (e) {
      dev.log('Error clearing all audio: $e');
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

  Future<Map<String, dynamic>> _getAudioMetadata() async {
    try {
      final metadataJson = _storageService.getString(audioMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      dev.log('Error reading audio metadata: $e');
      return {};
    }
  }

  Future<void> _saveAudioMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(audioMetadataKey, json.encode(metadata));
    } catch (e) {
      dev.log('Error saving audio metadata: $e');
    }
  }
}