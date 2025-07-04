import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/course_category.dart';
import 'package:korean_language_app/shared/models/book_related/book_item.dart';

class BookCard extends StatelessWidget {
  final BookItem book;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const BookCard({
    super.key,
    required this.book,
    required this.canEdit,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return _BookCardContainer(
      book: book,
      canEdit: canEdit,
      onTap: onTap,
      onLongPress: onLongPress,
      onEdit: onEdit,
      onDelete: onDelete,
      onViewDetails: onViewDetails,
    );
  }
}

class _BookCardContainer extends StatelessWidget {
  final BookItem book;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const _BookCardContainer({
    required this.book,
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
              child: _BookCardHeader(
                book: book,
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
              child: _BookCardContent(
                book: book,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCardHeader extends StatelessWidget {
  final BookItem book;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _BookCardHeader({
    required this.book,
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
    if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
      return _OptimizedBookImage(
        imageUrl: book.imageUrl!,
        imagePath: book.imagePath,
        icon: book.icon,
        colorScheme: colorScheme,
      );
    } else if (book.imagePath != null && book.imagePath!.isNotEmpty) {
      return _OptimizedBookImage(
        imagePath: book.imagePath,
        icon: book.icon,
        colorScheme: colorScheme,
      );
    } else {
      return _ImagePlaceholder(
        icon: book.icon,
        colorScheme: colorScheme,
      );
    }
  }
}

class _OptimizedBookImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final IconData icon;
  final ColorScheme colorScheme;

  const _OptimizedBookImage({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image.file(
          File(imagePath!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: (constraints.maxWidth * 2).toInt(),
          cacheHeight: (constraints.maxHeight * 2).toInt(),
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
      },
    );
  }

  Widget _buildNetworkImage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = (constraints.maxWidth * 2).toInt();
        final targetHeight = (constraints.maxHeight * 2).toInt();
        
        return CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          memCacheWidth: targetWidth.clamp(100, 200),
          memCacheHeight: targetHeight.clamp(100, 200),
          maxWidthDiskCache: targetWidth.clamp(100, 200),
          maxHeightDiskCache: targetHeight.clamp(100, 200),
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
      },
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
            value: 'read',
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 18),
                SizedBox(width: 8),
                Text('Start Reading'),
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
      case 'read':
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

class _BookCardContent extends StatelessWidget {
  final BookItem book;
  final ThemeData theme;

  const _BookCardContent({
    required this.book,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final isSmallScreen = screenSize.height < 700;
    
    final horizontalPadding = screenSize.width * 0.025;
    final verticalPadding = screenSize.height * 0.008;
    final titleToContentGap = screenSize.height * 0.004;
    final statsToChipGap = screenSize.height * 0.002;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;
        
        final paddingHeight = verticalPadding * 2;
        final gapsHeight = titleToContentGap + statsToChipGap;
        final contentHeight = availableHeight - paddingHeight - gapsHeight;
        
        final titleFontSize = isSmallScreen 
            ? (availableWidth * 0.035).clamp(10.0, 14.0)
            : (availableWidth * 0.04).clamp(12.0, 16.0);
            
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: contentHeight * 0.45,
                  minHeight: contentHeight * 0.25,
                ),
                child: Text(
                  book.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: titleFontSize,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              SizedBox(height: titleToContentGap),
              
              Expanded(
                child: LayoutBuilder(
                  builder: (context, contentConstraints) {
                    final remainingHeight = contentConstraints.maxHeight;
                    
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: remainingHeight - statsToChipGap - (screenSize.height * 0.022),
                            ),
                            child: _buildStatsSection(colorScheme, availableWidth, isSmallScreen),
                          ),
                        ),
                        
                        SizedBox(height: statsToChipGap),
                        
                        _CategoryChip(
                          category: book.category,
                          colorScheme: colorScheme,
                          theme: theme,
                          screenWidth: availableWidth,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme, double availableWidth, bool isSmallScreen) {
    final iconSize = isSmallScreen 
        ? (availableWidth * 0.035).clamp(10.0, 12.0)
        : (availableWidth * 0.04).clamp(12.0, 14.0);
    final fontSize = isSmallScreen 
        ? (availableWidth * 0.028).clamp(9.0, 11.0)
        : (availableWidth * 0.032).clamp(10.0, 12.0);
        
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatRow(
                icon: Icons.book_outlined,
                text: '${book.chapterCount}개 챕터',
                color: colorScheme.onSurfaceVariant,
                theme: theme,
                iconSize: iconSize,
                fontSize: fontSize,
              ),
              if (book.totalDuration > 0) ...[
                SizedBox(height: availableWidth * 0.008),
                _StatRow(
                  icon: Icons.access_time_rounded,
                  text: book.formattedDuration,
                  color: colorScheme.primary,
                  theme: theme,
                  iconSize: iconSize,
                  fontSize: fontSize,
                ),
              ],
              if (book.rating > 0) ...[
                SizedBox(height: availableWidth * 0.008),
                _StatRow(
                  icon: Icons.star_rounded,
                  text: book.formattedRating,
                  color: Colors.amber[600]!,
                  theme: theme,
                  iconSize: iconSize,
                  fontSize: fontSize,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.topRight,
            child: _StatRow(
              icon: Icons.visibility_rounded,
              text: book.formattedViewCount,
              color: colorScheme.onSurfaceVariant,
              theme: theme,
              iconSize: iconSize,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final ThemeData theme;
  final double iconSize;
  final double fontSize;

  const _StatRow({
    required this.icon,
    required this.text,
    required this.color,
    required this.theme,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: color,
        ),
        SizedBox(width: iconSize * 0.3),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
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
  final CourseCategory category;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final double screenWidth;
  final bool isSmallScreen;

  const _CategoryChip({
    required this.category,
    required this.colorScheme,
    required this.theme,
    required this.screenWidth,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = screenWidth * 0.02;
    final verticalPadding = screenWidth * 0.008;
    final fontSize = isSmallScreen 
        ? (screenWidth * 0.025).clamp(8.0, 10.0)
        : (screenWidth * 0.028).clamp(9.0, 11.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Text(
        category.name,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: fontSize,
          height: 1.0,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}