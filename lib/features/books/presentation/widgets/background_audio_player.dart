import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';

class BackgroundAudioPlayer extends StatefulWidget {
  final List<AudioTrack> audioTracks;
  final Widget Function(BackgroundAudioPlayerState) builder;
  final VoidCallback? onTrackChanged;
  final Function(AudioTrack)? onTrackStarted;
  final Function(AudioTrack)? onTrackCompleted;
  final VoidCallback? onPlaylistCompleted;

  const BackgroundAudioPlayer({
    super.key,
    required this.audioTracks,
    required this.builder,
    this.onTrackChanged,
    this.onTrackStarted,
    this.onTrackCompleted,
    this.onPlaylistCompleted,
  });

  @override
  State<BackgroundAudioPlayer> createState() => BackgroundAudioPlayerState();
}

class BackgroundAudioPlayerState extends State<BackgroundAudioPlayer> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  AudioTrack? _currentTrack;
  int _currentTrackIndex = -1;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  bool _showMiniPlayer = false;
  
  List<AudioTrack> get audioTracks => widget.audioTracks;
  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasNextTrack => _currentTrackIndex < audioTracks.length - 1;
  bool get hasPreviousTrack => _currentTrackIndex > 0;
  AudioTrack? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get showMiniPlayer => _showMiniPlayer;
  
  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
  }
  
  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }
  
  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();
    
    _audioPlayer!.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer!.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        final wasPlaying = _isPlaying;
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.playing && _duration == Duration.zero;
          _showMiniPlayer = _isPlaying && _currentTrack != null;
        });
        
        if (_isPlaying && !wasPlaying && _currentTrack != null) {
          widget.onTrackStarted?.call(_currentTrack!);
        }
      }
    });
    
    _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted && _currentTrack != null) {
        widget.onTrackCompleted?.call(_currentTrack!);
        _onTrackCompleted();
      }
    });
  }
  
  void _onTrackCompleted() {
    if (hasNextTrack) {
      playNextTrack();
    } else {
      setState(() {
        _currentTrack = null;
        _currentTrackIndex = -1;
        _isPlaying = false;
        _showMiniPlayer = false;
        _duration = Duration.zero;
        _position = Duration.zero;
      });
      widget.onPlaylistCompleted?.call();
    }
  }
  
  Future<void> playTrack(AudioTrack track) async {
    if (_audioPlayer == null) return;
    
    try {
      final trackIndex = audioTracks.indexWhere((t) => t.id == track.id);
      if (trackIndex == -1) return;
      
      setState(() {
        _currentTrack = track;
        _currentTrackIndex = trackIndex;
        _isLoading = true;
      });
      
      String? source;
      bool isLocalFile = false;
      
      if (track.audioPath != null && track.audioPath!.isNotEmpty) {
        final file = File(track.audioPath!);
        if (await file.exists()) {
          source = track.audioPath!;
          isLocalFile = true;
        }
      }
      
      if (source == null && track.audioUrl != null && track.audioUrl!.isNotEmpty) {
        source = track.audioUrl!;
        isLocalFile = false;
      }
      
      if (source != null) {
        if (isLocalFile) {
          await _audioPlayer!.play(DeviceFileSource(source));
        } else {
          await _audioPlayer!.play(UrlSource(source));
        }
        widget.onTrackChanged?.call();
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }
  
  Future<void> playTrackAtIndex(int index) async {
    if (index >= 0 && index < audioTracks.length) {
      await playTrack(audioTracks[index]);
    }
  }
  
  Future<void> playNextTrack() async {
    if (hasNextTrack) {
      await playTrackAtIndex(_currentTrackIndex + 1);
    }
  }
  
  Future<void> playPreviousTrack() async {
    if (hasPreviousTrack) {
      await playTrackAtIndex(_currentTrackIndex - 1);
    }
  }
  
  Future<void> pauseAudio() async {
    await _audioPlayer?.pause();
  }
  
  Future<void> resumeAudio() async {
    await _audioPlayer?.resume();
  }
  
  Future<void> stopAudio() async {
    await _audioPlayer?.stop();
    setState(() {
      _currentTrack = null;
      _currentTrackIndex = -1;
      _isPlaying = false;
      _showMiniPlayer = false;
      _duration = Duration.zero;
      _position = Duration.zero;
    });
  }
  
  Future<void> seekAudio(double value) async {
    final position = Duration(seconds: (_duration.inSeconds * value).round());
    await _audioPlayer?.seek(position);
  }
  
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.builder(this);
  }
}

class AudioMiniPlayer extends StatelessWidget {
  final BackgroundAudioPlayerState audioState;
  final VoidCallback? onTap;
  final VoidCallback? onInteraction;
  final double opacity;

  const AudioMiniPlayer({
    super.key,
    required this.audioState,
    this.onTap,
    this.onInteraction,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!audioState.showMiniPlayer || audioState.currentTrack == null) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () {
        onTap?.call();
        onInteraction?.call();
      },
      onPanStart: (_) => onInteraction?.call(),
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: audioState.isPlaying ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      audioState.currentTrack!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildControlButton(
                    icon: audioState.hasPreviousTrack ? Icons.skip_previous : Icons.skip_previous,
                    onTap: audioState.hasPreviousTrack ? audioState.playPreviousTrack : null,
                    enabled: audioState.hasPreviousTrack,
                  ),
                  const SizedBox(width: 4),
                  _buildControlButton(
                    icon: audioState.isLoading
                        ? Icons.hourglass_empty
                        : audioState.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                    onTap: () {
                      if (audioState.isPlaying) {
                        audioState.pauseAudio();
                      } else {
                        audioState.resumeAudio();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _buildControlButton(
                    icon: audioState.hasNextTrack ? Icons.skip_next : Icons.skip_next,
                    onTap: audioState.hasNextTrack ? audioState.playNextTrack : null,
                    enabled: audioState.hasNextTrack,
                  ),
                  const SizedBox(width: 4),
                  _buildControlButton(
                    icon: Icons.stop,
                    onTap: audioState.stopAudio,
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    audioState.formatDuration(audioState.position),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: audioState.duration.inSeconds > 0
                            ? audioState.position.inSeconds / audioState.duration.inSeconds
                            : 0.0,
                        onChanged: audioState.duration.inSeconds > 0 ? audioState.seekAudio : null,
                      ),
                    ),
                  ),
                  Text(
                    audioState.formatDuration(audioState.duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: enabled ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
          size: 16,
        ),
      ),
    );
  }
}

class AudioTrackItem extends StatelessWidget {
  final AudioTrack audioTrack;
  final BackgroundAudioPlayerState audioState;
  final VoidCallback? onTap;

  const AudioTrackItem({
    super.key,
    required this.audioTrack,
    required this.audioState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentTrack = audioState.currentTrack?.id == audioTrack.id;
    final isPlaying = isCurrentTrack && audioState.isPlaying;
    
    return Container(
      decoration: BoxDecoration(
        color: isCurrentTrack 
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTrack 
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCurrentTrack 
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isCurrentTrack 
                        ? Icon(
                            audioState.isLoading
                                ? Icons.hourglass_empty
                                : isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '${audioTrack.order}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audioTrack.name,
                        style: TextStyle(
                          color: isCurrentTrack ? Colors.green : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCurrentTrack && audioState.duration.inSeconds > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${audioState.formatDuration(audioState.position)} / ${audioState.formatDuration(audioState.duration)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrentTrack && audioState.hasPreviousTrack) ...[
                      _buildActionButton(
                        icon: Icons.skip_previous,
                        onTap: audioState.playPreviousTrack,
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildActionButton(
                      icon: isCurrentTrack
                          ? (audioState.isLoading
                              ? Icons.hourglass_empty
                              : isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow)
                          : Icons.play_arrow,
                      onTap: () {
                        if (isCurrentTrack) {
                          if (isPlaying) {
                            audioState.pauseAudio();
                          } else {
                            audioState.resumeAudio();
                          }
                        } else {
                          audioState.playTrack(audioTrack);
                        }
                        onTap?.call();
                      },
                      color: isCurrentTrack 
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.3),
                    ),
                    if (isCurrentTrack && audioState.hasNextTrack) ...[
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.skip_next,
                        onTap: audioState.playNextTrack,
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ],
                    if (isCurrentTrack) ...[
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.stop,
                        onTap: audioState.stopAudio,
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (isCurrentTrack && audioState.duration.inSeconds > 0) ...[
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: Colors.green,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  thumbColor: Colors.green,
                  overlayColor: Colors.green.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: audioState.duration.inSeconds > 0
                      ? audioState.position.inSeconds / audioState.duration.inSeconds
                      : 0.0,
                  onChanged: audioState.duration.inSeconds > 0 ? audioState.seekAudio : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}