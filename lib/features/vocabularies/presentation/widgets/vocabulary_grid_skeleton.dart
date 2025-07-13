import 'package:flutter/material.dart';

class VocabularyGridSkeleton extends StatelessWidget {
  const VocabularyGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const VocabularyCardSkeleton();
      },
    );
  }
}

class VocabularyCardSkeleton extends StatefulWidget {
  const VocabularyCardSkeleton({super.key});

  @override
  State<VocabularyCardSkeleton> createState() => _VocabularyCardSkeletonState();
}

class _VocabularyCardSkeletonState extends State<VocabularyCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _getSkeletonColor(context, _animation.value),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          height: 20,
                          width: 60,
                          decoration: BoxDecoration(
                            color: _getSkeletonColor(context, _animation.value, isOverlay: true),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          height: 16,
                          width: 40,
                          decoration: BoxDecoration(
                            color: _getSkeletonColor(context, _animation.value, isOverlay: true),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: _getSkeletonColor(context, _animation.value, isOverlay: true),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                            color: _getSkeletonColor(context, _animation.value, isOverlay: true),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _getSkeletonColor(context, _animation.value),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: double.infinity * 0.8,
                        decoration: BoxDecoration(
                          color: _getSkeletonColor(context, _animation.value),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Container(
                            height: 8,
                            width: 12,
                            decoration: BoxDecoration(
                              color: _getSkeletonColor(context, _animation.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            height: 8,
                            width: 20,
                            decoration: BoxDecoration(
                              color: _getSkeletonColor(context, _animation.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 8,
                            width: 12,
                            decoration: BoxDecoration(
                              color: _getSkeletonColor(context, _animation.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            height: 8,
                            width: 25,
                            decoration: BoxDecoration(
                              color: _getSkeletonColor(context, _animation.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 6),
                      
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _getSkeletonColor(context, _animation.value),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 8,
                              width: double.infinity * 0.7,
                              decoration: BoxDecoration(
                                color: _getSkeletonColor(context, _animation.value),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 12,
                            width: 30,
                            decoration: BoxDecoration(
                              color: _getSkeletonColor(context, _animation.value),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                height: 8,
                                width: 8,
                                decoration: BoxDecoration(
                                  color: _getSkeletonColor(context, _animation.value),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                height: 8,
                                width: 20,
                                decoration: BoxDecoration(
                                  color: _getSkeletonColor(context, _animation.value),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getSkeletonColor(BuildContext context, double animationValue, {bool isOverlay = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isOverlay) {
      if (isDark) {
        return Color.lerp(
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.15),
          animationValue,
        )!;
      } else {
        return Color.lerp(
          Colors.black.withValues(alpha: 0.06),
          Colors.black.withValues(alpha: 0.12),
          animationValue,
        )!;
      }
    }
    
    if (isDark) {
      return Color.lerp(
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        animationValue,
      )!;
    } else {
      return Color.lerp(
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        animationValue,
      )!;
    }
  }
}