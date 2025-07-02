import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:korean_language_app/shared/services/storage_service.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';

class AudioCacheService {
  final StorageService _storageService;
  static const String audioMetadataKey = 'BOOK_AUDIO_METADATA';
  
  Directory? _audioCacheDir;

  AudioCacheService({required StorageService storageService})
      : _storageService = storageService;

  Future<Directory> get _audioCacheDirectory async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _audioCacheDir = Directory('${appDir.path}/books_audio_cache');
    
    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
    }
    
    return _audioCacheDir!;
  }

  Future<void> cacheBookAudioTracks(BookItem book) async {
    try {
      for (final audioTrack in book.audioTracks) {
        if (audioTrack.audioUrl != null && audioTrack.audioUrl!.isNotEmpty) {
          await cacheAudioTrack(audioTrack.audioUrl!, book.id, audioTrack.id);
        }
      }
      
      for (final chapter in book.chapters) {
        for (final audioTrack in chapter.audioTracks) {
          if (audioTrack.audioUrl != null && audioTrack.audioUrl!.isNotEmpty) {
            await cacheChapterAudioTrack(audioTrack.audioUrl!, book.id, chapter.id, audioTrack.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error caching book audio tracks: $e');
    }
  }

  Future<void> cacheAudioTrack(String audioUrl, String bookId, String audioTrackId) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, bookId, audioTrackId);
      final cacheDir = await _audioCacheDirectory;
      final bookDir = Directory('${cacheDir.path}/$bookId');
      
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }
      
      final file = File('${bookDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('Audio already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        debugPrint('Cached book audio track: $fileName (${response.data.length} bytes)');
        
        await _updateAudioMetadata(bookId, audioTrackId, audioUrl);
      } else {
        debugPrint('Failed to download book audio: $audioUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching book audio $audioUrl: $e');
    }
  }

  Future<void> cacheChapterAudioTrack(String audioUrl, String bookId, String chapterId, String audioTrackId) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, bookId, audioTrackId);
      final cacheDir = await _audioCacheDirectory;
      final chapterDir = Directory('${cacheDir.path}/$bookId/chapters/$chapterId');
      
      if (!await chapterDir.exists()) {
        await chapterDir.create(recursive: true);
      }
      
      final file = File('${chapterDir.path}/$fileName');
      
      if (await file.exists()) {
        debugPrint('Chapter audio already cached: $fileName');
        return;
      }
      
      final dio = Dio();
      final response = await dio.get(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data);
        debugPrint('Cached chapter audio track: $fileName (${response.data.length} bytes)');
        
        await _updateChapterAudioMetadata(bookId, chapterId, audioTrackId, audioUrl);
      } else {
        debugPrint('Failed to download chapter audio: $audioUrl (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error caching chapter audio $audioUrl: $e');
    }
  }

  Future<String?> getCachedAudioPath(String audioUrl, String bookId, String audioTrackId) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, bookId, audioTrackId);
      final cacheDir = await _audioCacheDirectory;
      final bookDir = Directory('${cacheDir.path}/$bookId');
      final file = File('${bookDir.path}/$fileName');
      
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      debugPrint('Error getting cached audio path: $e');
    }
    return null;
  }

  Future<String?> getCachedChapterAudioPath(String audioUrl, String bookId, String chapterId, String audioTrackId) async {
    try {
      final fileName = _generateAudioFileName(audioUrl, bookId, audioTrackId);
      final cacheDir = await _audioCacheDirectory;
      final chapterDir = Directory('${cacheDir.path}/$bookId/chapters/$chapterId');
      final file = File('${chapterDir.path}/$fileName');
      
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      debugPrint('Error getting cached chapter audio path: $e');
    }
    return null;
  }

  Future<void> removeBookAudioTracks(String bookId) async {
    try {
      final cacheDir = await _audioCacheDirectory;
      final bookDir = Directory('${cacheDir.path}/$bookId');
      
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
        debugPrint('Deleted cached audio tracks for book: $bookId');
      }
      
      final audioMetadata = await _getAudioMetadata();
      audioMetadata.remove(bookId);
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error removing book audio tracks: $e');
    }
  }

  Future<void> clearAllAudioTracks() async {
    try {
      final cacheDir = await _audioCacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      
      await _storageService.remove(audioMetadataKey);
      
      debugPrint('Cleared all cached audio tracks');
    } catch (e) {
      debugPrint('Error clearing all audio tracks: $e');
    }
  }

  Future<BookItem> processBookWithCachedAudio(BookItem book) async {
    try {
      final updatedAudioTracks = <AudioTrack>[];
      
      for (final audioTrack in book.audioTracks) {
        AudioTrack updatedTrack = audioTrack;
        
        if (audioTrack.audioUrl != null && audioTrack.audioUrl!.isNotEmpty) {
          final cachedPath = await getCachedAudioPath(audioTrack.audioUrl!, book.id, audioTrack.id);
          if (cachedPath != null && (audioTrack.audioPath == null || audioTrack.audioPath!.isEmpty)) {
            updatedTrack = updatedTrack.copyWith(audioPath: cachedPath);
          }
        }
        
        updatedAudioTracks.add(updatedTrack);
      }
      
      final updatedChapters = book.chapters.map((chapter) {
        final updatedChapterAudioTracks = <AudioTrack>[];
        
        for (final audioTrack in chapter.audioTracks) {
          AudioTrack updatedTrack = audioTrack;
          
          if (audioTrack.audioUrl != null && audioTrack.audioUrl!.isNotEmpty) {
            final cachedPath = getCachedChapterAudioPath(audioTrack.audioUrl!, book.id, chapter.id, audioTrack.id);
            cachedPath.then((path) {
              if (path != null && (audioTrack.audioPath == null || audioTrack.audioPath!.isEmpty)) {
                updatedTrack = updatedTrack.copyWith(audioPath: path);
              }
            });
          }
          
          updatedChapterAudioTracks.add(updatedTrack);
        }
        
        return chapter.copyWith(audioTracks: updatedChapterAudioTracks);
      }).toList();
      
      return book.copyWith(
        audioTracks: updatedAudioTracks,
        chapters: updatedChapters,
      );
    } catch (e) {
      debugPrint('Error processing book with cached audio: $e');
      return book;
    }
  }

  String _generateAudioFileName(String audioUrl, String bookId, String audioTrackId) {
    final urlHash = md5.convert(utf8.encode(audioUrl)).toString().substring(0, 8);
    final extension = _getAudioExtension(audioUrl);
    return '${bookId}_${audioTrackId}_$urlHash$extension';
  }

  String _getAudioExtension(String audioUrl) {
    final uri = Uri.parse(audioUrl);
    final path = uri.path.toLowerCase();
    
    if (path.contains('.mp3')) return '.mp3';
    if (path.contains('.m4a')) return '.m4a';
    if (path.contains('.aac')) return '.aac';
    if (path.contains('.wav')) return '.wav';
    if (path.contains('.ogg')) return '.ogg';
    
    return '.m4a';
  }

  Future<void> _updateAudioMetadata(String bookId, String audioTrackId, String audioUrl) async {
    try {
      final audioMetadata = await _getAudioMetadata();
      
      if (!audioMetadata.containsKey(bookId)) {
        audioMetadata[bookId] = <String, dynamic>{};
      }
      
      final bookMetadata = audioMetadata[bookId] as Map<String, dynamic>;
      
      if (!bookMetadata.containsKey('audioTracks')) {
        bookMetadata['audioTracks'] = <String, dynamic>{};
      }
      
      final audioTracks = bookMetadata['audioTracks'] as Map<String, dynamic>;
      audioTracks[audioTrackId] = {
        'url': audioUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error updating audio metadata: $e');
    }
  }

  Future<void> _updateChapterAudioMetadata(String bookId, String chapterId, String audioTrackId, String audioUrl) async {
    try {
      final audioMetadata = await _getAudioMetadata();
      
      if (!audioMetadata.containsKey(bookId)) {
        audioMetadata[bookId] = <String, dynamic>{};
      }
      
      final bookMetadata = audioMetadata[bookId] as Map<String, dynamic>;
      
      if (!bookMetadata.containsKey('chapters')) {
        bookMetadata['chapters'] = <String, dynamic>{};
      }
      
      final chapters = bookMetadata['chapters'] as Map<String, dynamic>;
      
      if (!chapters.containsKey(chapterId)) {
        chapters[chapterId] = <String, dynamic>{};
      }
      
      final chapterMetadata = chapters[chapterId] as Map<String, dynamic>;
      
      if (!chapterMetadata.containsKey('audioTracks')) {
        chapterMetadata['audioTracks'] = <String, dynamic>{};
      }
      
      final audioTracks = chapterMetadata['audioTracks'] as Map<String, dynamic>;
      audioTracks[audioTrackId] = {
        'url': audioUrl,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _saveAudioMetadata(audioMetadata);
    } catch (e) {
      debugPrint('Error updating chapter audio metadata: $e');
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
}