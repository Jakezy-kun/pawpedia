import 'package:flutter/material.dart';

/// The PawPedia palette. Every colour in the app comes from here — no literal
/// `Color(0x...)` values anywhere else.
abstract final class AppColors {
  /// Warm amber. Primary actions, active states, brand marks.
  static const Color primary = Color(0xFFE8A33D);

  /// A deeper amber used for text *on* pale amber surfaces, where the primary
  /// amber alone would not clear WCAG AA against `badge`.
  static const Color primaryDeep = Color(0xFF9C6408);

  /// Soft cream page background.
  static const Color background = Color(0xFFFDF8F0);

  /// Cards, sheets, nav bars.
  static const Color surface = Color(0xFFFFFFFF);

  /// Dark slate. Headings and body copy.
  static const Color textPrimary = Color(0xFF2E2E2E);

  /// Warm grey. Supporting copy, captions, inactive labels.
  static const Color textSecondary = Color(0xFF8A8175);

  /// Soft red. Destructive actions only.
  static const Color destructive = Color(0xFFD9534F);

  /// Pale amber. Badge and chip backgrounds, icon tiles, info banners.
  static const Color badge = Color(0xFFFBEBD2);

  /// Hairline borders on outlined chips, fields and dividers.
  static const Color border = Color(0xFFEFE7DA);

  /// Placeholder block while an image or row is loading.
  static const Color skeleton = Color(0xFFF1EAE0);

  /// The single card shadow used across the app: low opacity, large blur.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F2E2E2E),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// A slightly lifted shadow for floating controls (hero back button, FABs).
  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x1F2E2E2E),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}
