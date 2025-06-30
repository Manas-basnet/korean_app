import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';

class PDFViewerScreen extends StatefulWidget {
  final File pdfFile;
  final String title;
  
  const PDFViewerScreen({
    super.key,
    required this.pdfFile,
    required this.title,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen>
    with TickerProviderStateMixin {
  
  // Animation configuration variables
  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const Curve _animationCurve = Curves.easeInOut;
  static const Offset _topSlideBegin = Offset(0, -1);
  static const Offset _bottomSlideBegin = Offset(0, 1);
  static const Offset _slideEnd = Offset.zero;
  
  late AnimationController _uiAnimationController;
  late Animation<Offset> _topSlideAnimation;
  late Animation<Offset> _bottomSlideAnimation;
  late Animation<double> _fadeAnimation;
  
  PDFViewController? _pdfController;
  bool _showUI = true;
  bool _isHorizontal = false;
  int _currentPage = 0;
  int _totalPages = 0;
  
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
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: _animationCurve,
    ));
    
    _uiAnimationController.forward();
  }
  
  @override
  void dispose() {
    _uiAnimationController.dispose();
    super.dispose();
  }
  
  void _toggleUI() {
    if (kDebugMode) {
      print('Toggle UI called - current state: $_showUI');
    }
    
    if (_showUI) {
      // Hide UI with animation
      _uiAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showUI = false;
          });
        }
      });
    } else {
      // Show UI with animation
      setState(() {
        _showUI = true;
      });
      _uiAnimationController.forward();
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PDF Viewer
          Positioned.fill(
            child: PDFView(
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
          ),
          
          // Always visible toggle button
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
                    color: Colors.black.withValues(alpha:0.6),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha:0.2),
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
          
          // Back button (top-left)
          Positioned(
            top: 50,
            left: 20,
            child: _showUI 
              ? SlideTransition(
                  position: _topSlideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SafeArea(
                      child: _buildControlButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => context.pop(),
                        tooltip: 'Go Back',
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          ),
          
          // Download button (top-left, next to back button)
          Positioned(
            top: 50,
            left: 80,
            child: _showUI 
              ? SlideTransition(
                  position: _topSlideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SafeArea(
                      child: _buildControlButton(
                        icon: Icons.file_download_outlined,
                        onPressed: _downloadPdf,
                        tooltip: 'Download PDF',
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          ),
          
          // Bottom Controls & Page Indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _showUI 
              ? SlideTransition(
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
                )
              : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha:0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha:0.1),
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
              ? Colors.white.withValues(alpha:0.2)
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
        color: Colors.black.withValues(alpha:0.8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.2),
          width: 1,
        ),
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
              color: Colors.white.withValues(alpha:0.7),
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
        color: Colors.black.withValues(alpha:0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.1),
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
}