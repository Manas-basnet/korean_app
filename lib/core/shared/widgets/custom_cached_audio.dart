import 'dart:io';
import 'package:flutter/material.dart';
import 'package:korean_language_app/core/enums/audio_display_type.dart';
import 'package:korean_language_app/core/shared/models/audio_display_source.dart';
import 'package:korean_language_app/core/shared/widgets/audio_player.dart';

class CustomCachedAudio extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final audioSource = _determineAudioSource();
    
    switch (audioSource.type) {
      case AudioDisplayType.localFile:
        return _buildLocalAudio(context, audioSource.path!);
      case AudioDisplayType.networkUrl:
        return _buildNetworkAudio(context, audioSource.url!);
      case AudioDisplayType.none:
        return _buildErrorWidget(context, 'No audio available');
    }
  }

  AudioDisplaySource _determineAudioSource() {
    if (audioPath != null && audioPath!.isNotEmpty) {
      final file = File(audioPath!);
      if (file.existsSync()) {
        return AudioDisplaySource(type: AudioDisplayType.localFile, path: audioPath);
      }
    }
    
    if (audioUrl != null && audioUrl!.isNotEmpty) {
      return AudioDisplaySource(type: AudioDisplayType.networkUrl, url: audioUrl);
    }
    
    return AudioDisplaySource(type: AudioDisplayType.none);
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

  Widget _buildErrorWidget(BuildContext context, String message) {
    if (errorWidget != null) {
      return errorWidget!(context, message, null);
    }
    
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3)
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