import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Shared height for every full-width button. Comfortably above the 48dp
/// minimum touch target, and tall enough that a large system font still fits.
const double _kButtonHeight = 56;

/// The filled amber call to action. One per screen.
///
/// Text on amber is dark slate, not white: amber is a light colour and white
/// on it fails WCAG AA badly.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    final Widget button = SizedBox(
      height: _kButtonHeight,
      width: expand ? double.infinity : null,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.textPrimary.withValues(alpha: 0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonR),
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: isLoading
            ? const _ButtonSpinner(color: AppColors.textPrimary)
            : _ButtonLabel(label: label, icon: icon),
      ),
    );

    // The spinner replaces the label, so screen readers need to be told the
    // button is busy rather than silently renamed.
    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, in progress' : label,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// White, outlined. Secondary actions such as "Log out".
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, in progress' : label,
      excludeSemantics: true,
      child: SizedBox(
        height: _kButtonHeight,
        width: expand ? double.infinity : null,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonR),
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: isLoading
              ? const _ButtonSpinner(color: AppColors.textPrimary)
              : _ButtonLabel(label: label, icon: icon),
        ),
      ),
    );
  }
}

/// Filled red. Only for actions that destroy data.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, in progress' : label,
      excludeSemantics: true,
      child: SizedBox(
        height: _kButtonHeight,
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.destructive,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.destructive.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonR),
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: isLoading
              ? const _ButtonSpinner(color: Colors.white)
              : _ButtonLabel(label: label, icon: icon),
        ),
      ),
    );
  }
}

/// A plain text button. Used for "Cancel" and other low-emphasis escapes,
/// which should stay visually easier to reach than the destructive path.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.bold = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.textPrimary,
        minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonR),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color ?? AppColors.textPrimary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(label, textAlign: TextAlign.center);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
    );
  }
}
