import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// The amber paw mark plus the PawPedia wordmark, as shown on Onboarding and
/// the auth screen.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.showWordmark = true, this.size = 36});

  final bool showWordmark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PawPedia',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: size,
            width: size,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets_rounded,
              size: size * 0.55,
              color: AppColors.textPrimary,
            ),
          ),
          if (showWordmark) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Text(
              'PawPedia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A circular white icon button used as a floating back control, both over
/// photos (Breed Detail) and on plain backgrounds (auth).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.iconColor = AppColors.textPrimary,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: AppSpacing.minTouchTarget,
        width: AppSpacing.minTouchTarget,
        child: Center(
          child: Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: size,
                width: size,
                child: Icon(icon, size: size * 0.45, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
