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

// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:korean_language_app/shared/enums/test_category.dart';
// import 'package:korean_language_app/shared/models/test_item.dart';

// class TestCard extends StatefulWidget {
//   final TestItem test;
//   final bool canEdit;
//   final VoidCallback onTap;
//   final VoidCallback? onLongPress;
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;
//   final VoidCallback? onViewDetails;

//   const TestCard({
//     super.key,
//     required this.test,
//     required this.canEdit,
//     required this.onTap,
//     this.onLongPress,
//     this.onEdit,
//     this.onDelete,
//     this.onViewDetails,
//   });

//   @override
//   State<TestCard> createState() => _TestCardState();
// }

// class _TestCardState extends State<TestCard> with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;
//   bool _isPressed = false;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 150),
//       vsync: this,
//     );
//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 0.95,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     ));
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   void _handleTapDown(TapDownDetails details) {
//     setState(() => _isPressed = true);
//     _animationController.forward();
//   }

//   void _handleTapUp(TapUpDetails details) {
//     setState(() => _isPressed = false);
//     _animationController.reverse();
//   }

//   void _handleTapCancel() {
//     setState(() => _isPressed = false);
//     _animationController.reverse();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//     final screenSize = MediaQuery.of(context).size;
    
//     return AnimatedBuilder(
//       animation: _scaleAnimation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _scaleAnimation.value,
//           child: Container(
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(screenSize.width * 0.04),
//               boxShadow: [
//                 BoxShadow(
//                   color: colorScheme.shadow.withValues(alpha: _isPressed ? 0.1 : 0.15),
//                   blurRadius: _isPressed ? 4 : 8,
//                   offset: Offset(0, _isPressed ? 2 : 4),
//                 ),
//               ],
//             ),
//             child: Material(
//               color: colorScheme.surface,
//               borderRadius: BorderRadius.circular(screenSize.width * 0.04),
//               clipBehavior: Clip.antiAlias,
//               child: InkWell(
//                 onTap: widget.onTap,
//                 onLongPress: widget.onLongPress,
//                 onTapDown: _handleTapDown,
//                 onTapUp: _handleTapUp,
//                 onTapCancel: _handleTapCancel,
//                 splashColor: colorScheme.primary.withValues(alpha: 0.1),
//                 highlightColor: colorScheme.primary.withValues(alpha: 0.05),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Expanded(
//                       flex: 40,
//                       child: _buildHeader(context, screenSize),
//                     ),
//                     Expanded(
//                       flex: 60,
//                       child: _buildContent(context, theme, screenSize),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildHeader(BuildContext context, Size screenSize) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
    
//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         if (widget.test.imageUrl != null && widget.test.imageUrl!.isNotEmpty)
//           ClipRRect(
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(screenSize.width * 0.04),
//               topRight: Radius.circular(screenSize.width * 0.04),
//             ),
//             child: CachedNetworkImage(
//               imageUrl: widget.test.imageUrl!,
//               fit: BoxFit.cover,
//               placeholder: (context, url) => _buildImagePlaceholder(theme, screenSize),
//               errorWidget: (context, url, error) => _buildImagePlaceholder(theme, screenSize),
//             ),
//           )
//         else
//           _buildImagePlaceholder(theme, screenSize),
        
//         // Gradient overlay for better text readability
//         Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [
//                 Colors.black.withValues(alpha: 0.2),
//                 Colors.transparent,
//                 Colors.black.withValues(alpha: 0.3),
//               ],
//               stops: const [0.0, 0.5, 1.0],
//             ),
//           ),
//         ),
        
//         // Rating badge in top-left
//         if (widget.test.rating > 0)
//           Positioned(
//             top: screenSize.height * 0.012,
//             left: screenSize.width * 0.03,
//             child: Container(
//               padding: EdgeInsets.symmetric(
//                 horizontal: screenSize.width * 0.02,
//                 vertical: screenSize.height * 0.004,
//               ),
//               decoration: BoxDecoration(
//                 color: Colors.amber.withValues(alpha: 0.9),
//                 borderRadius: BorderRadius.circular(screenSize.width * 0.03),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     Icons.star_rounded,
//                     color: Colors.white,
//                     size: screenSize.width * 0.03,
//                   ),
//                   SizedBox(width: screenSize.width * 0.01),
//                   Text(
//                     widget.test.formattedRating,
//                     style: theme.textTheme.labelSmall?.copyWith(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w600,
//                       fontSize: screenSize.width * 0.025,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
        
//         if (widget.canEdit)
//           Positioned(
//             top: screenSize.height * 0.012,
//             right: screenSize.width * 0.03,
//             child: _buildMenuButton(context, screenSize),
//           ),
//       ],
//     );
//   }

//   Widget _buildImagePlaceholder(ThemeData theme, Size screenSize) {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             theme.colorScheme.primary,
//             theme.colorScheme.primary.withValues(alpha: 0.8),
//           ],
//         ),
//       ),
//       child: Center(
//         child: Container(
//           padding: EdgeInsets.all(screenSize.width * 0.04),
//           decoration: BoxDecoration(
//             color: Colors.white.withValues(alpha: 0.15),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(
//             widget.test.icon,
//             size: screenSize.width * 0.08,
//             color: Colors.white,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildMenuButton(BuildContext context, Size screenSize) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.black.withValues(alpha: 0.3),
//         shape: BoxShape.circle,
//       ),
//       child: PopupMenuButton<String>(
//         icon: Icon(
//           Icons.more_vert_rounded,
//           color: Colors.white,
//           size: screenSize.width * 0.045,
//         ),
//         onSelected: (value) => _handleMenuAction(context, value),
//         itemBuilder: (context) => _buildMenuItems(context),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(screenSize.width * 0.03),
//         ),
//         position: PopupMenuPosition.under,
//       ),
//     );
//   }

//   Widget _buildContent(BuildContext context, ThemeData theme, Size screenSize) {
//     final contentPadding = screenSize.width * 0.04;
//     final spacingUnit = screenSize.height * 0.01;
    
//     return Padding(
//       padding: EdgeInsets.all(contentPadding),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Title section
//           Text(
//             widget.test.title,
//             style: theme.textTheme.titleMedium?.copyWith(
//               fontWeight: FontWeight.w700,
//               fontSize: screenSize.width * 0.04,
//               color: theme.colorScheme.onSurface,
//               height: 1.3,
//             ),
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//           ),
          
//           SizedBox(height: spacingUnit),
          
//           // Stats section
//           Expanded(
//             child: Column(
//               children: [
//                 // Time and views row
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _buildStatChip(
//                         Icons.schedule_rounded,
//                         _formatTimeLimit(widget.test.formattedTimeLimit),
//                         theme.colorScheme.secondary,
//                         theme,
//                         screenSize,
//                       ),
//                     ),
//                     SizedBox(width: screenSize.width * 0.02),
//                     Expanded(
//                       child: _buildStatChip(
//                         Icons.visibility_rounded,
//                         widget.test.formattedViewCount,
//                         theme.colorScheme.tertiary,
//                         theme,
//                         screenSize,
//                       ),
//                     ),
//                   ],
//                 ),
                
//                 const Spacer(),
                
//                 // Category chip at bottom
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Container(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: screenSize.width * 0.03,
//                           vertical: screenSize.height * 0.008,
//                         ),
//                         decoration: BoxDecoration(
//                           color: theme.colorScheme.primaryContainer,
//                           borderRadius: BorderRadius.circular(screenSize.width * 0.04),
//                           border: Border.all(
//                             color: theme.colorScheme.primary.withValues(alpha: 0.2),
//                             width: 1,
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               Icons.category_rounded,
//                               size: screenSize.width * 0.035,
//                               color: theme.colorScheme.onPrimaryContainer,
//                             ),
//                             SizedBox(width: screenSize.width * 0.015),
//                             Flexible(
//                               child: Text(
//                                 widget.test.category.displayName,
//                                 style: theme.textTheme.labelMedium?.copyWith(
//                                   color: theme.colorScheme.onPrimaryContainer,
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: screenSize.width * 0.03,
//                                 ),
//                                 overflow: TextOverflow.ellipsis,
//                                 maxLines: 1,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatChip(
//     IconData icon,
//     String text,
//     Color color,
//     ThemeData theme,
//     Size screenSize,
//   ) {
//     return Container(
//       padding: EdgeInsets.symmetric(
//         horizontal: screenSize.width * 0.025,
//         vertical: screenSize.height * 0.006,
//       ),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(screenSize.width * 0.025),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             icon,
//             size: screenSize.width * 0.035,
//             color: color,
//           ),
//           SizedBox(width: screenSize.width * 0.015),
//           Flexible(
//             child: Text(
//               text,
//               style: theme.textTheme.bodySmall?.copyWith(
//                 color: color,
//                 fontWeight: FontWeight.w600,
//                 fontSize: screenSize.width * 0.028,
//               ),
//               overflow: TextOverflow.ellipsis,
//               maxLines: 1,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // IconData _getCategoryIcon(TestCategory category) {
//   //   switch (category) {
//   //     case TestCategory.:
//   //       return Icons.auto_stories_rounded;
//   //     case TestCategory.vocabulary:
//   //       return Icons.translate_rounded;
//   //     case TestCategory.listening:
//   //       return Icons.hearing_rounded;
//   //     case TestCategory.reading:
//   //       return Icons.menu_book_rounded;
//   //     case TestCategory.writing:
//   //       return Icons.edit_rounded;
//   //     case TestCategory.speaking:
//   //       return Icons.record_voice_over_rounded;
//   //     default:
//   //       return Icons.quiz_rounded;
//   //   }
//   // }

//   String _formatTimeLimit(String timeLimit) {
//     return timeLimit
//         .replaceAll(' min', '분')
//         .replaceAll(' hour', '시간')
//         .replaceAll(' hours', '시간')
//         .replaceAll(' minutes', '분');
//   }

//   List<PopupMenuItem<String>> _buildMenuItems(BuildContext context) {
//     final theme = Theme.of(context);
//     final List<PopupMenuItem<String>> menuItems = [
//       PopupMenuItem<String>(
//         value: 'start',
//         child: Row(
//           children: [
//             Icon(Icons.play_arrow_rounded, size: 20, color: theme.colorScheme.primary),
//             const SizedBox(width: 12),
//             const Text('Start Test'),
//           ],
//         ),
//       ),
//       const PopupMenuItem<String>(
//         value: 'details',
//         child: Row(
//           children: [
//             Icon(Icons.info_outline_rounded, size: 20),
//             SizedBox(width: 12),
//             Text('View Details'),
//           ],
//         ),
//       ),
//     ];
    
//     if (widget.canEdit) {
//       if (widget.onEdit != null) {
//         menuItems.add(const PopupMenuItem<String>(
//           value: 'edit',
//           child: Row(
//             children: [
//               Icon(Icons.edit_rounded, size: 20),
//               SizedBox(width: 12),
//               Text('Edit'),
//             ],
//           ),
//         ));
//       }
      
//       if (widget.onDelete != null) {
//         menuItems.add(PopupMenuItem<String>(
//           value: 'delete',
//           child: Row(
//             children: [
//               Icon(
//                 Icons.delete_outline_rounded, 
//                 size: 20, 
//                 color: theme.colorScheme.error,
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Delete',
//                 style: TextStyle(color: theme.colorScheme.error),
//               ),
//             ],
//           ),
//         ));
//       }
//     }
    
//     return menuItems;
//   }

//   void _handleMenuAction(BuildContext context, String value) {
//     switch (value) {
//       case 'start':
//         widget.onTap();
//         break;
//       case 'details':
//         if (widget.onViewDetails != null) widget.onViewDetails!();
//         break;
//       case 'edit':
//         if (widget.onEdit != null) widget.onEdit!();
//         break;
//       case 'delete':
//         if (widget.onDelete != null) widget.onDelete!();
//         break;
//     }
//   }
// }