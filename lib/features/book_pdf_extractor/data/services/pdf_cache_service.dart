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
  static const int maxCacheSize = 200 * 1024 * 1024; // 200MB
  static const int maxCacheAgeMs = 7 * 24 * 60 * 60 * 1000;
  
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
      await _cleanupExpiredCache();
      await _enforceMaxCacheSize();

      final cacheDir = await _pdfCacheDirectory;
      final pdfCacheDir = Directory('${cacheDir.path}/$pdfId');
      
      if (!await pdfCacheDir.exists()) {
        await pdfCacheDir.create(recursive: true);
      }
      
      int totalSize = 0;
      for (int i = 0; i < thumbnails.length; i++) {
        final thumbnailFile = File('${pdfCacheDir.path}/page_${i + 1}.png');
        await thumbnailFile.writeAsBytes(thumbnails[i]);
        totalSize += thumbnails[i].length;
      }
      
      await _updateCacheMetadata(pdfId, thumbnails.length, totalSize);
      
      return pdfCacheDir.path;
    } catch (e) {
      debugPrint('Error caching PDF thumbnails: $e');
      throw Exception('Failed to cache PDF thumbnails');
    }
  }

  Future<String> cachePdfThumbnailsStreaming(
    String pdfId, 
    Stream<Uint8List> thumbnailStream
  ) async {
    try {
      await _cleanupExpiredCache();
      await _enforceMaxCacheSize();

      final cacheDir = await _pdfCacheDirectory;
      final pdfCacheDir = Directory('${cacheDir.path}/$pdfId');
      
      if (!await pdfCacheDir.exists()) {
        await pdfCacheDir.create(recursive: true);
      }
      
      int pageCount = 0;
      int totalSize = 0;
      
      await for (final thumbnailBytes in thumbnailStream) {
        pageCount++;
        final thumbnailFile = File('${pdfCacheDir.path}/page_$pageCount.png');
        await thumbnailFile.writeAsBytes(thumbnailBytes);
        totalSize += thumbnailBytes.length;
      }
      
      await _updateCacheMetadata(pdfId, pageCount, totalSize);
      
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
      
      await _updateLastAccessed(pdfId);
      
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

  Future<bool> isCached(String pdfId) async {
    final metadata = await _getCacheMetadata();
    return metadata.containsKey(pdfId);
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
      log('Cleared PDF cache for: $pdfId');
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
      log('Cleared all PDF cache');
    } catch (e) {
      debugPrint('Error clearing all PDF cache: $e');
    }
  }

  Future<void> _cleanupExpiredCache() async {
    try {
      final metadata = await _getCacheMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiredKeys = <String>[];

      for (final entry in metadata.entries) {
        final cacheData = entry.value as Map<String, dynamic>;
        final cachedAt = cacheData['cachedAt'] as int;
        
        if (now - cachedAt > maxCacheAgeMs) {
          expiredKeys.add(entry.key);
        }
      }

      for (final key in expiredKeys) {
        await clearPdfCache(key);
      }

      if (expiredKeys.isNotEmpty) {
        log('Cleaned up ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      debugPrint('Error cleaning up expired cache: $e');
    }
  }

  Future<void> _enforceMaxCacheSize() async {
    try {
      final metadata = await _getCacheMetadata();
      int totalSize = 0;
      
      final cacheEntries = metadata.entries
          .map((e) => MapEntry(e.key, e.value as Map<String, dynamic>))
          .toList();

      for (final entry in cacheEntries) {
        totalSize += (entry.value['size'] as int? ?? 0);
      }

      if (totalSize <= maxCacheSize) return;

      cacheEntries.sort((a, b) {
        final aAccessed = a.value['lastAccessed'] as int? ?? 0;
        final bAccessed = b.value['lastAccessed'] as int? ?? 0;
        return aAccessed.compareTo(bAccessed);
      });

      while (totalSize > maxCacheSize && cacheEntries.isNotEmpty) {
        final oldestEntry = cacheEntries.removeAt(0);
        await clearPdfCache(oldestEntry.key);
        totalSize -= (oldestEntry.value['size'] as int? ?? 0);
      }

      log('Cache size enforced, removed old entries');
    } catch (e) {
      debugPrint('Error enforcing max cache size: $e');
    }
  }

  Future<void> _updateCacheMetadata(String pdfId, int pageCount, int size) async {
    try {
      final metadata = await _getCacheMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      metadata[pdfId] = {
        'pageCount': pageCount,
        'size': size,
        'cachedAt': now,
        'lastAccessed': now,
      };
      await _saveCacheMetadata(metadata);
    } catch (e) {
      debugPrint('Error updating cache metadata: $e');
    }
  }

  Future<void> _updateLastAccessed(String pdfId) async {
    try {
      final metadata = await _getCacheMetadata();
      if (metadata.containsKey(pdfId)) {
        final cacheData = metadata[pdfId] as Map<String, dynamic>;
        cacheData['lastAccessed'] = DateTime.now().millisecondsSinceEpoch;
        await _saveCacheMetadata(metadata);
      }
    } catch (e) {
      debugPrint('Error updating last accessed: $e');
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

  Future<Map<String, dynamic>> getCacheStats() async {
    final metadata = await _getCacheMetadata();
    int totalSize = 0;
    int totalFiles = 0;

    for (final entry in metadata.values) {
      final cacheData = entry as Map<String, dynamic>;
      totalSize += (cacheData['size'] as int? ?? 0);
      totalFiles += (cacheData['pageCount'] as int? ?? 0);
    }

    return {
      'totalEntries': metadata.length,
      'totalSize': totalSize,
      'totalFiles': totalFiles,
      'maxSize': maxCacheSize,
    };
  }
}