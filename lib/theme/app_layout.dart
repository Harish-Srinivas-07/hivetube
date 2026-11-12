import 'package:flutter/material.dart';

/// Named layout tokens: gutters, section gaps, and max content widths.
/// Use instead of hardcoded padding/margin/gap numbers.
abstract final class AppLayout {
  /// Responsive page gutter — horizontal padding on each side.
  static double pageGutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1024) return 32;
    if (w >= 600) return 24;
    return 16;
  }

  /// Vertical gap between major sections on a screen.
  static const double sectionGap = 24;

  /// Gap between items within a section (cards, tiles).
  static const double itemGap = 12;

  /// Padding inside cards.
  static const double cardPadding = 12;

  /// Padding inside sheets and dialogs.
  static const double sheetPadding = 20;

  /// Maximum content width for a single-column layout.
  static const double maxContentWidth = 840;

  /// Responsive column count for video grid.
  static int gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1200) return 4;
    if (w >= 900) return 3;
    if (w >= 600) return 2;
    return 1;
  }

  /// Whether the layout is wide enough for a side rail.
  static bool hasRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  /// Whether the layout should use two-column panels (watch page).
  static bool hasTwoColumns(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;
}

