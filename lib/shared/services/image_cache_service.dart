// lib/features/books/data/services/image_cache_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';

class ImageCacheService {
  final StorageService _storageService;
  static const String imageMetadataKey = 'BOOK_IMAGE_METADATA';
  
  Directory? _imagesCacheDir;

  ImageCacheService({required StorageService storageService})
      : _storageService = storageService;

  Future<Directory> get _imagesCacheDirectory async {
    if (_imagesCacheDir != null) return _imagesCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _imagesCacheDir = Directory('${appDir.path}/books_images_cache');
    
    if (!await _imagesCacheDir!.exists()) {
      await _imagesCacheDir!.create(recursive: true);
    }
    
    return _imagesCacheDir!;
  }

  Future<void> cacheImage(String imageUrl, String bookId) async {
    try {
      final fileName = _generateImageFileName(imageUrl, bookId);
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
        debugPrint('Cached book image: $fileName (${response.data.length} bytes)');
        
        await _updateImageMetadata(bookId, imageUrl);
      } else {
        debugPrint('Failed to download book image: $imageUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching book image $imageUrl: $e');
    }
  }

  Future<String?> getCachedImagePath(String imageUrl, String bookId) async {
    try {
      final fileName = _generateImageFileName(imageUrl, bookId);
      final cacheDir = await _imagesCacheDirectory;
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      debugPrint('Error getting cached image path: $e');
    }
    return null;
  }

  Future<void> removeBookImages(String bookId) async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      final imageMetadata = await _getImageMetadata();
      
      final files = await cacheDir.list().toList();
      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.contains(bookId)) {
          await fileEntity.delete();
          debugPrint('Deleted cached image: ${fileEntity.path}');
        }
      }
      
      imageMetadata.remove(bookId);
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      debugPrint('Error removing book images: $e');
    }
  }

  Future<void> clearAllImages() async {
    try {
      final cacheDir = await _imagesCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      
      await _storageService.remove(imageMetadataKey);
      
      debugPrint('Cleared all cached book images');
    } catch (e) {
      debugPrint('Error clearing all images: $e');
    }
  }

  String _generateImageFileName(String imageUrl, String bookId) {
    final urlHash = md5.convert(utf8.encode(imageUrl)).toString().substring(0, 8);
    return '${bookId}_main_$urlHash.jpg';
  }

  Future<void> _updateImageMetadata(String bookId, String imageUrl) async {
    try {
      final imageMetadata = await _getImageMetadata();
      imageMetadata[bookId] = {
        'url': imageUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveImageMetadata(imageMetadata);
    } catch (e) {
      debugPrint('Error updating image metadata: $e');
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
}