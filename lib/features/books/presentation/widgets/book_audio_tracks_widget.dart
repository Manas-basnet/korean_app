import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/features/books/presentation/bloc/korean_books/korean_books_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';

class BookAudioTracksWidget extends StatefulWidget {
  final BookItem book;
  final bool isCompact;
  final bool showPreloadButton;

  const BookAudioTracksWidget({
    super.key,
    required this.book,
    this.isCompact = false,
    this.showPreloadButton = true,
  });

  @override
  State<BookAudioTracksWidget> createState() => _BookAudioTracksWidgetState();
}

class _BookAudioTracksWidgetState extends State<BookAudioTracksWidget> {
  final Map<String, File?> _loadedAudioFiles = {};
  final Set<String> _loadingTracks = {};

  KoreanBooksCubit get _koreanBooksCubit => context.read<KoreanBooksCubit>();
  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();

  @override
  Widget build(BuildContext context) {
    if (widget.book.audioTracks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<KoreanBooksCubit, KoreanBooksState>(
      listener: (context, state) {
        _handleAudioTrackLoadingState(state);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: widget.isCompact ? 16 : 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _languageCubit.getLocalizedText(
                      korean: '오디오 트랙 (${widget.book.audioTracks.length})',
                      english: 'Audio Tracks (${widget.book.audioTracks.length})',
                    ),
                    style: widget.isCompact 
                        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                        : theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.showPreloadButton && !widget.isCompact)
                  _buildPreloadButton(colorScheme),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.book.audioTracks.map((audioTrack) => 
              _buildAudioTrackItem(audioTrack, theme, colorScheme)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreloadButton(ColorScheme colorScheme) {
    return TextButton.icon(
      onPressed: () => _preloadAllTracks(),
      icon: Icon(
        Icons.download,
        size: 16,
        color: colorScheme.primary,
      ),
      label: Text(
        _languageCubit.getLocalizedText(
          korean: '모두 다운로드',
          english: 'Download All',
        ),
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.primary,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildAudioTrackItem(AudioTrack audioTrack, ThemeData theme, ColorScheme colorScheme) {
    final isLoading = _loadingTracks.contains(audioTrack.id);
    final loadedFile = _loadedAudioFiles[audioTrack.id];
    final hasAudio = loadedFile != null || (audioTrack.audioPath != null && audioTrack.audioPath!.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: hasAudio && !isLoading
          ? AudioPlayerWidget(
              audioUrl: audioTrack.audioUrl,
              audioPath: loadedFile?.path ?? audioTrack.audioPath,
              label: audioTrack.name,
              isCompact: widget.isCompact,
              minHeight: widget.isCompact ? 35 : 40,
              maxHeight: widget.isCompact ? 45 : 60,
            )
          : _buildAudioTrackPlaceholder(audioTrack, isLoading, theme, colorScheme),
    );
  }

  Widget _buildAudioTrackPlaceholder(
    AudioTrack audioTrack, 
    bool isLoading, 
    ThemeData theme, 
    ColorScheme colorScheme
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 8 : 12,
        vertical: widget.isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(widget.isCompact ? 6 : 8),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: widget.isCompact ? 24 : 36,
            height: widget.isCompact ? 24 : 36,
            decoration: BoxDecoration(
              color: isLoading 
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.outline.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? SizedBox(
                    width: widget.isCompact ? 12 : 16,
                    height: widget.isCompact ? 12 : 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  )
                : Icon(
                    Icons.download_outlined,
                    color: colorScheme.primary,
                    size: widget.isCompact ? 12 : 16,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  audioTrack.name,
                  style: widget.isCompact
                      ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)
                      : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!widget.isCompact)
                  Text(
                    isLoading
                        ? _languageCubit.getLocalizedText(
                            korean: '다운로드 중...',
                            english: 'Downloading...',
                          )
                        : _languageCubit.getLocalizedText(
                            korean: '재생하려면 탭하세요',
                            english: 'Tap to download and play',
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (!isLoading)
            IconButton(
              onPressed: () => _loadAudioTrack(audioTrack.id),
              icon: Icon(
                Icons.play_circle_outline,
                color: colorScheme.primary,
              ),
              iconSize: widget.isCompact ? 20 : 24,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: widget.isCompact ? 24 : 32,
                minHeight: widget.isCompact ? 24 : 32,
              ),
            ),
        ],
      ),
    );
  }

  void _handleAudioTrackLoadingState(KoreanBooksState state) {
    final operation = state.currentOperation;

    if (operation.type == KoreanBooksOperationType.loadAudioTrack) {
      final trackId = operation.bookId;

      if (operation.status == KoreanBooksOperationStatus.inProgress) {
        if (mounted) {
          setState(() {
            _loadingTracks.add(trackId ?? '');
          });
        }
      } else if (operation.status == KoreanBooksOperationStatus.completed &&
                 state.loadedAudioFile != null &&
                 state.loadedAudioBookId == widget.book.id &&
                 state.loadedAudioChapterId == null) {
        if (mounted) {
          setState(() {
            _loadingTracks.remove(trackId);
            if (state.loadedAudioTrackId != null) {
              _loadedAudioFiles[state.loadedAudioTrackId!] = state.loadedAudioFile;
            }
          });
        }
      } else if (operation.status == KoreanBooksOperationStatus.failed) {
        if (mounted) {
          setState(() {
            _loadingTracks.remove(trackId);
          });
        }
        
        _snackBarCubit.showErrorLocalized(
          korean: '오디오 트랙 로드에 실패했습니다',
          english: 'Failed to load audio track',
        );
      }
    }

    if (operation.type == KoreanBooksOperationType.preloadAudioTracks &&
        operation.bookId == widget.book.id) {
      if (operation.status == KoreanBooksOperationStatus.completed) {
        _snackBarCubit.showSuccessLocalized(
          korean: '모든 오디오 트랙이 다운로드되었습니다',
          english: 'All audio tracks downloaded successfully',
        );
      } else if (operation.status == KoreanBooksOperationStatus.failed) {
        _snackBarCubit.showErrorLocalized(
          korean: '오디오 트랙 다운로드에 실패했습니다',
          english: 'Failed to download audio tracks',
        );
      }
    }
  }

  void _loadAudioTrack(String audioTrackId) {
    _koreanBooksCubit.loadBookAudioTrack(widget.book.id, audioTrackId);
  }

  void _preloadAllTracks() {
    _koreanBooksCubit.preloadBookAudioTracks(widget.book.id);
  }
}