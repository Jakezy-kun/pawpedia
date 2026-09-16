import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// The favourite toggle, in a white circle so it stays legible on top of any
/// photo.
///
/// Filled-vs-outlined carries the state as well as the colour change, so it
/// still reads when hue is unavailable. The label announced to screen readers
/// is the action ("Add to favorites"), not the state, because that is what
/// activating it will do.
class HeartButton extends StatelessWidget {
  const HeartButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.breedName,
    this.size = 44,
    this.busy = false,
  });

  final bool isFavorite;
  final VoidCallback onTap;
  final String? breedName;
  final double size;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final String subject = breedName == null ? '' : ' $breedName';
    final String label = isFavorite
        ? 'Remove$subject from favorites'
        : 'Add$subject to favorites';

    return Semantics(
      button: true,
      toggled: isFavorite,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        // The visual circle can be smaller than 48dp; the tap target cannot.
        height: AppSpacing.minTouchTarget,
        width: AppSpacing.minTouchTarget,
        child: Center(
          child: Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onTap();
                    },
              child: SizedBox(
                height: size,
                width: size,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) =>
                                  ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey<bool>(isFavorite),
                            size: size * 0.5,
                            color: isFavorite
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
