import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleAudioPlayer extends StatefulWidget {
  final String? audioUrl;
  final String? audioPath;
  final Widget child;

  const SimpleAudioPlayer({
    super.key,
    this.audioUrl,
    this.audioPath,
    required this.child,
  });

  @override
  State<SimpleAudioPlayer> createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        return;
      }

      String? source;
      bool isLocalFile = false;
      
      if (widget.audioPath != null && widget.audioPath!.isNotEmpty) {
        final file = File(widget.audioPath!);
        if (await file.exists()) {
          source = widget.audioPath!;
          isLocalFile = true;
        }
      }
      
      if (source == null && widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
        source = widget.audioUrl!;
        isLocalFile = false;
      }
      
      if (source != null) {
        if (isLocalFile) {
          await _audioPlayer.play(DeviceFileSource(source));
        } else {
          await _audioPlayer.play(UrlSource(source));
        }
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) ||
                     (widget.audioPath != null && widget.audioPath!.isNotEmpty);

    if (!hasAudio) {
      return widget.child;
    }

    return GestureDetector(
      onTap: _playAudio,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isPlaying ? Icons.stop : Icons.volume_up,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}