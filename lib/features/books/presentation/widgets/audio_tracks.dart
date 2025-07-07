import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';

class AudioTracksWidget extends StatefulWidget {
  final List<AudioTrack> audioTracks;
  final LanguagePreferenceCubit languageCubit;
  final ScrollController? scrollController;
  final AudioTrack? currentlyPlayingTrack;
  final Function(AudioTrack track, bool isPlaying)? onPlayStateChanged;

  const AudioTracksWidget({
    super.key,
    required this.audioTracks,
    required this.languageCubit,
    this.scrollController,
    this.currentlyPlayingTrack,
    this.onPlayStateChanged,
  });

  @override
  State<AudioTracksWidget> createState() => _AudioTracksWidgetState();
}

class _AudioTracksWidgetState extends State<AudioTracksWidget> {
  void _onAudioPlayStateChanged(AudioTrack track, bool isPlaying) {
    widget.onPlayStateChanged?.call(track, isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.audioTracks.length,
      itemBuilder: (context, index) {
        final track = widget.audioTracks[index];
        final isPlaying = widget.currentlyPlayingTrack?.id == track.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isPlaying 
                ? colorScheme.primaryContainer.withValues(alpha:0.3)
                : colorScheme.surfaceContainerHighest.withValues(alpha:0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPlaying 
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outline.withValues(alpha:0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.audioTracks.length > 1)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPlaying 
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isPlaying 
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          track.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                            color: isPlaying 
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPlaying)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha:0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.volume_up_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              AudioPlayerWidget(
                audioUrl: track.audioUrl,
                audioPath: track.audioPath,
                label: widget.audioTracks.length == 1 ? track.title : null,
                onPlayStateChanged: (isPlaying) => _onAudioPlayStateChanged(track, isPlaying),
              ),
            ],
          ),
        );
      },
    );
  }
}