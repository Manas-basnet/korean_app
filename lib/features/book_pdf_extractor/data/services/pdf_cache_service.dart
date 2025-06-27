import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';

class PdfCacheService {
  final StorageService _storageService;
  static const String pdfCacheKey = 'PDF_CACHE_METADATA';
  
  Directory? _pdfCacheDir;

  PdfCacheService({required StorageService storageService})
      : _storageService = storageService;

  Future<Directory> get _pdfCacheDirectory async {
    if (_pdfCacheDir != null) return _pdfCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _pdfCacheDir = Directory('${appDir.path}/pdf_editing_cache');
    
    if (!await _pdfCacheDir!.exists()) {
      await _pdfCacheDir!.create(recursive: true);
    }
    
    return _pdfCacheDir!;
  }

  Future<String> cachePdfThumbnails(String pdfId, List<Uint8List> thumbnails) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final pdfCacheDir = Directory('${cacheDir.path}/$pdfId');
      
      if (!await pdfCacheDir.exists()) {
        await pdfCacheDir.create(recursive: true);
      }
      
      for (int i = 0; i < thumbnails.length; i++) {
        final thumbnailFile = File('${pdfCacheDir.path}/page_${i + 1}.png');
        await thumbnailFile.writeAsBytes(thumbnails[i]);
      }
      
      await _updateCacheMetadata(pdfId, thumbnails.length);
      
      return pdfCacheDir.path;
    } catch (e) {
      debugPrint('Error caching PDF thumbnails: $e');
      throw Exception('Failed to cache PDF thumbnails');
    }
  }

  Future<List<String>> getCachedThumbnailPaths(String pdfId) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final pdfCacheDir = Directory('${cacheDir.path}/$pdfId');
      
      if (!await pdfCacheDir.exists()) {
        return [];
      }
      
      final files = await pdfCacheDir.list().toList();
      final imagePaths = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .map((file) => file.path)
          .toList();
      
      imagePaths.sort((a, b) {
        final aNum = int.tryParse(a.split('page_')[1].split('.')[0]) ?? 0;
        final bNum = int.tryParse(b.split('page_')[1].split('.')[0]) ?? 0;
        return aNum.compareTo(bNum);
      });
      
      return imagePaths;
    } catch (e) {
      debugPrint('Error getting cached thumbnail paths: $e');
      return [];
    }
  }

  Future<void> clearPdfCache(String pdfId) async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      final pdfCacheDir = Directory('${cacheDir.path}/$pdfId');
      
      if (await pdfCacheDir.exists()) {
        await pdfCacheDir.delete(recursive: true);
      }
      
      final metadata = await _getCacheMetadata();
      metadata.remove(pdfId);
      await _saveCacheMetadata(metadata);
      log('cleared pdf cache');
    } catch (e) {
      debugPrint('Error clearing PDF cache: $e');
    }
  }

  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _pdfCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      
      await _storageService.remove(pdfCacheKey);
      log('cleared pdf cache');
    } catch (e) {
      debugPrint('Error clearing all PDF cache: $e');
    }
  }

  Future<void> _updateCacheMetadata(String pdfId, int pageCount) async {
    try {
      final metadata = await _getCacheMetadata();
      metadata[pdfId] = {
        'pageCount': pageCount,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _saveCacheMetadata(metadata);
    } catch (e) {
      debugPrint('Error updating cache metadata: $e');
    }
  }

  Future<Map<String, dynamic>> _getCacheMetadata() async {
    try {
      final metadataJson = _storageService.getString(pdfCacheKey);
      if (metadataJson == null) return {};
      
      return json.decode(metadataJson);
    } catch (e) {
      debugPrint('Error reading cache metadata: $e');
      return {};
    }
  }

  Future<void> _saveCacheMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storageService.setString(pdfCacheKey, json.encode(metadata));
    } catch (e) {
      debugPrint('Error saving cache metadata: $e');
    }
  }
}