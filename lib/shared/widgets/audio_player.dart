import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String? audioUrl;
  final String? audioPath;
  final String? label;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;
  final Function(bool)? onPlayStateChanged;

  const AudioPlayerWidget({
    super.key,
    this.audioUrl,
    this.audioPath,
    this.label,
    this.onRemove,
    this.onEdit,
    this.onPlayStateChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.audioPath != widget.audioPath || 
        oldWidget.audioUrl != widget.audioUrl) {
      _resetPlayer();
    }
  }

  void _resetPlayer() {
    _audioPlayer.stop();
    setState(() {
      _duration = Duration.zero;
      _position = Duration.zero;
      _isPlaying = false;
      _isLoading = false;
    });
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
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
        final wasPlaying = _isPlaying;
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.playing && _duration == Duration.zero;
        });
        
        if (wasPlaying != _isPlaying) {
          widget.onPlayStateChanged?.call(_isPlaying);
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_position == Duration.zero) {
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
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No audio source available')),
              );
            }
          }
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _seek(double value) async {
    final position = Duration(seconds: (_duration.inSeconds * value).round());
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: EdgeInsets.all(theme.spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.spacing.medium),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null || widget.onEdit != null || widget.onRemove != null)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.small),
              child: Row(
                children: [
                  if (widget.label != null)
                    Expanded(
                      child: Text(
                        widget.label!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.onEdit != null)
                    IconButton(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      iconSize: theme.iconSizes.small,
                      visualDensity: VisualDensity.compact,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  if (widget.onRemove != null)
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.close),
                      iconSize: theme.iconSizes.small,
                      visualDensity: VisualDensity.compact,
                      color: colorScheme.error,
                    ),
                ],
              ),
            ),
          
          // Player controls
          Row(
            children: [
              // Play/Pause button
              Container(
                decoration: BoxDecoration(
                  color: _isPlaying ? colorScheme.primary : colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _playPause,
                  icon: Icon(
                    _isLoading
                        ? Icons.hourglass_empty
                        : _isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                    color: _isPlaying ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
                  ),
                  iconSize: theme.iconSizes.medium,
                  padding: EdgeInsets.all(theme.spacing.small),
                ),
              ),
              SizedBox(width: theme.spacing.medium),
              
              // Time and progress bar
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    SizedBox(
                      height: theme.spacing.large,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: theme.spacing.small,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: theme.spacing.medium,
                          ),
                          activeTrackColor: colorScheme.primary,
                          inactiveTrackColor: colorScheme.primaryContainer,
                          thumbColor: colorScheme.primary,
                          overlayColor: colorScheme.primary.withValues(alpha:0.1),
                        ),
                        child: Slider(
                          value: _duration.inSeconds > 0
                              ? _position.inSeconds / _duration.inSeconds
                              : 0.0,
                          onChanged: _duration.inSeconds > 0 ? (value) => _seek(value) : null,
                        ),
                      ),
                    ),
                    
                    // Time labels
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.spacing.small),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension ThemeSpacing on ThemeData {
  Spacing get spacing => Spacing(this);
  IconSizes get iconSizes => IconSizes(this);
}

class Spacing {
  final ThemeData theme;
  
  Spacing(this.theme);
  
  double get small => theme.textTheme.bodySmall?.fontSize ?? 12;
  double get medium => theme.textTheme.bodyMedium?.fontSize ?? 14;
  double get large => theme.textTheme.bodyLarge?.fontSize ?? 16;
}

class IconSizes {
  final ThemeData theme;
  
  IconSizes(this.theme);
  
  double get small => (theme.textTheme.bodySmall?.fontSize ?? 12) * 1.5;
  double get medium => (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.7;
  double get large => (theme.textTheme.bodyLarge?.fontSize ?? 16) * 2;
}