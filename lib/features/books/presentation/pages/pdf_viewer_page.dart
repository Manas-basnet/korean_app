import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/features/books/presentation/widgets/background_audio_player.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/book_related/chapter.dart';
import 'package:korean_language_app/shared/models/audio_track.dart';

class PDFViewerScreen extends StatefulWidget {
  final File pdfFile;
  final String title;
  final BookItem? book;
  final Chapter? chapter;
  
  const PDFViewerScreen({
    super.key,
    required this.pdfFile,
    required this.title,
    this.book,
    this.chapter,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen>
    with TickerProviderStateMixin {
  
  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const Duration _overlayHideDelay = Duration(seconds: 3);
  static const Curve _animationCurve = Curves.easeInOut;
  static const Offset _topSlideBegin = Offset(0, -1);
  static const Offset _bottomSlideBegin = Offset(0, 1);
  static const Offset _slideEnd = Offset.zero;
  
  late AnimationController _uiAnimationController;
  late AnimationController _audioAnimationController;
  late AnimationController _audioOverlayController;
  late Animation<Offset> _topSlideAnimation;
  late Animation<Offset> _bottomSlideAnimation;
  late Animation<Offset> _audioSlideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _overlayOpacityAnimation;
  
  PDFViewController? _pdfController;
  bool _showUI = true;
  bool _showAudioPanel = false;
  bool _isHorizontal = false;
  int _currentPage = 0;
  int _totalPages = 0;
  
  // Audio overlay state
  Timer? _overlayHideTimer;
  bool _isUserInteractingWithOverlay = false;
  
  List<AudioTrack> get _audioTracks {
    if (widget.chapter != null) {
      return widget.chapter!.audioTracks;
    } else if (widget.book != null) {
      return widget.book!.audioTracks;
    }
    return [];
  }
  
  bool get _hasAudio => _audioTracks.isNotEmpty;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _uiAnimationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _audioAnimationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _audioOverlayController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _topSlideAnimation = Tween<Offset>(
      begin: _topSlideBegin,
      end: _slideEnd,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: _animationCurve,
    ));
    
    _bottomSlideAnimation = Tween<Offset>(
      begin: _bottomSlideBegin,
      end: _slideEnd,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: _animationCurve,
    ));
    
    _audioSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: _slideEnd,
    ).animate(CurvedAnimation(
      parent: _audioAnimationController,
      curve: _animationCurve,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: _animationCurve,
    ));
    
    _overlayOpacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _audioOverlayController,
      curve: _animationCurve,
    ));
    
    _uiAnimationController.forward();
  }
  
  @override
  void dispose() {
    _uiAnimationController.dispose();
    _audioAnimationController.dispose();
    _audioOverlayController.dispose();
    _overlayHideTimer?.cancel();
    super.dispose();
  }
  
  void _toggleUI() {
    if (kDebugMode) {
      print('Toggle UI called - current state: $_showUI');
    }
    
    if (_showUI) {
      _uiAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showUI = false;
          });
        }
      });
    } else {
      setState(() {
        _showUI = true;
      });
      _uiAnimationController.forward();
    }
  }
  
  void _toggleAudioPanel() {
    if (!_hasAudio) return;
    
    if (_showAudioPanel) {
      _audioAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showAudioPanel = false;
          });
        }
      });
    } else {
      setState(() {
        _showAudioPanel = true;
      });
      _audioAnimationController.forward();
    }
  }
  
  void _closeAudioPanel() {
    if (_showAudioPanel) {
      _audioAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showAudioPanel = false;
          });
        }
      });
    }
  }
  
  void _toggleViewMode() {
    setState(() {
      _isHorizontal = !_isHorizontal;
    });
    if (_pdfController != null) {
      _pdfController!.setPage(_currentPage - 1);
    }
  }
  
  void _downloadPdf() {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.download_done, color: Colors.white),
              SizedBox(width: 8),
              Text('PDF saved to downloads'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Error saving PDF: $e'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  
  void _showAudioOverlay() {
    _audioOverlayController.forward();
    _startOverlayHideTimer();
  }
  
  void _hideAudioOverlay() {
    if (!_isUserInteractingWithOverlay) {
      _audioOverlayController.reverse();
    }
  }
  
  void _startOverlayHideTimer() {
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(_overlayHideDelay, _hideAudioOverlay);
  }
  
  void _onOverlayInteraction() {
    setState(() {
      _isUserInteractingWithOverlay = true;
    });
    _audioOverlayController.forward();
    _overlayHideTimer?.cancel();
    
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isUserInteractingWithOverlay = false;
        });
        _startOverlayHideTimer();
      }
    });
  }
  
  void _onTrackStarted(AudioTrack track) {
    _showAudioOverlay();
    if (kDebugMode) {
      print('Started playing: ${track.name}');
    }
  }
  
  void _onTrackCompleted(AudioTrack track) {
    if (kDebugMode) {
      print('Completed playing: ${track.name}');
    }
  }
  
  void _onPlaylistCompleted() {
    if (kDebugMode) {
      print('Playlist completed');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.playlist_play, color: Colors.white),
            SizedBox(width: 8),
            Text('Playlist completed'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return BackgroundAudioPlayer(
      audioTracks: _audioTracks,
      onTrackStarted: _onTrackStarted,
      onTrackCompleted: _onTrackCompleted,
      onPlaylistCompleted: _onPlaylistCompleted,
      builder: (audioState) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _toggleUI();
                    if (_showAudioPanel) {
                      _closeAudioPanel();
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    children: [
                      PDFView(
                        key: ValueKey(_isHorizontal),
                        filePath: widget.pdfFile.path,
                        enableSwipe: true,
                        swipeHorizontal: _isHorizontal,
                        autoSpacing: true,
                        pageFling: true,
                        pageSnap: true,
                        defaultPage: _currentPage > 0 ? _currentPage - 1 : 0,
                        fitPolicy: FitPolicy.BOTH,
                        preventLinkNavigation: false,
                        onRender: (pages) {
                          setState(() {
                            _totalPages = pages ?? 0;
                            if (_currentPage == 0 && _totalPages > 0) {
                              _currentPage = 1;
                            }
                          });
                          if (kDebugMode) {
                            print('PDF rendered with $pages pages');
                          }
                        },
                        onError: (error) {
                          if (kDebugMode) {
                            print('Error in PDFView: $error');
                          }
                          context.pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $error'),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        },
                        onPageError: (page, error) {
                          debugPrint('Error on page $page: $error');
                        },
                        onViewCreated: (controller) {
                          _pdfController = controller;
                          if (kDebugMode) {
                            print('PDFView controller created');
                          }
                        },
                        onPageChanged: (int? page, int? total) {
                          setState(() {
                            _currentPage = (page ?? 0) + 1;
                            _totalPages = total ?? 0;
                          });
                          if (kDebugMode) {
                            print('Page changed: $_currentPage / $_totalPages');
                          }
                        },
                      ),
                      
                      Container(
                        color: Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Audio Mini Player
              if (audioState.showMiniPlayer)
                Positioned(
                  top: 50,
                  left: 20,
                  right: 80,
                  child: AnimatedBuilder(
                    animation: _overlayOpacityAnimation,
                    builder: (context, child) {
                      return AudioMiniPlayer(
                        audioState: audioState,
                        opacity: _overlayOpacityAnimation.value,
                        onInteraction: _onOverlayInteraction,
                      );
                    },
                  ),
                ),
              
              // UI Toggle Button
              Positioned(
                top: 50,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleUI,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _showUI ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              
              // UI Controls
              if (_showUI) ...[
                // Top Controls
                Positioned(
                  top: 50,
                  left: 20,
                  child: SlideTransition(
                    position: _topSlideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SafeArea(
                        child: Row(
                          children: [
                            _buildControlButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onPressed: () => context.pop(),
                              tooltip: 'Go Back',
                            ),
                            const SizedBox(width: 12),
                            _buildControlButton(
                              icon: Icons.file_download_outlined,
                              onPressed: _downloadPdf,
                              tooltip: 'Download PDF',
                            ),
                            if (_hasAudio) ...[
                              const SizedBox(width: 12),
                              _buildControlButton(
                                icon: _showAudioPanel ? Icons.volume_off : Icons.volume_up,
                                onPressed: _toggleAudioPanel,
                                tooltip: _showAudioPanel ? 'Hide Audio' : 'Show Audio',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bottom Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _bottomSlideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SafeArea(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          child: _buildBottomSection(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              
              // Audio Panel with backdrop
              if (_hasAudio && _showAudioPanel) ...[
                // Backdrop
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeAudioPanel,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                
                // Audio Panel
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 300,
                  child: SlideTransition(
                    position: _audioSlideAnimation,
                    child: _buildAudioPanel(audioState),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: _buildToggleButton(),
        ),
        const SizedBox(height: 12),
        _buildPageIndicator(),
      ],
    );
  }
  
  Widget _buildToggleButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(
            icon: Icons.view_agenda_outlined,
            label: 'Vertical',
            isSelected: !_isHorizontal,
            onTap: () {
              if (_isHorizontal) _toggleViewMode();
            },
          ),
          _buildToggleOption(
            icon: Icons.view_day_outlined,
            label: 'Horizontal',
            isSelected: _isHorizontal,
            onTap: () {
              if (!_isHorizontal) _toggleViewMode();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPageIndicator() {
    if (_totalPages == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
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
          const Icon(
            Icons.description_outlined,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$_currentPage',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            ' / $_totalPages',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAudioPanel(BackgroundAudioPlayerState audioState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        border: Border(
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.library_music,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audio Tracks',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (audioState.currentTrack != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Playing: ${audioState.currentTrack!.name}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleAudioPanel,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _audioTracks.isEmpty
                  ? const Center(
                      child: Text(
                        'No audio tracks available',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _audioTracks.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final audioTrack = _audioTracks[index];
                        return AudioTrackItem(
                          audioTrack: audioTrack,
                          audioState: audioState,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}