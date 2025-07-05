import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:korean_language_app/shared/models/book_related/audio_track.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/shared/presentation/snackbar/bloc/snackbar_cubit.dart';
import 'package:korean_language_app/shared/widgets/audio_player.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_session/book_session_cubit.dart';

class PdfReadingPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final String? pdfPath;
  final String? pdfUrl;
  final List<AudioTrack> audioTracks;
  final int totalChapters;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;

  const PdfReadingPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    this.pdfPath,
    this.pdfUrl,
    this.audioTracks = const [],
    required this.totalChapters,
    this.onPreviousChapter,
    this.onNextChapter,
  });

  @override
  State<PdfReadingPage> createState() => _PdfReadingPageState();
}

class _PdfReadingPageState extends State<PdfReadingPage> 
    with TickerProviderStateMixin {
  PdfViewerController? _pdfViewerController;
  bool _isControlsVisible = true;
  bool _isAudioPanelExpanded = false;
  AudioTrack? _currentlyPlayingTrack;
  Timer? _hideControlsTimer;
  int _currentPage = 1;
  int _totalPages = 0;
  
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  late AnimationController _audioPanelAnimationController;
  late Animation<double> _audioPanelAnimation;

  LanguagePreferenceCubit get _languageCubit => context.read<LanguagePreferenceCubit>();
  SnackBarCubit get _snackBarCubit => context.read<SnackBarCubit>();
  BookSessionCubit get _bookSessionCubit => context.read<BookSessionCubit>();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );
    
    _audioPanelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _audioPanelAnimation = CurvedAnimation(
      parent: _audioPanelAnimationController,
      curve: Curves.easeInOut,
    );
    
    _controlsAnimationController.forward();
    _startHideControlsTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bookSessionCubit.startReadingSession(
        widget.bookId,
        widget.bookTitle,
        widget.chapterIndex,
        widget.chapterTitle,
      );
    });
  }

  @override
  void dispose() {
    _bookSessionCubit.updateReadingProgress(
      widget.chapterIndex,
      _currentPage,
      _totalPages,
    );
    _bookSessionCubit.pauseSession();
    
    _pdfViewerController?.dispose();
    _hideControlsTimer?.cancel();
    _controlsAnimationController.dispose();
    _audioPanelAnimationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
    
    if (_isControlsVisible) {
      _controlsAnimationController.forward();
      _startHideControlsTimer();
    } else {
      _controlsAnimationController.reverse();
      _hideControlsTimer?.cancel();
    }
    
    HapticFeedback.lightImpact();
  }

  void _showControls() {
    if (!_isControlsVisible) {
      setState(() {
        _isControlsVisible = true;
      });
      _controlsAnimationController.forward();
    }
    _startHideControlsTimer();
  }

  void _hideControls() {
    if (_isControlsVisible && !_isAudioPanelExpanded) {
      setState(() {
        _isControlsVisible = false;
      });
      _controlsAnimationController.reverse();
      _hideControlsTimer?.cancel();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isAudioPanelExpanded) {
        _hideControls();
      }
    });
  }

  void _toggleAudioPanel() {
    setState(() {
      _isAudioPanelExpanded = !_isAudioPanelExpanded;
    });
    
    if (_isAudioPanelExpanded) {
      _audioPanelAnimationController.forward();
      _showControls();
      _hideControlsTimer?.cancel();
    } else {
      _audioPanelAnimationController.reverse();
      _startHideControlsTimer();
    }
  }

  void _onAudioPlayStateChanged(AudioTrack track, bool isPlaying) {
    setState(() {
      if (isPlaying) {
        _currentlyPlayingTrack = track;
      } else if (_currentlyPlayingTrack?.id == track.id) {
        _currentlyPlayingTrack = null;
      }
    });
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
    
    _bookSessionCubit.updateReadingProgress(
      widget.chapterIndex,
      _currentPage,
      _totalPages,
    );
    
    _showControls();
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
    });

    _bookSessionCubit.loadLastReadPosition(widget.chapterIndex).then((lastPage) {
      if (lastPage > 1 && lastPage <= _totalPages) {
        _pdfViewerController?.jumpToPage(lastPage);
        setState(() {
          _currentPage = lastPage;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pdfPath == null && widget.pdfUrl == null) {
      return _buildNoPdfScreen();
    }

    return _buildReadingScreen();
  }

  Widget _buildNoPdfScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.chapterTitle),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapterTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            
            if (widget.audioTracks.isNotEmpty) ...[
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
              ...widget.audioTracks.map((track) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: AudioPlayerWidget(
                  audioUrl: track.audioUrl,
                  audioPath: track.audioPath,
                  label: track.title,
                  onPlayStateChanged: (isPlaying) => _onAudioPlayStateChanged(track, isPlaying),
                ),
              )),
              const SizedBox(height: 20),
            ],
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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

  Widget _buildReadingScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildPdfViewer(),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _controlsAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -100 * (1 - _controlsAnimation.value)),
                  child: Opacity(
                    opacity: _controlsAnimation.value,
                    child: IgnorePointer(
                      ignoring: !_isControlsVisible,
                      child: _buildTopControls(),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _controlsAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 100 * (1 - _controlsAnimation.value)),
                  child: Opacity(
                    opacity: _controlsAnimation.value,
                    child: IgnorePointer(
                      ignoring: !_isControlsVisible,
                      child: _buildBottomControls(),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (widget.audioTracks.isNotEmpty)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _audioPanelAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -300 * (1 - _audioPanelAnimation.value)),
                    child: Opacity(
                      opacity: _audioPanelAnimation.value,
                      child: IgnorePointer(
                        ignoring: !_isAudioPanelExpanded,
                        child: _buildAudioPanelContent(),
                      ),
                    ),
                  );
                },
              ),
            ),

          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 80,
            child: GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 80,
            child: GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          if (!_isControlsVisible)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _languageCubit.getLocalizedText(
                          korean: '화면 가장자리를 터치하여 조작 버튼 표시',
                          english: 'Tap screen edges to show controls',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    final colorScheme = Theme.of(context).colorScheme;

    String? pdfSource = widget.pdfPath;
    bool isLocalFile = false;

    if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty) {
      final file = File(widget.pdfPath!);
      if (file.existsSync()) {
        pdfSource = widget.pdfPath!;
        isLocalFile = true;
      }
    }

    if (pdfSource == null && widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
      pdfSource = widget.pdfUrl!;
      isLocalFile = false;
    }

    if (pdfSource == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _languageCubit.getLocalizedText(
                korean: 'PDF를 불러올 수 없습니다',
                english: 'Unable to load PDF',
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: colorScheme.surface,
      child: isLocalFile
          ? SfPdfViewer.file(
              File(pdfSource),
              controller: _pdfViewerController,
              canShowScrollStatus: false,
              canShowScrollHead: false,
              canShowPaginationDialog: false,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              scrollDirection: PdfScrollDirection.vertical,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              onDocumentLoaded: _onDocumentLoaded,
              onDocumentLoadFailed: (details) {
                _snackBarCubit.showErrorLocalized(
                  korean: 'PDF를 불러올 수 없습니다',
                  english: 'Failed to load PDF',
                );
              },
              onPageChanged: _onPageChanged,
              onTextSelectionChanged: (details) {
                if (details.selectedText?.isNotEmpty == true) {
                  _showControls();
                }
              },
            )
          : SfPdfViewer.network(
              pdfSource,
              controller: _pdfViewerController,
              canShowScrollStatus: false,
              canShowScrollHead: false,
              canShowPaginationDialog: false,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              scrollDirection: PdfScrollDirection.vertical,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              onDocumentLoaded: _onDocumentLoaded,
              onDocumentLoadFailed: (details) {
                _snackBarCubit.showErrorLocalized(
                  korean: 'PDF를 불러올 수 없습니다',
                  english: 'Failed to load PDF',
                );
              },
              onPageChanged: _onPageChanged,
              onTextSelectionChanged: (details) {
                if (details.selectedText?.isNotEmpty == true) {
                  _showControls();
                }
              },
            ),
    );
  }

  Widget _buildTopControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chapterTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.chapterIndex + 1}/${widget.totalChapters} - ${widget.bookTitle}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_totalPages > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.audioTracks.isNotEmpty)
                IconButton(
                  onPressed: _toggleAudioPanel,
                  icon: Icon(
                    _isAudioPanelExpanded ? Icons.headphones : Icons.headphones_outlined,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: _isAudioPanelExpanded ? colorScheme.primary : Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFirstChapter = widget.chapterIndex == 0;
    final isLastChapter = widget.chapterIndex == widget.totalChapters - 1;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (!isFirstChapter && widget.onPreviousChapter != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onPreviousChapter,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(
                      _languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              
              if (!isFirstChapter && !isLastChapter && widget.onPreviousChapter != null && widget.onNextChapter != null) 
                const SizedBox(width: 12),
              
              if (!isLastChapter && widget.onNextChapter != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onNextChapter,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      _languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isFirstChapter = widget.chapterIndex == 0;
    final isLastChapter = widget.chapterIndex == widget.totalChapters - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirstChapter && widget.onPreviousChapter != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onPreviousChapter,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    _languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (!isLastChapter && widget.onNextChapter != null)
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onNextChapter,
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

  Widget _buildAudioPanelContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.headphones_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _languageCubit.getLocalizedText(
                      korean: '오디오 트랙',
                      english: 'Audio Tracks',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleAudioPanel,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    minimumSize: const Size(32, 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: widget.audioTracks.map((track) {
                  final isPlaying = _currentlyPlayingTrack?.id == track.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isPlaying 
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlaying 
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: AudioPlayerWidget(
                      audioUrl: track.audioUrl,
                      audioPath: track.audioPath,
                      label: track.title,
                      onPlayStateChanged: (isPlaying) => _onAudioPlayStateChanged(track, isPlaying),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}