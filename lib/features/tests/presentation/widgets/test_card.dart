import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/models/test_related/test_item.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: _TestHeader(
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
              flex: 4,
              child: _TestContent(
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

class _TestHeader extends StatelessWidget {
  final TestItem test;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _TestHeader({
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
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeaderContent(),
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

  Widget _buildHeaderContent() {
    if (test.imageUrl != null && test.imageUrl!.isNotEmpty) {
      return _TestCoverImage(
        imageUrl: test.imageUrl!,
        imagePath: test.imagePath,
        colorScheme: colorScheme,
      );
    } else if (test.imagePath != null && test.imagePath!.isNotEmpty) {
      return _TestCoverImage(
        imagePath: test.imagePath,
        colorScheme: colorScheme,
      );
    } else {
      return _TestPlaceholder(
        category: test.category,
        questionCount: test.questionCount,
        colorScheme: colorScheme,
      );
    }
  }
}

class _TestCoverImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final ColorScheme colorScheme;

  const _TestCoverImage({
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
          return _buildErrorPlaceholder();
        },
      );
    }
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildNetworkImage();
    }
    
    return _buildErrorPlaceholder();
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
      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.quiz_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}

class _TestPlaceholder extends StatelessWidget {
  final TestCategory category;
  final int questionCount;
  final ColorScheme colorScheme;

  const _TestPlaceholder({
    required this.category,
    required this.questionCount,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    IconData icon;
    
    switch (category) {
      case TestCategory.topikI:
        icon = Icons.quiz_outlined;
        break;
      case TestCategory.topikII:
        icon = Icons.assignment_outlined;
        break;
      case TestCategory.practice:
        icon = Icons.school_outlined;
        break;
      case TestCategory.ubt:
        icon = Icons.fact_check_outlined;
        break;
      default:
        icon = Icons.quiz_outlined;
    }
    
    return Container(
      color: colorScheme.primaryContainer.withValues(alpha: 0.2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              '$questionCount',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Questions',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
            value: 'start',
            child: Row(
              children: [
                Icon(Icons.play_arrow, size: 16),
                SizedBox(width: 8),
                Text('Start Test'),
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

class _TestContent extends StatelessWidget {
  final TestItem test;
  final ThemeData theme;

  const _TestContent({
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
          Expanded(
            flex: 3,
            child: Text(
              test.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(
                Icons.quiz,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${test.questionCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.schedule,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  test.formattedTimeLimit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getCategoryColor(test.category),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  test.category.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              if (test.rating > 0) ...[
                Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 2),
                Text(
                  test.formattedRating,
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
                test.formattedViewCount,
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

  Color _getCategoryColor(TestCategory category) {
    switch (category) {
      case TestCategory.topikI:
        return Colors.blue.shade600;
      case TestCategory.topikII:
        return Colors.indigo.shade600;
      case TestCategory.practice:
        return Colors.green.shade600;
      case TestCategory.ubt:
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}