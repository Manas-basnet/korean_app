import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';
import 'package:korean_language_app/features/vocabularies/data/datasources/local/vocabularies_local_datasource.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';



class VocabulariesLocalDataSourceImpl implements VocabulariesLocalDataSource {
  
  VocabulariesLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  final StorageService _storageService;
  
  static const String vocabulariesKey = 'CACHED_VOCABULARIES';
  static const String lastSyncKey = 'LAST_VOCABULARIES_SYNC_TIME';
  static const String vocabularyHashesKey = 'VOCABULARY_HASHES';
  static const String totalCountKey = 'TOTAL_VOCABULARIES_COUNT';
  static const String levelCountPrefix = 'LEVEL_VOCABULARIES_COUNT_';
  static const String languageCountPrefix = 'LANGUAGE_VOCABULARIES_COUNT_';
  static const String imageMetadataKey = 'VOCABULARY_IMAGE_METADATA';
  static const String audioMetadataKey = 'VOCABULARY_AUDIO_METADATA';
  static const String pdfMetadataKey = 'VOCABULARY_PDF_METADATA';

  Directory? _imagesCacheDir;
  Directory? _audioCacheDir;
  Directory? _pdfsCacheDir;


  Future<Directory> get _imagesCacheDirectory async {
    if (_imagesCacheDir != null) return _imagesCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _imagesCacheDir = Directory('${appDir.path}/vocabularies_images_cache');
    
    if (!await _imagesCacheDir!.exists()) {
      await _imagesCacheDir!.create(recursive: true);
    }
    
    return _imagesCacheDir!;
  }

  Future<Directory> get _audioCacheDirectory async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _audioCacheDir = Directory('${appDir.path}/vocabularies_audio_cache');
    
    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
    }
    
    return _audioCacheDir!;
  }

  Future<Directory> get _pdfsCacheDirectory async {
    if (_pdfsCacheDir != null) return _pdfsCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _pdfsCacheDir = Directory('${appDir.path}/vocabularies_pdfs_cache');
    
    if (!await _pdfsCacheDir!.exists()) {
      await _pdfsCacheDir!.create(recursive: true);
    }
    
    return _pdfsCacheDir!;
  }

  @override
  Future<List<VocabularyItem>> getAllVocabularies() async {
    try {
      final jsonString = _storageService.getString(vocabulariesKey);
      if (jsonString == null) return [];
      
      final List<dynamic> decodedJson = json.decode(jsonString);
      final vocabularies = decodedJson.map((item) => VocabularyItem.fromJson(item)).toList();
      
      return vocabularies;
    } catch (e) {
      debugPrint('Error reading vocabularies from storage: $e');
      return [];
    }
  }

  @override
  Future<void> saveVocabularies(List<VocabularyItem> vocabularies) async {
    try {
      final jsonList = vocabularies.map((vocabulary) => vocabulary.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _storageService.setString(vocabulariesKey, jsonString);
      
      debugPrint('Saved ${vocabularies.length} vocabularies to cache');
    } catch (e) {
      debugPrint('Error saving vocabularies to storage: $e');
      throw Exception('Failed to save vocabularies: $e');
    }
  }

  @override
  Future<void> addVocabulary(VocabularyItem vocabulary) async {
    try {
      final vocabularies = await getAllVocabularies();
      final existingIndex = vocabularies.indexWhere((v) => v.id == vocabulary.id);
      
      if (existingIndex != -1) {
        vocabularies[existingIndex] = vocabulary;
      } else {
        vocabularies.add(vocabulary);
      }
      
      await saveVocabularies(vocabularies);
    } catch (e) {
      debugPrint('Error adding vocabulary to storage: $e');
      throw Exception('Failed to add vocabulary: $e');
    }
  }

  @override
  Future<void> updateVocabulary(VocabularyItem vocabulary) async {
    try {
      final vocabularies = await getAllVocabularies();
      final vocabularyIndex = vocabularies.indexWhere((v) => v.id == vocabulary.id);
      
      if (vocabularyIndex != -1) {
        vocabularies[vocabularyIndex] = vocabulary;
        await saveVocabularies(vocabularies);
      } else {
        throw Exception('Vocabulary not found for update: ${vocabulary.id}');
      }
    } catch (e) {
      debugPrint('Error updating vocabulary in storage: $e');
      throw Exception('Failed to update vocabulary: $e');
    }
  }

  @override
  Future<void> removeVocabulary(String vocabularyId) async {
    try {
      final vocabularies = await getAllVocabularies();
      final vocabularyToRemove = vocabularies.firstWhere(
        (vocabulary) => vocabulary.id == vocabularyId, 
        orElse: () => const VocabularyItem(
          id: '', 
          title: '', 
          description: '', 
          primaryLanguage: SupportedLanguage.english,
          level: BookLevel.beginner,
        )
      );
      
      if (vocabularyToRemove.id.isNotEmpty) {
        await _removeVocabularyImages(vocabularyToRemove);
        await _removeVocabularyAudio(vocabularyToRemove);
        await _removeVocabularyPdfs(vocabularyToRemove);
      }
      
      final updatedVocabularies = vocabularies.where((vocabulary) => vocabulary.id != vocabularyId).toList();
      await saveVocabularies(updatedVocabularies);
    } catch (e) {
      debugPrint('Error removing vocabulary from storage: $e');
      throw Exception('Failed to remove vocabulary: $e');
    }
  }

  @override
  Future<void> clearAllVocabularies() async {
    try {
      await _storageService.remove(vocabulariesKey);
      await _storageService.remove(lastSyncKey);
      await _storageService.remove(vocabularyHashesKey);
      await _storageService.remove(totalCountKey);
      await _storageService.remove(imageMetadataKey);
      await _storageService.remove(audioMetadataKey);
      await _storageService.remove(pdfMetadataKey);
      
      final allKeys = _storageService.getAllKeys();
      for (final key in allKeys) {
        if (key.startsWith(levelCountPrefix) || key.startsWith(languageCountPrefix)) {
          await _storageService.remove(key);
        }
      }
      
      await _clearAllImages();
      await _clearAllAudio();
      await _clearAllPdfs();
      
      debugPrint('Cleared all vocabularies cache, images, audio, and PDFs');
    } catch (e) {
      debugPrint('Error clearing all vocabularies from storage: $e');
    }
  }

  @override
  Future<bool> hasAnyVocabularies() async {
    try {
      final vocabularies = await getAllVocabularies();
      return vocabularies.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getVocabulariesCount() async {
    try {
      final vocabularies = await getAllVocabularies();
      return vocabularies.length;
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
  Future<void> setVocabularyHashes(Map<String, String> hashes) async {
    await _storageService.setString(vocabularyHashesKey, json.encode(hashes));
  }

  @override
  Future<Map<String, String>> getVocabularyHashes() async {
    try {
      final hashesJson = _storageService.getString(vocabularyHashesKey);
      if (hashesJson == null) return {};
      
      final Map<String, dynamic> decoded = json.decode(hashesJson);
      return decoded.cast<String, String>();
    } catch (e) {
      debugPrint('Error reading vocabulary hashes: $e');
      return {};
    }
  }

  @override
  Future<List<VocabularyItem>> getVocabulariesPage(int page, int pageSize) async {
    try {
      final allVocabularies = await getAllVocabularies();
      final sortedVocabularies = _applySorting(allVocabularies);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedVocabularies.length);
      
      if (startIndex >= sortedVocabularies.length) return [];
      
      final result = sortedVocabularies.sublist(startIndex, endIndex);
      debugPrint('Retrieved ${result.length} vocabularies (page $page)');
      
      return result;
    } catch (e) {
      debugPrint('Error getting vocabularies page: $e');
      return [];
    }
  }

  @override
  Future<List<VocabularyItem>> getVocabulariesByLevelPage(BookLevel level, int page, int pageSize) async {
    try {
      final allVocabularies = await getAllVocabularies();
      final levelVocabularies = allVocabularies.where((vocabulary) => 
        vocabulary.level == level
      ).toList();
      
      final sortedVocabularies = _applySorting(levelVocabularies);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedVocabularies.length);
      
      if (startIndex >= sortedVocabularies.length) return [];
      
      final result = sortedVocabularies.sublist(startIndex, endIndex);
      debugPrint('Retrieved ${result.length} level vocabularies (page $page, level: ${level.name})');
      
      return result;
    } catch (e) {
      debugPrint('Error getting level vocabularies page: $e');
      return [];
    }
  }

  @override
  Future<List<VocabularyItem>> getVocabulariesByLanguagePage(SupportedLanguage language, int page, int pageSize) async {
    try {
      final allVocabularies = await getAllVocabularies();
      final languageVocabularies = allVocabularies.where((vocabulary) => 
        vocabulary.primaryLanguage == language
      ).toList();
      
      final sortedVocabularies = _applySorting(languageVocabularies);
      
      final startIndex = page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, sortedVocabularies.length);
      
      if (startIndex >= sortedVocabularies.length) return [];
      
      final result = sortedVocabularies.sublist(startIndex, endIndex);
      debugPrint('Retrieved ${result.length} language vocabularies (page $page, language: ${language.name})');
      
      return result;
    } catch (e) {
      debugPrint('Error getting language vocabularies page: $e');
      return [];
    }
  }

  List<VocabularyItem> _applySorting(List<VocabularyItem> vocabularies) {
    final sortedVocabularies = List<VocabularyItem>.from(vocabularies);
    
    sortedVocabularies.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    
    return sortedVocabularies;
  }

  @override
  Future<void> setTotalVocabulariesCount(int count) async {
    await _storageService.setInt(totalCountKey, count);
  }

  @override
  Future<int?> getTotalVocabulariesCount() async {
    return _storageService.getInt(totalCountKey);
  }

  @override
  Future<void> setLevelVocabulariesCount(BookLevel level, int count) async {
    await _storageService.setInt('$levelCountPrefix${level.name}', count);
  }

  @override
  Future<int?> getLevelVocabulariesCount(BookLevel level) async {
    return _storageService.getInt('$levelCountPrefix${level.name}');
  }

  @override
  Future<void> setLanguageVocabulariesCount(SupportedLanguage language, int count) async {
    await _storageService.setInt('$languageCountPrefix${language.name}', count);
  }

  @override
  Future<int?> getLanguageVocabulariesCount(SupportedLanguage language) async {
    return _storageService.getInt('$languageCountPrefix${language.name}');
  }

  @override
  Future<void> cacheImage(String imageUrl, String vocabularyId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, vocabularyId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('Image already cached: $fileName');
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
        debugPrint('Cached image: $fileName (${response.data.length} bytes)');
        
        await _updateImageMetadata(vocabularyId, imageType, imageUrl);
      } else {
        debugPrint('Failed to download image: $imageUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching image $imageUrl: $e');
    }
  }

  @override
  Future<void> cacheAudio(String audioUrl, String vocabularyId, String audioType) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, vocabularyId, audioType);
      final cacheDir = await _audioCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('Audio already cached: $fileName');
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
        debugPrint('Cached audio: $fileName (${response.data.length} bytes)');
        
        await _updateAudioMetadata(vocabularyId, audioType, audioUrl);
      } else {
        debugPrint('Failed to download audio: $audioUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching audio $audioUrl: $e');
    }
  }

  @override
  Future<void> cachePdf(String pdfUrl, String vocabularyId, String filename) async {
    try {
      final fileName = _generatePdfFileName(pdfUrl, vocabularyId, filename);
      final cacheDir = await _pdfsCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('PDF already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        pdfUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        debugPrint('Cached PDF: $fileName (${response.data.length} bytes)');
        
        await _updatePdfMetadata(vocabularyId, filename, pdfUrl);
      } else {
        debugPrint('Failed to download PDF: $pdfUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching PDF $pdfUrl: $e');
    }
  }

  @override
  Future<String?> getCachedImagePath(String imageUrl, String vocabularyId, String imageType) async {
    try {
      final fileName = _generateImageFileName(imageUrl, vocabularyId, imageType);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        debugPrint('Found cached image: $absolutePath');
        return absolutePath;
      } else {
        debugPrint('Cached image not found: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error getting cached image path: $e');
    }
    return null;
  }

  @override
  Future<String?> getCachedAudioPath(String audioUrl, String vocabularyId, String audioType) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, vocabularyId, audioType);
      final cacheDir = await _audioCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        debugPrint('Found cached audio: $absolutePath');
        return absolutePath;
      } else {
        debugPrint('Cached audio not found: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error getting cached audio path: $e');
    }
    return null;
  }

  @override
  Future<String?> getCachedPdfPath(String pdfUrl, String vocabularyId, String filename) async {
    try {
      final fileName = _generatePdfFileName(pdfUrl, vocabularyId, filename);
      final cacheDir = await _pdfsCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        final absolutePath = file.absolute.path;
        debugPrint('Found cached PDF: $absolutePath');
        return absolutePath;
      } else {
        debugPrint('Cached PDF not found: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error getting cached PDF path: $e');
    }
    return null;
  }

  String _generateImageFileName(String imageUrl, String vocabularyId, String imageType) {
    final urlHash = md5.convert(utf8.encode(imageUrl)).toString().substring(0, 8);
    return '${vocabularyId}_${imageType}_$urlHash.jpg';
  }

  String _generateAudioFileName(String audioUrl, String vocabularyId, String audioType) {
    final urlHash = md5.convert(utf8.encode(audioUrl)).toString().substring(0, 8);
    final extension = _getAudioExtensionFromUrl(audioUrl);
    return '${vocabularyId}_${audioType}_$urlHash$extension';
  }

  String _generatePdfFileName(String pdfUrl, String vocabularyId, String filename) {
    final urlHash = md5.convert(utf8.encode(pdfUrl)).toString().substring(0, 8);
    final cleanFilename = filename.replaceAll(RegExp(r'[^\w\-_.]'), '_');
    return '${vocabularyId}_${urlHash}_$cleanFilename';
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

  Future<void> _updateImageMetadata(String vocabularyId, String imageType, String imageUrl) async {
    try {
      final imageMetadata = await _getImageMetadata();
      imageMetadata['${vocabularyId}_$imageType'] = {
        'url': imageUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      debugPrint('Error updating image metadata: $e');
    }
  }

  Future<void> _updateAudioMetadata(String vocabularyId, String audioType, String audioUrl) async {
    try {
      final audioMetadata = await _getAudioMetadata();
      audioMetadata['${vocabularyId}_$audioType'] = {
        'url': audioUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error updating audio metadata: $e');
    }
  }

  Future<void> _updatePdfMetadata(String vocabularyId, String filename, String pdfUrl) async {
    try {
      final pdfMetadata = await _getPdfMetadata();
      pdfMetadata['${vocabularyId}_$filename'] = {
        'url': pdfUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _savePdfMetadata(pdfMetadata);
    } catch (e) {
      debugPrint('Error updating PDF metadata: $e');
    }
  }

  Future<void> _removeVocabularyImages(VocabularyItem vocabulary) async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      final imageMetadata = await _getImageMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(vocabulary.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = imageMetadata.keys.where((key) => key.startsWith(vocabulary.id)).toList();
      for (final key in keysToRemove) {
        imageMetadata.remove(key);
      }
      
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      debugPrint('Error removing vocabulary images: $e');
    }
  }

  Future<void> _removeVocabularyAudio(VocabularyItem vocabulary) async {
    try {
      final cacheDir = await _audioCacheDirectory;
      final audioMetadata = await _getAudioMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(vocabulary.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = audioMetadata.keys.where((key) => key.startsWith(vocabulary.id)).toList();
      for (final key in keysToRemove) {
        audioMetadata.remove(key);
      }
      
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error removing vocabulary audio: $e');
    }
  }

  Future<void> _removeVocabularyPdfs(VocabularyItem vocabulary) async {
    try {
      final cacheDir = await _pdfsCacheDirectory;
      final pdfMetadata = await _getPdfMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(vocabulary.id)) {
          await fileEntity.delete();
        }
      }
      
      final keysToRemove = pdfMetadata.keys.where((key) => key.startsWith(vocabulary.id)).toList();
      for (final key in keysToRemove) {
        pdfMetadata.remove(key);
      }
      
      await _savePdfMetadata(pdfMetadata);
    } catch (e) {
      debugPrint('Error removing vocabulary PDFs: $e');
    }
  }

  Future<void> _clearAllImages() async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      debugPrint('Cleared all cached images');
    } catch (e) {
      debugPrint('Error clearing all images: $e');
    }
  }

  Future<void> _clearAllAudio() async {
    try {
      final cacheDir = await _audioCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      debugPrint('Cleared all cached audio');
    } catch (e) {
      debugPrint('Error clearing all audio: $e');
    }
  }

  Future<void> _clearAllPdfs() async {
    try {
      final cacheDir = await _pdfsCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      debugPrint('Cleared all cached PDFs');
    } catch (e) {
      debugPrint('Error clearing all PDFs: $e');
    }
  }

  Future<Map<String, dynamic>> _getImageMetadata() async {
    try {
      final metadataJson = _storageService.getString(imageMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading image metadata: $e');
      return {};
    }
  }

  Future<void> _saveImageMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(imageMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving image metadata: $e');
    }
  }

  Future<Map<String, dynamic>> _getAudioMetadata() async {
    try {
      final metadataJson = _storageService.getString(audioMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading audio metadata: $e');
      return {};
    }
  }

  Future<void> _saveAudioMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(audioMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving audio metadata: $e');
    }
  }

  Future<Map<String, dynamic>> _getPdfMetadata() async {
    try {
      final metadataJson = _storageService.getString(pdfMetadataKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading PDF metadata: $e');
      return {};
    }
  }

  Future<void> _savePdfMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(pdfMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving PDF metadata: $e');
    }
  }

}