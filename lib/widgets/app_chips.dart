import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// A selectable pill, used for breed groups and origin countries.
///
/// Selection is signalled by fill, border weight *and* a checkmark on
/// multi-select, never by colour alone — colour-blind users and anyone on a
/// washed-out screen get the same information.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.showCheckWhenSelected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional count badge, as on the Explore group chips ("Sporting 2").
  final int? count;

  /// Multi-select chips add a tick so selection is not colour-only.
  final bool showCheckWhenSelected;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count breeds',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected && showCheckWhenSelected) ...<Widget>[
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: text.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? AppColors.textPrimary : AppColors.textPrimary,
                  ),
                ),
                if (count != null) ...<Widget>[
                  const SizedBox(width: 7),
                  Text(
                    '$count',
                    style: text.labelMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.textPrimary.withValues(alpha: 0.65)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only outlined pill for one temperament trait.
class TemperamentChip extends StatelessWidget {
  const TemperamentChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
      ),
    );
  }
}

/// The small pale-amber badge used on breed cards for a single trait, and on
/// the detail screen for the breed group.
class AmberBadge extends StatelessWidget {
  const AmberBadge({
    super.key,
    required this.label,
    this.uppercase = false,
    this.letterSpacing,
  });

  final String label;
  final bool uppercase;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: uppercase ? 14 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.badge,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: uppercase ? 11 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: letterSpacing ?? (uppercase ? 1.0 : 0),
              // The deeper amber is what clears AA against the pale badge fill.
              color: AppColors.primaryDeep,
            ),
      ),
    );
  }
}
