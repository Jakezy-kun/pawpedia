import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for PawPedia: Nunito, a rounded geometric sans that reads as
/// friendly to children without looking childish to adults.
///
/// Sizes are in logical pixels and deliberately *not* scaled by hand — the
/// framework applies the user's text-scale setting on top, so every screen has
/// to survive large system fonts. Layouts wrap rather than truncate for this
/// reason.
abstract final class AppTextStyles {
  static TextTheme get textTheme => TextTheme(
        // H1 — screen titles, breed names on detail.
        displaySmall: GoogleFonts.nunito(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        // H1 compact — used where a title shares space with other chrome.
        headlineMedium: GoogleFonts.nunito(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        // H2 — section headers, card titles.
        titleLarge: GoogleFonts.nunito(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: AppColors.textPrimary,
        ),
        // H3 — list item titles.
        titleMedium: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: AppColors.textPrimary,
        ),
        // Body large — paragraphs.
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.55,
          color: AppColors.textSecondary,
        ),
        // Body — default.
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
        // Buttons.
        labelLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.textPrimary,
        ),
        // Small supporting text.
        labelMedium: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppColors.textSecondary,
        ),
      );

  /// Uppercase, letter-spaced micro-label. "BREED OF THE DAY", "LIFESPAN".
  static TextStyle badgeLabel({Color color = AppColors.textSecondary}) =>
      GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        height: 1.2,
        color: color,
      );

  /// The pill under a breed name on the detail screen: "SPORTING GROUP".
  static TextStyle groupPill() => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        height: 1.2,
        color: AppColors.primaryDeep,
      );
}
