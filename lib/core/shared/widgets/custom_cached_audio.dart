import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

enum AudioDisplayType { localFile, networkUrl, none }

class AudioDisplaySource {
  final AudioDisplayType type;
  final String? path;
  final String? url;

  AudioDisplaySource({
    required this.type,
    this.path,
    this.url,
  });
}

class CustomCachedAudio extends StatefulWidget {
  final String? audioUrl;
  final String? audioPath;
  final String? label;
  final double height;
  final VoidCallback? onTap;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const CustomCachedAudio({
    super.key,
    this.audioUrl,
    this.audioPath,
    this.label,
    this.height = 60,
    this.onTap,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CustomCachedAudio> createState() => _CustomCachedAudioState();
}

class _CustomCachedAudioState extends State<CustomCachedAudio> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  AudioDisplaySource _determineAudioSource() {
    if (widget.audioPath != null && widget.audioPath!.isNotEmpty) {
      final file = File(widget.audioPath!);
      if (file.existsSync()) {
        return AudioDisplaySource(type: AudioDisplayType.localFile, path: widget.audioPath);
      }
    }
    
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      return AudioDisplaySource(type: AudioDisplayType.networkUrl, url: widget.audioUrl);
    }
    
    return AudioDisplaySource(type: AudioDisplayType.none);
  }

  Future<void> _playPause() async {
    try {
      setState(() {
        _hasError = false;
      });

      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        final audioSource = _determineAudioSource();
        
        if (audioSource.type == AudioDisplayType.none) {
          setState(() {
            _hasError = true;
          });
          return;
        }

        if (_position == Duration.zero) {
          setState(() {
            _isLoading = true;
          });

          try {
            switch (audioSource.type) {
              case AudioDisplayType.localFile:
                await _audioPlayer.play(DeviceFileSource(audioSource.path!));
                break;
              case AudioDisplayType.networkUrl:
                await _audioPlayer.play(UrlSource(audioSource.url!));
                break;
              case AudioDisplayType.none:
                break;
            }
          } catch (e) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            
            if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
              try {
                await _audioPlayer.play(UrlSource(widget.audioUrl!));
              } catch (e2) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error playing audio: $e2')),
                  );
                }
              }
            }
          }
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _seek(double value) async {
    if (_duration.inSeconds > 0) {
      final position = Duration(seconds: (_duration.inSeconds * value).round());
      await _audioPlayer.seek(position);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildErrorWidget(BuildContext context, String error) {
    if (widget.errorWidget != null) {
      return widget.errorWidget!(context, 'audio_error', error);
    }
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Audio unavailable',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    if (widget.placeholder != null) {
      return widget.placeholder!(context, 'loading');
    }
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Loading audio...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioSource = _determineAudioSource();
    
    if (audioSource.type == AudioDisplayType.none || _hasError) {
      return _buildErrorWidget(context, 'No audio available');
    }

    if (_isLoading) {
      return _buildLoadingWidget(context);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _playPause,
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isLoading
                      ? Icons.hourglass_empty
                      : _isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  color: colorScheme.onPrimary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.label != null) ...[
                    Text(
                      widget.label!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _duration.inSeconds > 0
                                ? _position.inSeconds / _duration.inSeconds
                                : 0.0,
                            onChanged: _duration.inSeconds > 0 ? (value) => _seek(value) : null,
                            activeColor: colorScheme.primary,
                            inactiveColor: colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}