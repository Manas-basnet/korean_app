import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';
import 'package:korean_language_app/shared/models/book_related/chapter.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_audio_tracks_widget.dart';
import 'package:korean_language_app/features/books/presentation/widgets/chapters_audio_tracks_widget.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';

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
  
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Duration _hideDelay = Duration(seconds: 3);
  
  late AnimationController _uiAnimationController;
  late AnimationController _pageScrollAnimationController;
  late AnimationController _audioPanelController;
  
  late Animation<double> _uiFadeAnimation;
  late Animation<Offset> _topSlideAnimation;
  late Animation<Offset> _bottomSlideAnimation;
  late Animation<double> _pageScrollOpacityAnimation;
  late Animation<Offset> _pageScrollSlideAnimation;
  late Animation<Offset> _audioPanelSlideAnimation;
  
  PDFViewController? _pdfController;
  bool _showUI = true;
  bool _isHorizontal = false;
  bool _showPageScroll = false;
  bool _showAudioPanel = false;
  int _currentPage = 0;
  int _totalPages = 0;
  double _pageScrollPosition = 0.0;
  
  bool _isDraggingPageScroll = false;
  bool _userInteracting = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startHideTimer();
  }
  
  void _initializeAnimations() {
    _uiAnimationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _pageScrollAnimationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _audioPanelController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _uiFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _topSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _bottomSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _pageScrollOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pageScrollAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _pageScrollSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageScrollAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _audioPanelSlideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _audioPanelController,
      curve: Curves.easeInOut,
    ));
    
    _uiAnimationController.forward();
  }
  
  @override
  void dispose() {
    _uiAnimationController.dispose();
    _pageScrollAnimationController.dispose();
    _audioPanelController.dispose();
    super.dispose();
  }
  
  void _startHideTimer() {
    Future.delayed(_hideDelay, () {
      if (mounted && !_userInteracting && _showUI) {
        _hideUI();
      }
    });
  }
  
  void _onUserInteraction() {
    setState(() {
      _userInteracting = true;
    });
    
    if (!_showUI) {
      _showUIElements();
    }
    
    _showPageScrollTemporarily();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _userInteracting = false;
      });
      _startHideTimer();
    });
  }
  
  void _showUIElements() {
    setState(() {
      _showUI = true;
    });
    _uiAnimationController.forward();
  }
  
  void _hideUI() {
    _uiAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showUI = false;
        });
      }
    });
    _hidePageScroll();
  }
  
  void _showPageScrollTemporarily() {
    if (_totalPages > 1) {
      setState(() {
        _showPageScroll = true;
      });
      _pageScrollAnimationController.forward();
      
      Future.delayed(_hideDelay, () {
        if (mounted && !_isDraggingPageScroll) {
          _hidePageScroll();
        }
      });
    }
  }
  
  void _hidePageScroll() {
    _pageScrollAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showPageScroll = false;
        });
      }
    });
  }
  
  void _toggleAudioPanel() {
    setState(() {
      _showAudioPanel = !_showAudioPanel;
    });
    
    if (_showAudioPanel) {
      _audioPanelController.forward();
    } else {
      _audioPanelController.reverse();
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
  
  void _goToPage(int page) {
    if (_pdfController != null && page >= 1 && page <= _totalPages) {
      _pdfController!.setPage(page - 1);
    }
  }
  
  void _onPageScrollDrag(double value) {
    setState(() {
      _isDraggingPageScroll = true;
      _pageScrollPosition = value;
    });
    
    final targetPage = (value * _totalPages).round() + 1;
    if (targetPage != _currentPage) {
      _goToPage(targetPage);
    }
  }
  
  void _onPageScrollDragEnd() {
    setState(() {
      _isDraggingPageScroll = false;
    });
    
    Future.delayed(_hideDelay, () {
      if (mounted && !_isDraggingPageScroll) {
        _hidePageScroll();
      }
    });
  }
  
  void _downloadPdf() {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                context.read<LanguagePreferenceCubit>().getLocalizedText(
                  korean: 'PDF 다운로드가 완료되었습니다',
                  english: 'PDF downloaded successfully',
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.read<LanguagePreferenceCubit>().getLocalizedText(
                    korean: 'PDF 다운로드 중 오류가 발생했습니다: $e',
                    english: 'Error downloading PDF: $e',
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final languageCubit = context.read<LanguagePreferenceCubit>();
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onUserInteraction,
        child: Stack(
          children: [
            _buildPDFView(),
            
            if (_showAudioPanel) 
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _buildAudioPanel(languageCubit),
              ),
            
            if (_showUI) 
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopControls(languageCubit),
              ),
            
            if (_showUI) 
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(languageCubit),
              ),
            
            if (_showPageScroll && _totalPages > 1) 
              Positioned(
                right: 8,
                top: 100,
                bottom: 100,
                child: _buildPageScrollBar(),
              ),
            
            Positioned(
              top: 60,
              right: 16,
              child: _buildFloatingToggleButton(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPDFView() {
    return Positioned.fill(
      child: PDFView(
        key: ValueKey('${_isHorizontal}_${widget.pdfFile.path}'),
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
          _updatePageScrollPosition();
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
          _updatePageScrollPosition();
          if (kDebugMode) {
            print('Page changed: $_currentPage / $_totalPages');
          }
        },
      ),
    );
  }
  
  void _updatePageScrollPosition() {
    if (_totalPages > 0 && !_isDraggingPageScroll) {
      setState(() {
        _pageScrollPosition = (_currentPage - 1) / _totalPages;
      });
    }
  }
  
  Widget _buildAudioPanel(LanguagePreferenceCubit languageCubit) {
    return SlideTransition(
      position: _audioPanelSlideAnimation,
      child: Container(
        width: 320,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.audiotrack,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        languageCubit.getLocalizedText(
                          korean: '오디오 트랙',
                          english: 'Audio Tracks',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleAudioPanel,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (widget.book != null && widget.book!.audioTracks.isNotEmpty) ...[
                        BookAudioTracksWidget(
                          book: widget.book!,
                          isCompact: false,
                          showPreloadButton: true,
                        ),
                        if (widget.chapter != null && widget.chapter!.audioTracks.isNotEmpty)
                          const SizedBox(height: 16),
                      ],
                      
                      if (widget.chapter != null && 
                          widget.book != null && 
                          widget.chapter!.audioTracks.isNotEmpty)
                        ChapterAudioTracksWidget(
                          bookId: widget.book!.id,
                          chapter: widget.chapter!,
                          isCompact: false,
                          showPreloadButton: true,
                        ),
                      
                      if ((widget.book?.audioTracks.isEmpty ?? true) && 
                          (widget.chapter?.audioTracks.isEmpty ?? true))
                        _buildNoAudioTracksMessage(languageCubit),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNoAudioTracksMessage(LanguagePreferenceCubit languageCubit) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.audiotrack_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            languageCubit.getLocalizedText(
              korean: '오디오 트랙이 없습니다',
              english: 'No audio tracks available',
            ),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            languageCubit.getLocalizedText(
              korean: '이 문서에는 오디오 콘텐츠가 포함되어 있지 않습니다',
              english: 'This document does not contain any audio content',
            ),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopControls(LanguagePreferenceCubit languageCubit) {
    return SlideTransition(
      position: _topSlideAnimation,
      child: FadeTransition(
        opacity: _uiFadeAnimation,
        child: SafeArea(
          child: Container(
            height: 80,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildControlButton(
                    icon: Icons.arrow_back_ios_new,
                    onPressed: () => context.pop(),
                    tooltip: languageCubit.getLocalizedText(
                      korean: '뒤로가기',
                      english: 'Go back',
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_totalPages > 0)
                          Text(
                            '${_currentPage} / $_totalPages',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  if ((widget.book?.audioTracks.isNotEmpty ?? false) ||
                      (widget.chapter?.audioTracks.isNotEmpty ?? false)) ...[
                    _buildControlButton(
                      icon: Icons.audiotrack,
                      onPressed: _toggleAudioPanel,
                      tooltip: languageCubit.getLocalizedText(
                        korean: '오디오 트랙',
                        english: 'Audio tracks',
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  _buildControlButton(
                    icon: Icons.download,
                    onPressed: _downloadPdf,
                    tooltip: languageCubit.getLocalizedText(
                      korean: '다운로드',
                      english: 'Download',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomControls(LanguagePreferenceCubit languageCubit) {
    return SlideTransition(
      position: _bottomSlideAnimation,
      child: FadeTransition(
        opacity: _uiFadeAnimation,
        child: SafeArea(
          child: Container(
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
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeToggle(languageCubit),
                const SizedBox(height: 16),
                _buildPageIndicator(languageCubit),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPageScrollBar() {
    return SlideTransition(
      position: _pageScrollSlideAnimation,
      child: FadeTransition(
        opacity: _pageScrollOpacityAnimation,
        child: Container(
          width: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scrollHeight = constraints.maxHeight - 40;
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    '$_currentPage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final localY = details.localPosition.dy;
                        final relativeY = (localY - 20) / (scrollHeight - 40);
                        final clampedValue = relativeY.clamp(0.0, 1.0);
                        _onPageScrollDrag(clampedValue);
                      },
                      onPanEnd: (_) => _onPageScrollDragEnd(),
                      child: Container(
                        width: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        child: Stack(
                          children: [
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            
                            Positioned(
                              top: _pageScrollPosition * (scrollHeight - 40),
                              child: Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalPages',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildFloatingToggleButton() {
    return AnimatedOpacity(
      opacity: _showUI ? 0.0 : 1.0,
      duration: _animationDuration,
      child: _buildControlButton(
        icon: Icons.visibility,
        onPressed: _onUserInteraction,
        tooltip: 'Show controls',
      ),
    );
  }
  
  Widget _buildViewModeToggle(LanguagePreferenceCubit languageCubit) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(
            icon: Icons.view_agenda_outlined,
            label: languageCubit.getLocalizedText(korean: '세로', english: 'Vertical'),
            isSelected: !_isHorizontal,
            onTap: () {
              if (_isHorizontal) _toggleViewMode();
            },
          ),
          _buildToggleOption(
            icon: Icons.view_day_outlined,
            label: languageCubit.getLocalizedText(korean: '가로', english: 'Horizontal'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPageIndicator(LanguagePreferenceCubit languageCubit) {
    if (_totalPages == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            color: Colors.white.withValues(alpha: 0.8),
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            languageCubit.getLocalizedText(
              korean: '$_currentPage / $_totalPages 페이지',
              english: 'Page $_currentPage of $_totalPages',
            ),
            style: const TextStyle(
              color: Colors.white,
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
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
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
}