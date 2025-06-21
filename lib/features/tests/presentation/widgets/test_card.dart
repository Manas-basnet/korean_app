import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/test_category.dart';
import 'package:korean_language_app/shared/models/test_item.dart';

class TestCard extends StatelessWidget {
  final TestItem test;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const TestCard({
    super.key,
    required this.test,
    required this.canEdit,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    
    return Card(
      elevation: 3,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.08), 
          width: 0.5
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with image - reduced size
            Expanded(
              flex: 2,
              child: _buildHeader(context, screenSize),
            ),
            
            // Content section - increased space
            Expanded(
              flex: 3,
              child: _buildContent(context, theme, screenSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Size screenSize) {
    final theme = Theme.of(context);
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image or gradient
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: test.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildHeaderPlaceholder(theme),
            errorWidget: (context, url, error) => _buildHeaderPlaceholder(theme),
          )
        else
          _buildHeaderPlaceholder(theme),
        
        // Menu button only (no prominent level badge)
        Positioned(
          top: 8,
          right: 8,
          child: Material(
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
              itemBuilder: (context) => _buildMenuItems(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.8),
            theme.colorScheme.secondary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          test.icon,
          size: 28,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Size screenSize) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title only
          Text(
            test.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 8),
          
          // Key stats in a more compact layout
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildStatChip(
                icon: Icons.quiz_rounded,
                text: '${test.questionCount}Q',
                color: theme.colorScheme.primary,
              ),
              _buildStatChip(
                icon: Icons.timer_rounded,
                text: _formatTimeLimit(test.formattedTimeLimit),
                color: theme.colorScheme.tertiary,
              ),
              _buildStatChip(
                icon: Icons.school_rounded,
                text: '${test.passingScore}%',
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Description with more space
          Expanded(
            child: Text(
              test.description,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.3,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Bottom row with category and metrics
          Row(
            children: [
              // Category - flexible to prevent overflow
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    test.category.displayName,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Rating and views
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (test.rating > 0) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      test.formattedRating,
                      style: TextStyle(
                        color: Colors.amber[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.visibility_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    test.formattedViewCount,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeLimit(String timeLimit) {
    // Convert "30 min" to "30m" for more compact display
    return timeLimit
        .replaceAll(' min', 'm')
        .replaceAll(' hour', 'h')
        .replaceAll(' hours', 'h')
        .replaceAll(' minutes', 'm');
  }

  List<PopupMenuItem<String>> _buildMenuItems(BuildContext context) {
    final List<PopupMenuItem<String>> menuItems = [
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
    ];
    
    if (canEdit) {
      if (onEdit != null) {
        menuItems.add(const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ));
      }
      
      if (onDelete != null) {
        menuItems.add(PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded, 
                size: 18, 
                color: Theme.of(context).colorScheme.error
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ));
      }
    }
    
    return menuItems;
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'start':
        onTap();
        break;
      case 'details':
        if (onViewDetails != null) onViewDetails!();
        break;
      case 'edit':
        if (onEdit != null) onEdit!();
        break;
      case 'delete':
        if (onDelete != null) onDelete!();
        break;
    }
  }
}