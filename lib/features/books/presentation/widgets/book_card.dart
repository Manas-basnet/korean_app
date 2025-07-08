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
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: _BookCover(
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
              flex: 3,
              child: _BookInfo(
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

class _BookCover extends StatelessWidget {
  final BookItem book;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _BookCover({
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
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverImage(context),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getCategoryColor(book.category),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  book.category.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            if (canEdit)
              Positioned(
                top: 6,
                right: 6,
                child: _MenuButton(
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onViewDetails: onViewDetails,
                  onTap: onTap,
                  colorScheme: colorScheme,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    if (book.imageUrl != null && book.imageUrl!.isNotEmpty) {
      return _BookCoverImage(
        imageUrl: book.imageUrl!,
        imagePath: book.imagePath,
        colorScheme: colorScheme,
      );
    } else if (book.imagePath != null && book.imagePath!.isNotEmpty) {
      return _BookCoverImage(
        imagePath: book.imagePath,
        colorScheme: colorScheme,
      );
    } else {
      return _BookPlaceholder(
        title: book.title,
        category: book.category,
        colorScheme: colorScheme,
      );
    }
  }

  Color _getCategoryColor(CourseCategory category) {
    switch (category) {
      case CourseCategory.korean:
        return Colors.blue.shade600;
      case CourseCategory.global:
        return Colors.green.shade600;
      case CourseCategory.nepali:
        return Colors.red.shade600;
      case CourseCategory.test:
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

class _BookCoverImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final ColorScheme colorScheme;

  const _BookCoverImage({
    this.imageUrl,
    this.imagePath,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (imageUrl != null && imageUrl!.isNotEmpty) {
            return _buildNetworkImage();
          }
          return Container(
            color: colorScheme.surfaceContainerHigh,
            child: Icon(
              Icons.broken_image_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 32,
            ),
          );
        },
      );
    }
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildNetworkImage();
    }
    
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.image_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: colorScheme.surfaceContainerHigh,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: colorScheme.surfaceContainerHigh,
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    );
  }
}

class _BookPlaceholder extends StatelessWidget {
  final String title;
  final CourseCategory category;
  final ColorScheme colorScheme;

  const _BookPlaceholder({
    required this.title,
    required this.category,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color categoryColor;
    switch (category) {
      case CourseCategory.korean:
        categoryColor = Colors.blue.shade600;
        break;
      case CourseCategory.global:
        categoryColor = Colors.green.shade600;
        break;
      case CourseCategory.nepali:
        categoryColor = Colors.red.shade600;
        break;
      case CourseCategory.test:
        categoryColor = Colors.purple.shade600;
        break;
      default:
        categoryColor = colorScheme.primary;
    }
    
    return Container(
      color: colorScheme.primaryContainer.withValues(alpha: 0.2),
      child: Stack(
        children: [
          Container(
            width: 8,
            color: colorScheme.primary,
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                category.name.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert,
          size: 16,
          color: Colors.white,
        ),
        iconSize: 16,
        padding: const EdgeInsets.all(4),
        onSelected: (value) => _handleMenuAction(context, value),
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'read',
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 16),
                SizedBox(width: 8),
                Text('Read'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'details',
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16),
                SizedBox(width: 8),
                Text('Details'),
              ],
            ),
          ),
          if (onEdit != null)
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16),
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
                    Icons.delete_outline, 
                    size: 16, 
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

class _BookInfo extends StatelessWidget {
  final BookItem book;
  final ThemeData theme;

  const _BookInfo({
    required this.book,
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
          Expanded(
            flex: 2,
            child: Text(
              book.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${book.chapterCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (book.rating > 0) ...[
                Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 2),
                Text(
                  book.formattedRating,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.visibility,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                book.formattedViewCount,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}