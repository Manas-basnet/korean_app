import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:korean_language_app/core/enums/audio_display_type.dart';
import 'package:korean_language_app/shared/models/audio_display_source.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';

class CustomCachedAudio extends StatefulWidget {
  final String? audioUrl;
  final String? audioPath;
  final String? label;
  final double height;
  final VoidCallback? onError;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CustomCachedAudio({
    super.key,
    this.audioUrl,
    this.audioPath,
    this.label,
    this.height = 60,
    this.onError,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CustomCachedAudio> createState() => _CustomCachedAudioState();
}

class _CustomCachedAudioState extends State<CustomCachedAudio> {
  AudioDisplaySource? _cachedAudioSource;
  bool _isResolving = false;
  String? _lastAudioPath;
  String? _lastAudioUrl;
  
  // State class variables
  late String? audioUrl;
  late String? audioPath;
  late String? label;
  late double height;
  late VoidCallback? onError;
  late Widget Function(BuildContext, String)? placeholder;
  late Widget Function(BuildContext, String, dynamic)? errorWidget;

  @override
  void initState() {
    super.initState();
    _initializeStateVariables();
    _resolveAudioSource();
  }

  @override
  void didUpdateWidget(CustomCachedAudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldAudioPath = audioPath;
    final oldAudioUrl = audioUrl;
    
    _initializeStateVariables();
    
    if (oldAudioPath != audioPath || oldAudioUrl != audioUrl) {
      _resolveAudioSource();
    }
  }
  
  void _initializeStateVariables() {
    audioUrl = widget.audioUrl;
    audioPath = widget.audioPath;
    label = widget.label;
    height = widget.height;
    onError = widget.onError;
    placeholder = widget.placeholder;
    errorWidget = widget.errorWidget;
  }

  Future<void> _resolveAudioSource() async {
    if (_isResolving) return;
    
    if (widget.audioPath == _lastAudioPath && widget.audioUrl == _lastAudioUrl && _cachedAudioSource != null) {
      return;
    }
    
    setState(() {
      _isResolving = true;
    });
    
    try {
      final audioSource = await _determineAudioSource();
      
      if (mounted) {
        setState(() {
          _cachedAudioSource = audioSource;
          _lastAudioPath = widget.audioPath;
          _lastAudioUrl = widget.audioUrl;
          _isResolving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedAudioSource = AudioDisplaySource(type: AudioDisplayType.none);
          _lastAudioPath = widget.audioPath;
          _lastAudioUrl = widget.audioUrl;
          _isResolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving || _cachedAudioSource == null) {
      return _buildLoadingWidget(context);
    }
    
    switch (_cachedAudioSource!.type) {
      case AudioDisplayType.localFile:
        return _buildLocalAudio(context, _cachedAudioSource!.path!);
      case AudioDisplayType.networkUrl:
        return _buildNetworkAudio(context, _cachedAudioSource!.url!);
      case AudioDisplayType.none:
        return _buildErrorWidget(context, 'No audio available');
    }
  }

  Future<AudioDisplaySource> _determineAudioSource() async {
    if (audioPath != null && audioPath!.isNotEmpty) {
      final resolvedPath = await _resolveAudioPath(audioPath!);
      if (resolvedPath != null) {
        final file = File(resolvedPath);
        if (await file.exists()) {
          return AudioDisplaySource(type: AudioDisplayType.localFile, path: resolvedPath);
        }
      }
    }
    
    if (audioUrl != null && audioUrl!.isNotEmpty) {
      return AudioDisplaySource(type: AudioDisplayType.networkUrl, url: audioUrl);
    }
    
    return AudioDisplaySource(type: AudioDisplayType.none);
  }

  Future<String?> _resolveAudioPath(String path) async {
    try {
      if (path.startsWith('/')) {
        return path;
      }
      
      final documentsDir = await getApplicationDocumentsDirectory();
      final fullPath = '${documentsDir.path}/$path';
      
      if (await File(fullPath).exists()) {
        return fullPath;
      }
      
      final cacheDir = Directory('${documentsDir.path}/tests_audio_cache');
      final cachePath = '${cacheDir.path}/$path';
      
      if (await File(cachePath).exists()) {
        return cachePath;
      }
      
      if (path.contains('/')) {
        final fileName = path.split('/').last;
        final files = await cacheDir.list().toList();
        
        for (final fileEntity in files) {
          if (fileEntity is File && fileEntity.path.endsWith(fileName)) {
            return fileEntity.path;
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildLocalAudio(BuildContext context, String path) {
    return AudioPlayerWidget(
      audioPath: path,
      label: label,
      height: height,
    );
  }

  Widget _buildNetworkAudio(BuildContext context, String url) {
    return AudioPlayerWidget(
      audioUrl: url,
      label: label,
      height: height,
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha : 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha : 0.3)
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Loading audio...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String message) {
    if (errorWidget != null) {
      return errorWidget!(context, message, null);
    }
    
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha : 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha : 0.3)
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}