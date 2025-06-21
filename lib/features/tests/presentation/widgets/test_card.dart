import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:korean_language_app/shared/enums/book_level.dart';
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
    final isSmallScreen = screenSize.width < 360;
    
    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1), 
          width: 0.5
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image/icon and overlay
            Expanded(
              flex: 3,
              child: _buildHeader(context, screenSize),
            ),
            
            // Content section
            Expanded(
              flex: 4,
              child: _buildContent(context, theme, isSmallScreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Size screenSize) {
    final theme = Theme.of(context);
    final headerHeight = screenSize.height * 0.15; // Responsive height
    
    return SizedBox(
      height: headerHeight,
      child: Stack(
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
          
          // Overlay with actions
          _buildHeaderOverlay(context, theme, screenSize),
        ],
      ),
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
            theme.colorScheme.primary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          test.icon,
          size: 32,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildHeaderOverlay(BuildContext context, ThemeData theme, Size screenSize) {
    final padding = screenSize.width * 0.02; // Responsive padding
    
    return Positioned.fill(
      child: Container(
        padding: EdgeInsets.all(padding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.02,
                vertical: screenSize.height * 0.005,
              ),
              decoration: BoxDecoration(
                color: test.level.getColor().withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                test.level.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenSize.width * 0.025,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Menu button
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: EdgeInsets.all(screenSize.width * 0.015),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: screenSize.width * 0.04,
                  ),
                ),
                onSelected: (value) => _handleMenuAction(context, value),
                itemBuilder: (context) => _buildMenuItems(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, bool isSmallScreen) {
    final screenSize = MediaQuery.of(context).size;
    final contentPadding = screenSize.width * 0.03;
    
    return Padding(
      padding: EdgeInsets.all(contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Flexible(
            flex: 2,
            child: Text(
              test.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          SizedBox(height: screenSize.height * 0.008),
          
          // Key stats row
          Flexible(
            flex: 1,
            child: _buildStatsRow(theme, screenSize, isSmallScreen),
          ),
          
          SizedBox(height: screenSize.height * 0.008),
          
          // Description
          Flexible(
            flex: 2,
            child: Text(
              test.description,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isSmallScreen ? 10 : 11,
                height: 1.3,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          SizedBox(height: screenSize.height * 0.008),
          
          // Bottom row with category and rating
          Flexible(
            flex: 1,
            child: _buildBottomRow(theme, screenSize, isSmallScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, Size screenSize, bool isSmallScreen) {
    final iconSize = screenSize.width * 0.03;
    double fontSize = isSmallScreen ? 10 : 11;
    
    return Row(
      children: [
        Icon(
          Icons.quiz_rounded,
          size: iconSize,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: screenSize.width * 0.01),
        Text(
          '${test.questionCount}Q',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        SizedBox(width: screenSize.width * 0.03),
        
        Icon(
          Icons.timer_rounded,
          size: iconSize,
          color: theme.colorScheme.tertiary,
        ),
        SizedBox(width: screenSize.width * 0.01),
        Flexible(
          child: Text(
            test.formattedTimeLimit,
            style: TextStyle(
              color: theme.colorScheme.tertiary,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        SizedBox(width: screenSize.width * 0.03),
        
        Icon(
          Icons.school_rounded,
          size: iconSize,
          color: theme.colorScheme.secondary,
        ),
        SizedBox(width: screenSize.width * 0.01),
        Text(
          '${test.passingScore}%',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow(ThemeData theme, Size screenSize, bool isSmallScreen) {
    double fontSize = isSmallScreen ? 9 : 10;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Category
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.02,
              vertical: screenSize.height * 0.003,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              test.category.name,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        
        SizedBox(width: screenSize.width * 0.02),
        
        // Rating and views
        if (test.rating > 0) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: screenSize.width * 0.025,
                color: Colors.amber[600],
              ),
              SizedBox(width: screenSize.width * 0.005),
              Text(
                test.formattedRating,
                style: TextStyle(
                  color: Colors.amber[600],
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(width: screenSize.width * 0.02),
        ],
        
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_rounded,
              size: screenSize.width * 0.025,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: screenSize.width * 0.005),
            Text(
              test.formattedViewCount,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
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