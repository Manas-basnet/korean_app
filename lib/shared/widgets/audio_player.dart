import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String? audioUrl;
  final String? audioPath; // Should be a resolved/absolute path
  final String? label;
  final double? height;
  final double? minHeight;
  final double? maxHeight;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;
  final bool isCompact;
  final Function(bool)? onPlayStateChanged; // Added callback

  const AudioPlayerWidget({
    super.key,
    this.audioUrl,
    this.audioPath,
    this.label,
    this.height,
    this.minHeight = 40,
    this.maxHeight,
    this.onRemove,
    this.onEdit,
    this.isCompact = false,
    this.onPlayStateChanged, // Added callback
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
  
  // State class variables
  late String? audioUrl;
  late String? audioPath;
  late String? label;
  late double? height;
  late double? minHeight;
  late double? maxHeight;
  late VoidCallback? onRemove;
  late VoidCallback? onEdit;
  late bool isCompact;

  @override
  void initState() {
    super.initState();
    _initializeStateVariables();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldAudioPath = audioPath;
    final oldAudioUrl = audioUrl;
    
    _initializeStateVariables();
    
    if (oldAudioPath != audioPath || oldAudioUrl != audioUrl) {
      _resetPlayer();
    }
  }
  
  void _initializeStateVariables() {
    audioUrl = widget.audioUrl;
    audioPath = widget.audioPath;
    label = widget.label;
    height = widget.height;
    minHeight = widget.minHeight;
    maxHeight = widget.maxHeight;
    onRemove = widget.onRemove;
    onEdit = widget.onEdit;
    isCompact = widget.isCompact;
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
        
        // Call the callback when play state changes
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
          
          if (audioPath != null && audioPath!.isNotEmpty) {
            final file = File(audioPath!);
            if (await file.exists()) {
              source = audioPath!;
              isLocalFile = true;
            }
          }
          
          if (source == null && audioUrl != null && audioUrl!.isNotEmpty) {
            source = audioUrl!;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;
        
        final shouldUseCompactLayout = isCompact || 
            availableHeight < 50 || 
            availableWidth < 200;

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: minHeight ?? (shouldUseCompactLayout ? 35 : 40),
            maxHeight: maxHeight ?? 
                (height ?? (shouldUseCompactLayout ? 45 : 60)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: shouldUseCompactLayout ? 8 : 12,
            vertical: shouldUseCompactLayout ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues( alpha: 0.3),
            borderRadius: BorderRadius.circular(shouldUseCompactLayout ? 6 : 8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha : 0.3),
              width: 0.5,
            ),
          ),
          child: shouldUseCompactLayout 
              ? _buildCompactLayout(theme, colorScheme)
              : _buildNormalLayout(theme, colorScheme),
        );
      },
    );
  }

  Widget _buildCompactLayout(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        _buildPlayButton(colorScheme, size: 24),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Flexible(
                  child: Text(
                    label!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 8,
                      ),
                    ),
                    Expanded(
                      child: _buildSlider(colorScheme, height: 2),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null || onRemove != null) ...[
          const SizedBox(width: 4),
          _buildActionButtons(colorScheme, isCompact: true),
        ],
      ],
    );
  }

  Widget _buildNormalLayout(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        _buildPlayButton(colorScheme),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                Flexible(
                  child: Text(
                    label!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Flexible(
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    Expanded(
                      child: _buildSlider(colorScheme),
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
              ),
            ],
          ),
        ),
        if (onEdit != null || onRemove != null) ...[
          const SizedBox(width: 4),
          _buildActionButtons(colorScheme),
        ],
      ],
    );
  }

  Widget _buildPlayButton(ColorScheme colorScheme, {double size = 36}) {
    return Container(
      width: size,
      height: size,
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
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildSlider(ColorScheme colorScheme, {double height = 2}) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: height,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: height + 2,
        ),
        overlayShape: RoundSliderOverlayShape(
          overlayRadius: (height + 2) * 2,
        ),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.outline.withValues(alpha : 0.3),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha : 0.1),
      ),
      child: Slider(
        value: _duration.inSeconds > 0
            ? _position.inSeconds / _duration.inSeconds
            : 0.0,
        onChanged: _duration.inSeconds > 0 ? (value) => _seek(value) : null,
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, {bool isCompact = false}) {
    final buttonSize = isCompact ? 20.0 : 24.0;
    final iconSize = isCompact ? 12.0 : 16.0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit, size: iconSize),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        if (onEdit != null && onRemove != null)
          SizedBox(width: isCompact ? 2 : 4),
        if (onRemove != null)
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: iconSize),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.error,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}