import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/core/enums/image_display_type.dart';
import 'package:korean_language_app/core/shared/models/image_display_source.dart';

class CustomCachedImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Widget imageWidget;

    // Determine the best image source to use
    final imageSource = _determineImageSource();
    
    switch (imageSource.type) {
      case ImageDisplayType.localFile:
        imageWidget = _buildLocalImage(context, imageSource.path!);
        break;
      case ImageDisplayType.networkUrl:
        imageWidget = _buildNetworkImage(context, imageSource.url!);
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

  ImageDisplaySource _determineImageSource() {
    // Priority 1: Local file (for new uploads or cached files)
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return ImageDisplaySource(type: ImageDisplayType.localFile, path: imagePath);
      }
    }
    
    // Priority 2: Network URL (for existing remote images)
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ImageDisplaySource(type: ImageDisplayType.networkUrl, url: imageUrl);
    }
    
    // No valid image source
    return ImageDisplaySource(type: ImageDisplayType.none);
  }

  Widget _buildLocalImage(BuildContext context, String path) {
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        // If local image fails and we have a URL fallback, try network
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