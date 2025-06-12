import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:korean_language_app/core/enums/image_display_type.dart';
import 'package:korean_language_app/core/shared/models/image_display_source.dart';

class CustomCachedImage extends StatefulWidget {
  final String? imageUrl;
  final String? imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final BorderRadius? borderRadius;

  const CustomCachedImage({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CustomCachedImage> createState() => _CustomCachedImageState();
}

class _CustomCachedImageState extends State<CustomCachedImage> {
  ImageDisplaySource? _cachedImageSource;
  bool _isResolving = false;
  String? _lastImagePath;
  String? _lastImageUrl;
  
  late String? imageUrl;
  late String? imagePath;
  late BoxFit fit;
  late double? width;
  late double? height;
  late Widget Function(BuildContext, String)? placeholder;
  late Widget Function(BuildContext, String, dynamic)? errorWidget;
  late BorderRadius? borderRadius;

  @override
  void initState() {
    super.initState();
    _initializeStateVariables();
    _resolveImageSource();
  }

  @override
  void didUpdateWidget(CustomCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final oldImagePath = imagePath;
    final oldImageUrl = imageUrl;
    
    _initializeStateVariables();
    
    if (oldImagePath != imagePath || oldImageUrl != imageUrl) {
      _resolveImageSource();
    }
  }
  
  void _initializeStateVariables() {
    imageUrl = widget.imageUrl;
    imagePath = widget.imagePath;
    fit = widget.fit;
    width = widget.width;
    height = widget.height;
    placeholder = widget.placeholder;
    errorWidget = widget.errorWidget;
    borderRadius = widget.borderRadius;
  }

  Future<void> _resolveImageSource() async {
    if (_isResolving) return;
    
    if (imagePath == _lastImagePath && imageUrl == _lastImageUrl && _cachedImageSource != null) {
      return;
    }
    
    setState(() {
      _isResolving = true;
    });
    
    try {
      final imageSource = await _determineImageSource();
      
      if (mounted) {
        setState(() {
          _cachedImageSource = imageSource;
          _lastImagePath = imagePath;
          _lastImageUrl = imageUrl;
          _isResolving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedImageSource = ImageDisplaySource(type: ImageDisplayType.none);
          _lastImagePath = imagePath;
          _lastImageUrl = imageUrl;
          _isResolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving || _cachedImageSource == null) {
      return _buildDefaultPlaceholder(context, 'Loading...');
    }
    
    Widget imageWidget;
    
    switch (_cachedImageSource!.type) {
      case ImageDisplayType.localFile:
        imageWidget = _buildLocalImage(context, _cachedImageSource!.path!);
        break;
      case ImageDisplayType.networkUrl:
        imageWidget = _buildNetworkImage(context, _cachedImageSource!.url!);
        break;
      case ImageDisplayType.none:
        imageWidget = _buildErrorWidget(context, 'No image available');
        break;
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Future<ImageDisplaySource> _determineImageSource() async {
    if (imagePath != null && imagePath!.isNotEmpty) {
      final resolvedPath = await _resolveImagePath(imagePath!);
      if (resolvedPath != null) {
        final file = File(resolvedPath);
        if (await file.exists()) {
          return ImageDisplaySource(type: ImageDisplayType.localFile, path: resolvedPath);
        }
      }
    }
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ImageDisplaySource(type: ImageDisplayType.networkUrl, url: imageUrl);
    }
    
    return ImageDisplaySource(type: ImageDisplayType.none);
  }

  Future<String?> _resolveImagePath(String path) async {
    try {
      if (path.startsWith('/')) {
        return path;
      }
      
      final documentsDir = await getApplicationDocumentsDirectory();
      final fullPath = '${documentsDir.path}/$path';
      
      if (await File(fullPath).exists()) {
        return fullPath;
      }
      
      final cacheDir = Directory('${documentsDir.path}/tests_images_cache');
      final cachePath = '${cacheDir.path}/$path';
      
      if (await File(cachePath).exists()) {
        return cachePath;
      }
      
      if (path.contains('/')) {
        final fileName = path.split('/').last;
        final files = await cacheDir.list().toList();
        
        for (final fileEntity in files) {
          if (fileEntity is File && fileEntity.path.endsWith(fileName)) {
            return fileEntity.path;
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildLocalImage(BuildContext context, String path) {
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        if (imageUrl != null && imageUrl!.isNotEmpty) {
          return _buildNetworkImage(context, imageUrl!);
        }
        return _buildErrorWidget(context, error);
      },
    );
  }

  Widget _buildNetworkImage(BuildContext context, String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder ?? (context, url) => _buildDefaultPlaceholder(context, url),
      errorWidget: errorWidget ?? (context, url, error) => _buildErrorWidget(context, error),
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context, String url) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: borderRadius,
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, size: 32, color: colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}