import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'app_buttons.dart';

/// The shared "there is nothing here" panel.
///
/// Every empty, error and no-results state in the app uses this, so a user who
/// learns to read one has learned to read them all. Scrollable by default
/// because the largest system font sizes can push the illustration, copy and
/// button past a short viewport.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: iconBackground ?? AppColors.badge,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The pale-amber notice used for guest mode and other standing explanations.
/// Carries an icon as well as colour so it does not depend on hue alone.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.badge.withValues(alpha: 0.55),
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.badge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.primaryDeep),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.82),
                    height: 1.5,
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: GestureDetector(
                      onTap: onAction,
                      child: Container(
                        // Keeps the tap target at 48dp without visibly padding
                        // the link away from its sentence.
                        constraints: const BoxConstraints(minHeight: 40),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          actionLabel!,
                          style: text.labelLarge?.copyWith(
                            fontSize: 14,
                            color: AppColors.primaryDeep,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryDeep,
                          ),
                        ),
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
}
