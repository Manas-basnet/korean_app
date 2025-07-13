import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
import 'package:korean_language_app/shared/enums/supported_language.dart';
import 'package:korean_language_app/shared/models/vocabulary_related/vocabulary_item.dart';

class VocabularyCard extends StatelessWidget {
  final VocabularyItem vocabulary;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const VocabularyCard({
    super.key,
    required this.vocabulary,
    required this.canEdit,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return _VocabularyCardContainer(
      vocabulary: vocabulary,
      canEdit: canEdit,
      onTap: onTap,
      onLongPress: onLongPress,
      onEdit: onEdit,
      onDelete: onDelete,
      onViewDetails: onViewDetails,
    );
  }
}

class _VocabularyCardContainer extends StatelessWidget {
  final VocabularyItem vocabulary;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const _VocabularyCardContainer({
    required this.vocabulary,
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
              child: _VocabularyCover(
                vocabulary: vocabulary,
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
              child: _VocabularyInfo(
                vocabulary: vocabulary,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabularyCover extends StatelessWidget {
  final VocabularyItem vocabulary;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _VocabularyCover({
    required this.vocabulary,
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
                  color: _getLanguageColor(vocabulary.primaryLanguage),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vocabulary.primaryLanguage.flag,
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vocabulary.primaryLanguage.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: vocabulary.level.getColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vocabulary.level.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            if (canEdit)
              Positioned(
                bottom: 6,
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
    if (vocabulary.imageUrl != null && vocabulary.imageUrl!.isNotEmpty) {
      return _VocabularyCoverImage(
        imageUrl: vocabulary.imageUrl!,
        imagePath: vocabulary.imagePath,
        colorScheme: colorScheme,
      );
    } else if (vocabulary.imagePath != null && vocabulary.imagePath!.isNotEmpty) {
      return _VocabularyCoverImage(
        imagePath: vocabulary.imagePath,
        colorScheme: colorScheme,
      );
    } else {
      return _VocabularyPlaceholder(
        title: vocabulary.title,
        primaryLanguage: vocabulary.primaryLanguage,
        level: vocabulary.level,
        colorScheme: colorScheme,
      );
    }
  }

  Color _getLanguageColor(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.korean:
        return Colors.blue.shade600;
      case SupportedLanguage.japanese:
        return Colors.red.shade600;
      case SupportedLanguage.chinese:
        return Colors.yellow.shade700;
      case SupportedLanguage.english:
        return Colors.green.shade600;
      case SupportedLanguage.nepali:
        return Colors.orange.shade600;
      case SupportedLanguage.hindi:
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

class _VocabularyCoverImage extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  final ColorScheme colorScheme;

  const _VocabularyCoverImage({
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

class _VocabularyPlaceholder extends StatelessWidget {
  final String title;
  final SupportedLanguage primaryLanguage;
  final BookLevel level;
  final ColorScheme colorScheme;

  const _VocabularyPlaceholder({
    required this.title,
    required this.primaryLanguage,
    required this.level,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final baseColor = _getLanguageBaseColor(primaryLanguage);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.2),
            baseColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Stack(
        children: [
          Container(
            width: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  baseColor,
                  baseColor.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.school_rounded,
              size: 48,
              color: baseColor.withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: baseColor,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      primaryLanguage.flag,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: level.getColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getLanguageBaseColor(SupportedLanguage language) {
    switch (language) {
      case SupportedLanguage.korean:
        return Colors.blue.shade700;
      case SupportedLanguage.japanese:
        return Colors.red.shade700;
      case SupportedLanguage.chinese:
        return Colors.yellow.shade800;
      case SupportedLanguage.english:
        return Colors.green.shade700;
      case SupportedLanguage.nepali:
        return Colors.orange.shade700;
      case SupportedLanguage.hindi:
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
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
            value: 'study',
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 16),
                SizedBox(width: 8),
                Text('Study'),
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
      case 'study':
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

class _VocabularyInfo extends StatelessWidget {
  final VocabularyItem vocabulary;
  final ThemeData theme;

  const _VocabularyInfo({
    required this.vocabulary,
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
              vocabulary.title,
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
                Icons.book_outlined,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${vocabulary.chapterCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.translate,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${vocabulary.totalWords}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (vocabulary.rating > 0) ...[
                Icon(
                  Icons.star,
                  size: 12,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 2),
                Text(
                  vocabulary.formattedRating,
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
                vocabulary.formattedViewCount,
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