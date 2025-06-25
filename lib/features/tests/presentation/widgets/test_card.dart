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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;
    
    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenSize.width * 0.03),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress ?? null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 45,
              child: _buildHeader(context, screenSize),
            ),
            Expanded(
              flex: 55,
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
        if (test.imageUrl != null && test.imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: test.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildHeaderPlaceholder(theme, screenSize),
            errorWidget: (context, url, error) => _buildHeaderPlaceholder(theme, screenSize),
          )
        else
          _buildHeaderPlaceholder(theme, screenSize),
        
        if (canEdit)
          Positioned(
            top: screenSize.height * 0.01,
            right: screenSize.width * 0.02,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(screenSize.width * 0.05),
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: EdgeInsets.all(screenSize.width * 0.015),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
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
          ),
      ],
    );
  }

  Widget _buildHeaderPlaceholder(ThemeData theme, Size screenSize) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
      ),
      child: Center(
        child: Icon(
          test.icon,
          size: screenSize.width * 0.08,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Size screenSize) {
    final contentPadding = screenSize.width * 0.025;
    final spacingUnit = screenSize.height * 0.008;
    final iconSize = screenSize.width * 0.035;
    final titleFontSize = screenSize.width * 0.035;
    final bodyFontSize = screenSize.width * 0.03;
    final chipFontSize = screenSize.width * 0.027;
    
    return Padding(
      padding: EdgeInsets.all(contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title takes the space it needs (up to 2 lines)
          Flexible(
            child: Text(
              test.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: titleFontSize,
                color: theme.colorScheme.onSurface,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          SizedBox(height: spacingUnit),
          
          // Middle section adapts to remaining space
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              child: _buildInfoRow(
                                Icons.schedule_rounded,
                                _formatTimeLimit(test.formattedTimeLimit),
                                theme.colorScheme.onSurfaceVariant,
                                iconSize,
                                bodyFontSize,
                                theme,
                              ),
                            ),
                            
                            if (test.rating > 0)
                              Flexible(
                                child: _buildInfoRow(
                                  Icons.star_rounded,
                                  test.formattedRating,
                                  Colors.amber[600]!,
                                  iconSize,
                                  bodyFontSize,
                                  theme,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: _buildInfoRow(
                            Icons.visibility_rounded,
                            test.formattedViewCount,
                            theme.colorScheme.onSurfaceVariant,
                            iconSize,
                            bodyFontSize,
                            theme,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Category chip at bottom
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.02,
                      vertical: screenSize.height * 0.004,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                    ),
                    child: Text(
                      test.category.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: chipFontSize,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    Color color,
    double iconSize,
    double fontSize,
    ThemeData theme,
  ) {
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

  String _formatTimeLimit(String timeLimit) {
    return timeLimit
        .replaceAll(' min', '분')
        .replaceAll(' hour', '시간')
        .replaceAll(' hours', '시간')
        .replaceAll(' minutes', '분');
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