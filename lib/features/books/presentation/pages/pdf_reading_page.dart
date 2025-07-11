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
import 'package:korean_language_app/features/books/presentation/bloc/books_cubit.dart';

class PdfReadingPage extends StatefulWidget {
  final String bookId;
  final int chapterIndex;

  const PdfReadingPage({
    super.key,
    required this.bookId,
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
  
  Widget? _cachedPdfViewer;
  BookItem? _currentBookItem;
  bool _isLoadingBook = true;
  bool _hasError = false;
  String? _errorMessage;

  BookChapter? get currentChapter => _currentBookItem != null && 
      widget.chapterIndex < _currentBookItem!.chapters.length 
      ? _currentBookItem!.chapters[widget.chapterIndex] 
      : null;
  String get bookTitle => _currentBookItem?.title ?? '';
  String get chapterTitle => currentChapter?.title ?? '';
  String? get pdfPath => currentChapter?.pdfPath;
  String? get pdfUrl => currentChapter?.pdfUrl;
  List<AudioTrack> get audioTracks => currentChapter?.audioTracks ?? [];
  int get totalChapters => _currentBookItem?.chapters.length ?? 0;
  bool get isFirstChapter => widget.chapterIndex == 0;
  bool get isLastChapter => widget.chapterIndex == totalChapters - 1;

  late LanguagePreferenceCubit _languageCubit;
  late SnackBarCubit _snackBarCubit;
  late BookSessionCubit _bookSessionCubit;
  late BooksCubit _booksCubit;

  @override
  void initState() {
    super.initState();

    _languageCubit = context.read<LanguagePreferenceCubit>();
    _snackBarCubit = context.read<SnackBarCubit>();
    _bookSessionCubit = context.read<BookSessionCubit>();
    _booksCubit = context.read<BooksCubit>();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookAndCheckCachedPaths();
    });
  }

  Future<void> _loadBookAndCheckCachedPaths() async {
    try {
      setState(() {
        _isLoadingBook = true;
        _hasError = false;
        _errorMessage = null;
      });

      final booksState = _booksCubit.state;
      BookItem? book;

      if (booksState.selectedBook?.id == widget.bookId) {
        book = booksState.selectedBook;
      } else {
        await _booksCubit.loadBookById(widget.bookId);
        final updatedState = _booksCubit.state;
        
        if (updatedState.hasError || updatedState.selectedBook == null) {
          setState(() {
            _hasError = true;
            _errorMessage = updatedState.error ?? _languageCubit.getLocalizedText(
              korean: '도서를 불러올 수 없습니다',
              english: 'Failed to load book',
            );
            _isLoadingBook = false;
          });
          return;
        }
        book = updatedState.selectedBook;
      }

      if (book == null) {
        setState(() {
          _hasError = true;
          _errorMessage = _languageCubit.getLocalizedText(
            korean: '도서를 찾을 수 없습니다',
            english: 'Book not found',
          );
          _isLoadingBook = false;
        });
        return;
      }

      if (widget.chapterIndex >= book.chapters.length) {
        setState(() {
          _hasError = true;
          _errorMessage = _languageCubit.getLocalizedText(
            korean: '챕터를 찾을 수 없습니다',
            english: 'Chapter not found',
          );
          _isLoadingBook = false;
        });
        return;
      }

      final processedBook = await _booksCubit.getBookWithCachedPaths(book);

      setState(() {
        _currentBookItem = processedBook;
        _isLoadingBook = false;
      });

      _initializePdfViewer();
      _initializeSession();

    } catch (e) {
      debugPrint('Error loading book and checking cached paths: $e');
      setState(() {
        _hasError = true;
        _errorMessage = _languageCubit.getLocalizedText(
          korean: '오류가 발생했습니다: $e',
          english: 'An error occurred: $e',
        );
        _isLoadingBook = false;
      });
    }
  }

  void _initializePdfViewer() {
    if (currentChapter == null) return;

    if (pdfPath != null && File(pdfPath!).existsSync()) {
      _cachedPdfViewer = SfPdfViewer.file(
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
      _cachedPdfViewer = SfPdfViewer.network(
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
  }

  void _initializeSession() {
    if (_currentBookItem == null) return;

    _bookSessionCubit.startReadingSession(
      widget.bookId,
      bookTitle,
      widget.chapterIndex,
      chapterTitle,
      bookItem: _currentBookItem,
    );
  }

  @override
  void deactivate() {
    if (!_isLoadingBook && !_hasError) {
      _bookSessionCubit.updateReadingProgress(
        widget.chapterIndex,
        _currentPage,
        _totalPages,
      );
      _bookSessionCubit.pauseSession();
    }
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
        Routes.bookChapterReading(widget.bookId, widget.chapterIndex - 1),
      );
    }
  }

  void _navigateToNextChapter() {
    if (!isLastChapter) {
      context.pushReplacement(
        Routes.bookChapterReading(widget.bookId, widget.chapterIndex + 1),
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

  void _showPageNavigator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PageNavigatorDialog(
        currentPage: _currentPage,
        totalPages: _totalPages,
        languageCubit: _languageCubit,
        onPageSelected: _goToPage,
      ),
    );
  }

  void _showAudioTracksDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AudioTracksBottomSheet(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBook) {
      return _LoadingScreen(
        languageCubit: _languageCubit,
      );
    }

    if (_hasError) {
      return _ErrorScreen(
        languageCubit: _languageCubit,
        errorMessage: _errorMessage ?? 'Unknown error',
        onRetry: _loadBookAndCheckCachedPaths,
      );
    }

    if (_cachedPdfViewer == null) {
      return _NoPdfScreen(
        chapterTitle: chapterTitle,
        audioTracks: audioTracks,
        languageCubit: _languageCubit,
        currentlyPlayingTrack: _currentlyPlayingTrack,
        isFirstChapter: isFirstChapter,
        isLastChapter: isLastChapter,
        onPlayStateChanged: (track, isPlaying) {
          setState(() {
            if (isPlaying) {
              _currentlyPlayingTrack = track;
            } else if (_currentlyPlayingTrack?.id == track.id) {
              _currentlyPlayingTrack = null;
            }
          });
        },
        onNavigateToPrevious: _navigateToPreviousChapter,
        onNavigateToNext: _navigateToNextChapter,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _cachedPdfViewer!,

          if (_currentlyPlayingTrack != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _PersistentAudioOverlay(
                currentlyPlayingTrack: _currentlyPlayingTrack!,
                languageCubit: _languageCubit,
                onTap: () => _showAudioTracksDialog(context),
              ),
            ),

          _TopOverlay(
            isVisible: _isOverlayVisible,
            fadeAnimation: _fadeAnimation,
            currentPage: _currentPage,
            totalPages: _totalPages,
            hasAudioTracks: audioTracks.isNotEmpty,
            onBack: () => Navigator.of(context).pop(),
            onAudioTracks: () => _showAudioTracksDialog(context),
          ),

          _BottomOverlay(
            isVisible: _isOverlayVisible,
            fadeAnimation: _fadeAnimation,
            isFirstChapter: isFirstChapter,
            isLastChapter: isLastChapter,
            languageCubit: _languageCubit,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onNavigateToPrevious: _navigateToPreviousChapter,
            onNavigateToNext: _navigateToNextChapter,
            onPageNavigator: () => _showPageNavigator(context),
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final LanguagePreferenceCubit languageCubit;

  const _LoadingScreen({
    required this.languageCubit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              languageCubit.getLocalizedText(
                korean: '챕터를 준비하고 있습니다...',
                english: 'Preparing chapter...',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final LanguagePreferenceCubit languageCubit;
  final String errorMessage;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.languageCubit,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                languageCubit.getLocalizedText(
                  korean: '오류 발생',
                  english: 'Error Occurred',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      languageCubit.getLocalizedText(
                        korean: '돌아가기',
                        english: 'Go Back',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      languageCubit.getLocalizedText(
                        korean: '다시 시도',
                        english: 'Retry',
                      ),
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
}

class _TopOverlay extends StatelessWidget {
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final int currentPage;
  final int totalPages;
  final bool hasAudioTracks;
  final VoidCallback onBack;
  final VoidCallback onAudioTracks;

  const _TopOverlay({
    required this.isVisible,
    required this.fadeAnimation,
    required this.currentPage,
    required this.totalPages,
    required this.hasAudioTracks,
    required this.onBack,
    required this.onAudioTracks,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: isVisible ? fadeAnimation.value : 0.0,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: Container(
                height: MediaQuery.of(context).padding.top + 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        '$currentPage / $totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (hasAudioTracks)
                        IconButton(
                          onPressed: onAudioTracks,
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
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  final bool isVisible;
  final Animation<double> fadeAnimation;
  final bool isFirstChapter;
  final bool isLastChapter;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onNavigateToPrevious;
  final VoidCallback onNavigateToNext;
  final VoidCallback onPageNavigator;

  const _BottomOverlay({
    required this.isVisible,
    required this.fadeAnimation,
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.languageCubit,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onNavigateToPrevious,
    required this.onNavigateToNext,
    required this.onPageNavigator,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: isVisible ? fadeAnimation.value : 0.0,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: Container(
                height: 80 + MediaQuery.of(context).padding.bottom,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: onZoomOut,
                        icon: const Icon(Icons.zoom_out, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: onZoomIn,
                        icon: const Icon(Icons.zoom_in, color: Colors.white),
                      ),
                      if (!isFirstChapter)
                        IconButton(
                          onPressed: onNavigateToPrevious,
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          tooltip: languageCubit.getLocalizedText(
                            korean: '이전 챕터',
                            english: 'Previous Chapter',
                          ),
                        ),
                      if (!isLastChapter)
                        IconButton(
                          onPressed: onNavigateToNext,
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          tooltip: languageCubit.getLocalizedText(
                            korean: '다음 챕터',
                            english: 'Next Chapter',
                          ),
                        ),
                      IconButton(
                        onPressed: onPageNavigator,
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
    );
  }
}

class _PersistentAudioOverlay extends StatelessWidget {
  final AudioTrack currentlyPlayingTrack;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onTap;

  const _PersistentAudioOverlay({
    required this.currentlyPlayingTrack,
    required this.languageCubit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
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
                currentlyPlayingTrack.title,
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
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
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
}

class _NoPdfScreen extends StatelessWidget {
  final String chapterTitle;
  final List<AudioTrack> audioTracks;
  final LanguagePreferenceCubit languageCubit;
  final AudioTrack? currentlyPlayingTrack;
  final bool isFirstChapter;
  final bool isLastChapter;
  final Function(AudioTrack, bool) onPlayStateChanged;
  final VoidCallback onNavigateToPrevious;
  final VoidCallback onNavigateToNext;

  const _NoPdfScreen({
    required this.chapterTitle,
    required this.audioTracks,
    required this.languageCubit,
    required this.currentlyPlayingTrack,
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.onPlayStateChanged,
    required this.onNavigateToPrevious,
    required this.onNavigateToNext,
  });

  @override
  Widget build(BuildContext context) {
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
                languageCubit.getLocalizedText(
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
                languageCubit: languageCubit,
                currentlyPlayingTrack: currentlyPlayingTrack,
                onPlayStateChanged: onPlayStateChanged,
              ),
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
                      languageCubit.getLocalizedText(
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
      bottomNavigationBar: _NavigationBar(
        isFirstChapter: isFirstChapter,
        isLastChapter: isLastChapter,
        languageCubit: languageCubit,
        onNavigateToPrevious: onNavigateToPrevious,
        onNavigateToNext: onNavigateToNext,
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final bool isFirstChapter;
  final bool isLastChapter;
  final LanguagePreferenceCubit languageCubit;
  final VoidCallback onNavigateToPrevious;
  final VoidCallback onNavigateToNext;

  const _NavigationBar({
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.languageCubit,
    required this.onNavigateToPrevious,
    required this.onNavigateToNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            if (!isFirstChapter) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigateToPrevious,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(korean: '이전', english: 'Previous'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (!isLastChapter)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNavigateToNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    languageCubit.getLocalizedText(korean: '다음', english: 'Next'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageNavigatorDialog extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final LanguagePreferenceCubit languageCubit;
  final Function(int) onPageSelected;

  const _PageNavigatorDialog({
    required this.currentPage,
    required this.totalPages,
    required this.languageCubit,
    required this.onPageSelected,
  });

  @override
  State<_PageNavigatorDialog> createState() => _PageNavigatorDialogState();
}

class _PageNavigatorDialogState extends State<_PageNavigatorDialog> {
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.currentPage;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.languageCubit.getLocalizedText(
        korean: '페이지로 이동',
        english: 'Go to Page',
      )),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.languageCubit.getLocalizedText(
                korean: '페이지 번호 (1-${widget.totalPages})',
                english: 'Page number (1-${widget.totalPages})',
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              int? page = int.tryParse(value);
              if (page != null) {
                widget.onPageSelected(page);
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(height: 16),
          Slider(
            value: _currentPage.toDouble(),
            min: 1,
            max: widget.totalPages.toDouble(),
            divisions: widget.totalPages - 1,
            label: _currentPage.toString(),
            onChanged: (value) {
              int newPage = value.round();
              widget.onPageSelected(newPage);
              setState(() {
                _currentPage = newPage;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.languageCubit.getLocalizedText(
            korean: '닫기',
            english: 'Close',
          )),
        ),
      ],
    );
  }
}

class _AudioTracksBottomSheet extends StatelessWidget {
  final List<AudioTrack> audioTracks;
  final LanguagePreferenceCubit languageCubit;
  final AudioTrack? currentlyPlayingTrack;
  final Function(AudioTrack, bool) onPlayStateChanged;

  const _AudioTracksBottomSheet({
    required this.audioTracks,
    required this.languageCubit,
    required this.currentlyPlayingTrack,
    required this.onPlayStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                      languageCubit.getLocalizedText(
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
                  languageCubit: languageCubit,
                  scrollController: scrollController,
                  currentlyPlayingTrack: currentlyPlayingTrack,
                  onPlayStateChanged: onPlayStateChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}