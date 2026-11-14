abstract final class AppSpacing {
  // ── 4-pt grid ─────────────────────────────────────────────────────────────
  static const double none = 0,
      xxs = 2,
      xs = 4,
      iconGap = 8,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 24,
      xxl = 32,
      xxxl = 48;

  static const double screenGutter = md, feedCardGap = xl, shelfCardGap = md;

  // ── Video / content geometry ───────────────────────────────────────────────
  static const double videoMaxWidth = 360,
      shortWidth = 128,
      homeShortWidth = 150,
      homeShortRatio = 2 / 3,
      homeTrendingWidth = 280,
      thumbnailRatio = 16 / 9,
      shortRatio = 9 / 16;

  // ── Responsive breakpoints ─────────────────────────────────────────────────
  static const double navigationBreakpoint = 600,
      twoColumnBreakpoint = 1024,
      searchMaxWidth = 640,
      searchHeight = 40;

  // ── Sheet / modal sizes ────────────────────────────────────────────────────
  static const double contentSheetMaxHeightFactor = .85,
      sheetMaxHeightFactor = .9,
      contentSheetMinExtent = .55,
      contentRegionPickerHeightFactor = .65,
      contentSheetHandleWidth = 36,
      contentSheetHandleHeight = 4,
      contentLanguageRowHeight = 54,
      badgeDotSize = 8;

  // ── Glass / visual effects ─────────────────────────────────────────────────
  static const double glassBlur = 20,
      borderWidth = 1,
      glowHeightFactor = 0.35,
      glowRadius = 1.0;

  // ── Component sizes (kept for backward-compat — prefer AppSizes) ───────────
  static const double topButton = 44,
      avatar = 40,
      logoMark = 34,
      navHeight = 60,
      navIcon = 22,
      navItemPadding = 12,
      navDragVelocity = 220,
      progressHeight = 3;

  // ── Home chips ─────────────────────────────────────────────────────────────
  static const double homeChipHeight =
          36, // was 44, now matches AppSizes.chipHeight
      homeChipHorizontalPadding = 16,
      homeMoreIcon = 24,
      homeInlineIconSize = 18,
      homeInlineButtonSize = 36;

  // ── Shorts player ─────────────────────────────────────────────────────────
  static const double shortsRailWidth = 64,
      shortsRailIcon = 28,
      shortsScrimHeight = 280,
      shortsTopIcon = 44,
      shortsProgressTouchHeight = 24,
      shortsProgressIdleHeight = 2,
      shortsProgressActiveHeight = 6,
      shortsAspectTolerance = 0.08,
      shortsFeedbackScale = 0.14,
      shortsWheelThreshold = 24,
      shortsFeedbackIcon = 64,
      shortsHeartIcon = 88,
      cardInfoHeight = 112;

  // ── Lead items on Home feed ────────────────────────────────────────────────
  static const int homeLeadItems = 6;

  // ── Canonical animation durations (prefer AppMotion) ──────────────────────
  static const Duration shortsFeedbackDuration = Duration(milliseconds: 650),
      shortsPageDuration = Duration(milliseconds: 300),
      navAnimationDuration = Duration(milliseconds: 320);
}
