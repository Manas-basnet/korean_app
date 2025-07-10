import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String? audioUrl;
  final String? audioPath;
  final String? label;
  final double? height;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;
  final Function(bool)? onPlayStateChanged;

  const AudioPlayerWidget({
    super.key,
    this.audioUrl,
    this.audioPath,
    this.label,
    this.height,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;
    final effectiveHeight = widget.height ?? (isTablet ? 60 : 50);
    
    return Container(
      height: effectiveHeight,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Play/Pause button
          Container(
            width: effectiveHeight * 0.6,
            height: effectiveHeight * 0.6,
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
                size: (effectiveHeight * 0.35).clamp(16.0, 24.0),
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: effectiveHeight * 0.6,
                minHeight: effectiveHeight * 0.6,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Progress and controls
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Label (if provided and there's space)
                if (widget.label != null && effectiveHeight > 45) ...[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                          fontSize: isTablet ? 14 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 4 : 2),
                ],
                
                // Progress bar and time
                Expanded(
                  child: Row(
                    children: [
                      // Current time
                      Text(
                        _formatDuration(_position),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isTablet ? 12 : 10,
                        ),
                      ),
                      
                      SizedBox(width: isTablet ? 8 : 6),
                      
                      // Progress bar
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: isTablet ? 4 : 3,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: isTablet ? 8 : 6,
                            ),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: isTablet ? 14 : 12,
                            ),
                            activeTrackColor: colorScheme.primary,
                            inactiveTrackColor: colorScheme.primaryContainer,
                            thumbColor: colorScheme.primary,
                            overlayColor: colorScheme.primary.withOpacity(0.1),
                          ),
                          child: Slider(
                            value: _duration.inSeconds > 0
                                ? _position.inSeconds / _duration.inSeconds
                                : 0.0,
                            onChanged: _duration.inSeconds > 0 ? (value) => _seek(value) : null,
                          ),
                        ),
                      ),
                      
                      SizedBox(width: isTablet ? 8 : 6),
                      
                      // Total duration
                      Text(
                        _formatDuration(_duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isTablet ? 12 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons (if provided)
          if (widget.onEdit != null || widget.onRemove != null) ...[
            SizedBox(width: isTablet ? 8 : 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onEdit != null)
                  IconButton(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    iconSize: isTablet ? 18 : 16,
                    color: colorScheme.onSurfaceVariant,
                    padding: EdgeInsets.all(isTablet ? 4 : 2),
                    constraints: BoxConstraints(
                      minWidth: effectiveHeight * 0.4,
                      minHeight: effectiveHeight * 0.4,
                    ),
                  ),
                if (widget.onRemove != null)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close),
                    iconSize: isTablet ? 18 : 16,
                    color: colorScheme.error,
                    padding: EdgeInsets.all(isTablet ? 4 : 2),
                    constraints: BoxConstraints(
                      minWidth: effectiveHeight * 0.4,
                      minHeight: effectiveHeight * 0.4,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}