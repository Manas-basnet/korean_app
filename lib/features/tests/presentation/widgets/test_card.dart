import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/models/test_item.dart';

class TestCard extends StatelessWidget {
  final TestItem test;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const TestCard({
    super.key,
    required this.test,
    required this.canEdit,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _TestCardContainer(
        test: test,
        canEdit: canEdit,
        onTap: onTap,
        onLongPress: onLongPress,
        onEdit: onEdit,
        onDelete: onDelete,
        onViewDetails: onViewDetails,
      ),
    );
  }
}

class _TestCardContainer extends StatelessWidget {
  final TestItem test;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const _TestCardContainer({
    required this.test,
    required this.canEdit,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 45,
              child: _TestCardHeader(
                test: test,
                canEdit: canEdit,
                onEdit: onEdit,
                onDelete: onDelete,
                onViewDetails: onViewDetails,
                onTap: onTap,
                colorScheme: colorScheme,
              ),
            ),
            Expanded(
              flex: 55,
              child: _TestCardContent(
                test: test,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestCardHeader extends StatelessWidget {
  final TestItem test;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _TestCardHeader({
    required this.test,
    required this.canEdit,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildImageSection(context),
        if (canEdit)
          Positioned(
            top: 8,
            right: 8,
            child: _MenuButton(
              onEdit: onEdit,
              onDelete: onDelete,
              onViewDetails: onViewDetails,
              onTap: onTap,
              colorScheme: colorScheme,
            ),
          ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
      return _OptimizedTestImage(
        imageUrl: test.imageUrl!,
        imagePath: test.imagePath,
        icon: test.icon,
        colorScheme: colorScheme,
      );
    } else if (test.imagePath != null && test.imagePath!.isNotEmpty) {
      return _OptimizedTestImage(
        imagePath: test.imagePath,
        icon: test.icon,
        colorScheme: colorScheme,
      );
    } else {
      return _ImagePlaceholder(
        icon: test.icon,
        colorScheme: colorScheme,
      );
    }
  }
}

class _OptimizedTestImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final IconData icon;
  final ColorScheme colorScheme;

  const _OptimizedTestImage({
    this.imageUrl,
    this.imagePath,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return _buildLocalImage();
    }
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildNetworkImage();
    }
    
    return _ImagePlaceholder(icon: icon, colorScheme: colorScheme);
  }

  Widget _buildLocalImage() {
    return Image.file(
      File(imagePath!),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (imageUrl != null && imageUrl!.isNotEmpty) {
          return _buildNetworkImage();
        }
        return _ImagePlaceholder(icon: icon, colorScheme: colorScheme);
      },
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      memCacheHeight: 300,
      maxWidthDiskCache: 400,
      maxHeightDiskCache: 300,
      placeholder: (context, url) => _ImagePlaceholder(
        icon: icon,
        colorScheme: colorScheme,
        showLoading: true,
      ),
      errorWidget: (context, url, error) => _ImagePlaceholder(
        icon: icon,
        colorScheme: colorScheme,
      ),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  final ColorScheme colorScheme;
  final bool showLoading;

  const _ImagePlaceholder({
    required this.icon,
    required this.colorScheme,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.8),
            colorScheme.primary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              size: 28,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (showLoading)
            Positioned(
              bottom: 8,
              right: 8,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _MenuButton({
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        onSelected: (value) => _handleMenuAction(context, value),
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'start',
            child: Row(
              children: [
                Icon(Icons.play_arrow_rounded, size: 18),
                SizedBox(width: 8),
                Text('Start Test'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'details',
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18),
                SizedBox(width: 8),
                Text('View Details'),
              ],
            ),
          ),
          if (onEdit != null)
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
          if (onDelete != null)
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded, 
                    size: 18, 
                    color: colorScheme.error
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'start':
        onTap();
        break;
      case 'details':
        onViewDetails?.call();
        break;
      case 'edit':
        onEdit?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
    }
  }
}

class _TestCardContent extends StatelessWidget {
  final TestItem test;
  final ThemeData theme;

  const _TestCardContent({
    required this.test,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              test.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildStatsSection(colorScheme),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _CategoryChip(
                    category: test.category,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatRow(
                icon: Icons.schedule_rounded,
                text: _formatTimeLimit(test.formattedTimeLimit),
                color: colorScheme.onSurfaceVariant,
                theme: theme,
              ),
              if (test.rating > 0)
                _StatRow(
                  icon: Icons.star_rounded,
                  text: test.formattedRating,
                  color: Colors.amber[600]!,
                  theme: theme,
                ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.topRight,
            child: _StatRow(
              icon: Icons.visibility_rounded,
              text: test.formattedViewCount,
              color: colorScheme.onSurfaceVariant,
              theme: theme,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeLimit(String timeLimit) {
    return timeLimit
        .replaceAll(' min', '분')
        .replaceAll(' hour', '시간')
        .replaceAll(' hours', '시간')
        .replaceAll(' minutes', '분');
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final ThemeData theme;

  const _StatRow({
    required this.icon,
    required this.text,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final TestCategory category;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _CategoryChip({
    required this.category,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category.displayName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}