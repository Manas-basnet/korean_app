import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DialogUtils {
  /// Shows a full-screen image viewer with zoom and swipe-to-close functionality
  static void showFullScreenImage(
    BuildContext context,
    String? imageUrl,
    String? imagePath, {
    String? heroTag,
    Color backgroundColor = Colors.black,
  }) {
    if ((imageUrl?.isEmpty ?? true) && (imagePath?.isEmpty ?? true)) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            imageUrl: imageUrl,
            imagePath: imagePath,
            heroTag: heroTag,
            backgroundColor: backgroundColor,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? imagePath;
  final String? heroTag;
  final Color backgroundColor;

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.heroTag,
    this.backgroundColor = Colors.black,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with TickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _backgroundController;
  late AnimationController _scaleController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _scaleAnimation;

  double _verticalDragDistance = 0;
  double _horizontalDragDistance = 0;
  bool _isDragging = false;
  bool _isZoomed = false;
  bool _canDrag = true;
  double _currentScale = 1.0;
  Offset _dragStartPosition = Offset.zero;

  // Improved thresholds for better UX
  static const double _closeThreshold = 80.0; // Reduced for easier closing
  static const double _velocityThreshold = 300.0; // Reduced for more sensitivity  
  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;
  static const double _scaleThreshold = 1.02; // More precise zoom detection

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupTransformationListener();
  }

  void _initializeControllers() {
    _transformationController = TransformationController();
    
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));

    // Start entrance animation
    _backgroundController.forward();
    _scaleController.forward();
  }

  void _setupTransformationListener() {
    _transformationController.addListener(() {
      final Matrix4 matrix = _transformationController.value;
      _currentScale = matrix.getMaxScaleOnAxis();
      
      setState(() {
        _isZoomed = _currentScale > 1.05; // Small threshold to account for floating point precision
      });
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _backgroundController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_isZoomed) {
      _isDragging = true;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isZoomed && _isDragging) {
      setState(() {
        _verticalDragDistance += details.delta.dy;
      });

      // Update background opacity based on drag distance
      final opacity = (1.0 - (_verticalDragDistance.abs() / 300.0)).clamp(0.0, 1.0);
      _backgroundController.value = opacity;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isZoomed && _isDragging) {
      _isDragging = false;

      if (_verticalDragDistance.abs() > _closeThreshold ||
          details.velocity.pixelsPerSecond.dy.abs() > 500) {
        _closeViewer();
      } else {
        _resetPosition();
      }
    }
  }

  void _closeViewer() {
    HapticFeedback.lightImpact();
    
    // Animate out
    _backgroundController.reverse();
    _scaleController.reverse();
    
    // Close after animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _resetPosition() {
    // Quick smooth reset
    _backgroundController.animateTo(1.0, 
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    
    setState(() {
      _verticalDragDistance = 0;
      _horizontalDragDistance = 0;
    });
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    
    if (_isZoomed) {
      // Reset to fit screen
      _animateToScale(1.0);
    } else {
      // Zoom to 2x
      _animateToScale(2.0);
    }
  }

  // void _closeViewer() {
  //   HapticFeedback.lightImpact();
    
  //   // Prevent multiple close calls
  //   if (_backgroundController.isAnimating) return;
    
  //   // Animate out quickly
  //   _backgroundController.animateTo(0.0, 
  //     duration: const Duration(milliseconds: 250),
  //     curve: Curves.easeInCubic,
  //   );
  //   _scaleController.animateTo(0.0, 
  //     duration: const Duration(milliseconds: 250),
  //     curve: Curves.easeInCubic,
  //   );
    
  //   // Close after animation with slight delay
  //   Future.delayed(const Duration(milliseconds: 200), () {
  //     if (mounted) {
  //       Navigator.of(context).pop();
  //     }
  //   });
  // }

  // void _resetPosition() {
  //   // Quick smooth reset
  //   _backgroundController.animateTo(1.0, 
  //     duration: const Duration(milliseconds: 200),
  //     curve: Curves.easeOutCubic,
  //   );
    
  //   setState(() {
  //     _verticalDragDistance = 0;
  //     _horizontalDragDistance = 0;
  //   });
  // }

  void _animateToScale(double targetScale) {
    final Matrix4 matrix = Matrix4.identity();
    matrix.scale(targetScale);
    
    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([_backgroundAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Container(
            color: widget.backgroundColor.withValues(alpha: _backgroundAnimation.value),
            child: SafeArea(
              child: Stack(
                children: [
                  // Image viewer with improved gesture handling
                  Transform.translate(
                    offset: Offset(0, _verticalDragDistance * 0.5),
                    child: Transform.scale(
                      scale: _scaleAnimation.value * (1.0 - (_verticalDragDistance.abs() / 1000.0)).clamp(0.5, 1.0),
                      child: Listener(
                        onPointerDown: (event) {
                          // Reset drag state on new pointer down
                          _dragStartPosition = event.localPosition;
                        },
                        onPointerMove: (event) {
                          // Handle swipe-to-close when not zoomed
                          if (!_isZoomed && _canDrag) {
                            final delta = event.localPosition - _dragStartPosition;
                            
                            // Only handle vertical drags that are primarily vertical
                            if (delta.dy.abs() > delta.dx.abs() && delta.dy.abs() > 10) {
                              if (!_isDragging) {
                                setState(() {
                                  _isDragging = true;
                                  _verticalDragDistance = 0;
                                });
                              }
                              
                              setState(() {
                                _verticalDragDistance = delta.dy;
                              });

                              // Update background opacity
                              final maxDistance = MediaQuery.of(context).size.height * 0.3;
                              final opacity = (1.0 - (delta.dy.abs() / maxDistance)).clamp(0.0, 1.0);
                              _backgroundController.value = opacity;
                            }
                          }
                        },
                        onPointerUp: (event) {
                          // Handle end of drag
                          if (_isDragging && !_isZoomed) {
                            _isDragging = false;
                            
                            final dragDistance = _verticalDragDistance.abs();
                            
                            // More lenient closing conditions
                            if (dragDistance > _closeThreshold || dragDistance > 50) {
                              _closeViewer();
                            } else {
                              _resetPosition();
                            }
                          }
                        },
                        child: GestureDetector(
                          onDoubleTap: _handleDoubleTap,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: _minScale,
                            maxScale: _maxScale,
                            clipBehavior: Clip.none,
                            panEnabled: true,
                            scaleEnabled: true,
                            constrained: false,
                            onInteractionStart: (details) {
                              // Disable custom drag when interaction starts
                              setState(() {
                                _canDrag = false;
                              });
                            },
                            onInteractionEnd: (details) {
                              // Re-enable drag when interaction ends
                              Future.delayed(const Duration(milliseconds: 50), () {
                                if (mounted && !_isZoomed) {
                                  setState(() {
                                    _canDrag = true;
                                  });
                                }
                              });
                            },
                            child: Center(
                              child: _buildImage(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: AnimatedOpacity(
                      opacity: _backgroundAnimation.value,
                      duration: const Duration(milliseconds: 300),
                      child: _buildCloseButton(),
                    ),
                  ),

                  // Zoom indicator
                  if (_isZoomed)
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _backgroundAnimation.value,
                        duration: const Duration(milliseconds: 300),
                        child: _buildZoomIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage() {
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate optimal size that utilizes full screen
    final maxWidth = screenSize.width;
    final maxHeight = screenSize.height;

    Widget imageWidget;

    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      imageWidget = Image.file(
        File(widget.imagePath!),
        fit: BoxFit.contain,
        width: maxWidth,
        height: maxHeight,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        fit: BoxFit.contain,
        width: maxWidth,
        height: maxHeight,
        placeholder: (context, url) => _buildLoadingWidget(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      );
    } else {
      imageWidget = _buildErrorWidget();
    }

    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildCloseButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: _closeViewer,
        icon: const Icon(
          Icons.close_rounded,
          color: Colors.white,
          size: 24,
        ),
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildZoomIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${(_currentScale * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 48,
            color: Colors.white70,
          ),
          SizedBox(height: 12),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced version with additional features
class AdvancedFullScreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? imagePath;
  final String? heroTag;
  final Color backgroundColor;
  final List<String>? imageUrls; // For gallery mode
  final int initialIndex;
  final Function(int)? onPageChanged;

  const AdvancedFullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.heroTag,
    this.backgroundColor = Colors.black,
    this.imageUrls,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  @override
  State<AdvancedFullScreenImageViewer> createState() => _AdvancedFullScreenImageViewerState();
}

class _AdvancedFullScreenImageViewerState extends State<AdvancedFullScreenImageViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Single image mode
    if (widget.imageUrls == null || widget.imageUrls!.length <= 1) {
      return FullScreenImageViewer(
        imageUrl: widget.imageUrl,
        imagePath: widget.imagePath,
        heroTag: widget.heroTag,
        backgroundColor: widget.backgroundColor,
      );
    }

    // Gallery mode
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: widget.backgroundColor,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                widget.onPageChanged?.call(index);
              },
              itemCount: widget.imageUrls!.length,
              itemBuilder: (context, index) {
                return FullScreenImageViewer(
                  imageUrl: widget.imageUrls![index],
                  heroTag: index == widget.initialIndex ? widget.heroTag : null,
                  backgroundColor: Colors.transparent,
                );
              },
            ),
            
            // Page indicator
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls!.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Usage example extensions
extension DialogUtilsExtensions on DialogUtils {
  /// Show image gallery with swipe navigation
  static void showImageGallery(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
    String? heroTag,
    Function(int)? onPageChanged,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return AdvancedFullScreenImageViewer(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
            heroTag: heroTag,
            onPageChanged: onPageChanged,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}