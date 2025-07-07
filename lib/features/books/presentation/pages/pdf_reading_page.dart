import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/books/presentation/widgets/audio_tracks.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:korean_language_app/core/routes/app_router.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/book_related/book_chapter.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';

class PdfReadingPage extends StatefulWidget {
  final BookItem bookItem;
  final int chapterIndex;

  const PdfReadingPage({
    super.key,
    required this.bookItem,
    required this.chapterIndex,
  });

  @override
  State<PdfReadingPage> createState() => _PdfReadingPageState();
}

class _PdfReadingPageState extends State<PdfReadingPage>
    with TickerProviderStateMixin {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isOverlayVisible = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  double _currentZoom = 1.0;
  int _currentPage = 1;
  int _totalPages = 0;
  AudioTrack? _currentlyPlayingTrack;

  BookChapter get currentChapter => widget.bookItem.chapters[widget.chapterIndex];
  String get bookId => widget.bookItem.id;
  String get bookTitle => widget.bookItem.title;
  String get chapterTitle => currentChapter.title;
  String? get pdfPath => currentChapter.pdfPath;
  String? get pdfUrl => currentChapter.pdfUrl;
  List<AudioTrack> get audioTracks => currentChapter.audioTracks;
  int get totalChapters => widget.bookItem.chapters.length;
  bool get isFirstChapter => widget.chapterIndex == 0;
  bool get isLastChapter => widget.chapterIndex == totalChapters - 1;

  late LanguagePreferenceCubit _languageCubit;
  late SnackBarCubit _snackBarCubit;
  late BookSessionCubit _bookSessionCubit;

  @override
  void initState() {
    super.initState();

    _languageCubit = context.read<LanguagePreferenceCubit>();
    _snackBarCubit = context.read<SnackBarCubit>();
    _bookSessionCubit = context.read<BookSessionCubit>();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  void _initializeSession() {
    _bookSessionCubit.startReadingSession(
      bookId,
      bookTitle,
      widget.chapterIndex,
      chapterTitle,
      bookItem: widget.bookItem,
    );
  }

  @override
  void deactivate() {
    _bookSessionCubit.updateReadingProgress(
      widget.chapterIndex,
      _currentPage,
      _totalPages,
    );
    _bookSessionCubit.pauseSession();
    super.deactivate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
    if (_isOverlayVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 0.5).clamp(0.5, 3.0);
    _pdfViewerController.zoomLevel = _currentZoom;
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 0.5).clamp(0.5, 3.0);
    _pdfViewerController.zoomLevel = _currentZoom;
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pdfViewerController.jumpToPage(page);
    }
  }

  void _navigateToPreviousChapter() {
    if (!isFirstChapter) {
      context.pushReplacement(
        Routes.bookChapterReading(bookId, widget.chapterIndex - 1), 
        extra: widget.bookItem,
      );
    }
  }

  void _navigateToNextChapter() {
    if (!isLastChapter) {
      context.pushReplacement(
        Routes.bookChapterReading(bookId, widget.chapterIndex + 1), 
        extra: widget.bookItem,
      );
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    if (_isOverlayVisible) {
      _toggleOverlay();
    }
    setState(() {
      _currentPage = details.newPageNumber;
    });
    
    _bookSessionCubit.updateReadingProgress(
      widget.chapterIndex,
      _currentPage,
      _totalPages,
    );
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
    });

    _bookSessionCubit.loadLastReadPosition(widget.chapterIndex).then((lastPage) {
      if (lastPage > 1 && lastPage <= _totalPages) {
        _pdfViewerController.jumpToPage(lastPage);
        setState(() {
          _currentPage = lastPage;
        });
      }
    });
  }

  Widget? _getPdfViewer() {
    if (pdfPath != null && File(pdfPath!).existsSync()) {
      return SfPdfViewer.file(
        File(pdfPath!),
        controller: _pdfViewerController,
        onTap: (PdfGestureDetails details) {
          _toggleOverlay();
        },
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onDocumentLoaded,
        onDocumentLoadFailed: (details) {
          _snackBarCubit.showErrorLocalized(
            korean: 'PDF를 불러올 수 없습니다',
            english: 'Failed to load PDF',
          );
        },
        onZoomLevelChanged: (PdfZoomDetails details) {
          setState(() {
            _currentZoom = details.newZoomLevel;
          });
        },
        interactionMode: PdfInteractionMode.pan,
      );
    } else if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      return SfPdfViewer.network(
        pdfUrl!,
        controller: _pdfViewerController,
        onTap: (PdfGestureDetails details) {
          _toggleOverlay();
        },
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onDocumentLoaded,
        onDocumentLoadFailed: (details) {
          _snackBarCubit.showErrorLocalized(
            korean: 'PDF를 불러올 수 없습니다',
            english: 'Failed to load PDF',
          );
        },
        onZoomLevelChanged: (PdfZoomDetails details) {
          setState(() {
            _currentZoom = details.newZoomLevel;
          });
        },
        interactionMode: PdfInteractionMode.pan,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pdfViewer = _getPdfViewer();
    
    if (pdfViewer == null) {
      return _buildNoPdfScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          pdfViewer,

          // Persistent audio overlay (always visible when audio is playing)
          if (_currentlyPlayingTrack != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildPersistentAudioOverlay(),
            ),

          // Top overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _isOverlayVisible ? _fadeAnimation.value : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isOverlayVisible,
                    child: Container(
                      height: MediaQuery.of(context).padding.top + 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha:0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const Spacer(),
                            Text(
                              '$_currentPage / $_totalPages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (audioTracks.isNotEmpty)
                              IconButton(
                                onPressed: () => _showAudioTracksDialog(context),
                                icon: const Icon(Icons.headphones, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _isOverlayVisible ? _fadeAnimation.value : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isOverlayVisible,
                    child: Container(
                      height: 80 + MediaQuery.of(context).padding.bottom,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha:0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: _zoomOut,
                              icon: const Icon(Icons.zoom_out, color: Colors.white),
                            ),
                            IconButton(
                              onPressed: _zoomIn,
                              icon: const Icon(Icons.zoom_in, color: Colors.white),
                            ),
                            if (!isFirstChapter)
                              IconButton(
                                onPressed: _navigateToPreviousChapter,
                                icon: const Icon(Icons.skip_previous, color: Colors.white),
                                tooltip: _languageCubit.getLocalizedText(
                                  korean: '이전 챕터',
                                  english: 'Previous Chapter',
                                ),
                              ),
                            if (!isLastChapter)
                              IconButton(
                                onPressed: _navigateToNextChapter,
                                icon: const Icon(Icons.skip_next, color: Colors.white),
                                tooltip: _languageCubit.getLocalizedText(
                                  korean: '다음 챕터',
                                  english: 'Next Chapter',
                                ),
                              ),
                            IconButton(
                              onPressed: () => _showPageNavigator(context),
                              icon: const Icon(Icons.list, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPdfScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(chapterTitle),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapterTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            
            if (audioTracks.isNotEmpty) ...[
              Text(
                _languageCubit.getLocalizedText(
                  korean: '오디오 트랙',
                  english: 'Audio Tracks',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              AudioTracksWidget(
                audioTracks: audioTracks,
                languageCubit: _languageCubit,
                currentlyPlayingTrack: _currentlyPlayingTrack,
                onPlayStateChanged: (track, isPlaying) {
                  setState(() {
                    if (isPlaying) {
                      _currentlyPlayingTrack = track;
                    } else if (_currentlyPlayingTrack?.id == track.id) {
                      _currentlyPlayingTrack = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
            ],
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _languageCubit.getLocalizedText(
                        korean: '이 챕터에는 PDF 콘텐츠가 없습니다.',
                        english: 'This chapter does not contain PDF content.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha:0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirstChapter) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _navigateToPreviousChapter,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    _languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (!isLastChapter)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _navigateToNextChapter,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    _languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentAudioOverlay() {
    return GestureDetector(
      onTap: () => _showAudioTracksDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _currentlyPlayingTrack?.title ?? 
                _languageCubit.getLocalizedText(
                  korean: '재생 중',
                  english: 'Playing',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha:0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPageNavigator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(_languageCubit.getLocalizedText(
              korean: '페이지로 이동',
              english: 'Go to Page',
            )),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _languageCubit.getLocalizedText(
                      korean: '페이지 번호 (1-$_totalPages)',
                      english: 'Page number (1-$_totalPages)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    int? page = int.tryParse(value);
                    if (page != null) {
                      _goToPage(page);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: _totalPages.toDouble(),
                  divisions: _totalPages - 1,
                  label: _currentPage.toString(),
                  onChanged: (value) {
                    int newPage = value.round();
                    _goToPage(newPage);
                    setDialogState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_languageCubit.getLocalizedText(
                  korean: '닫기',
                  english: 'Close',
                )),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAudioTracksDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _languageCubit.getLocalizedText(
                          korean: '오디오 트랙',
                          english: 'Audio Tracks',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AudioTracksWidget(
                    audioTracks: audioTracks,
                    languageCubit: _languageCubit,
                    scrollController: scrollController,
                    currentlyPlayingTrack: _currentlyPlayingTrack,
                    onPlayStateChanged: (track, isPlaying) {
                      setState(() {
                        if (isPlaying) {
                          _currentlyPlayingTrack = track;
                        } else if (_currentlyPlayingTrack?.id == track.id) {
                          _currentlyPlayingTrack = null;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}