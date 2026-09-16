import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// A softly pulsing placeholder block.
///
/// Used instead of a bare spinner so the loading state has the shape of the
/// content that is coming, which makes the wait feel shorter and stops the
/// layout jumping when data lands.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": a static block is better than an animation the
    // user has asked the system not to play.
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    final Widget box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      ),
    );

    if (!animate) return box;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: box,
    );
  }
}

/// Skeleton in the shape of a compact breed row, for the Explore list.
class BreedRowSkeleton extends StatelessWidget {
  const BreedRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: <Widget>[
          const SkeletonBox(
            width: 64,
            height: 64,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                SkeletonBox(width: 150, height: 16),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 90, height: 12),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(
                  width: 74,
                  height: 22,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton in the shape of the Breed of the Day hero card.
class FeaturedSkeleton extends StatelessWidget {
  const FeaturedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SkeletonBox(height: 180, borderRadius: BorderRadius.zero),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                SkeletonBox(width: 110, height: 11),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(width: 190, height: 22),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(width: 140, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
