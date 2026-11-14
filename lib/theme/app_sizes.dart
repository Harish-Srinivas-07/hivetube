/// Named size tokens for consistent touch targets, icons, avatars, and controls.
/// Nothing in lib/ outside lib/theme/ should use raw numeric sizes.
abstract final class AppSizes {
  // Touch targets (minimum 48 for accessibility)
  static const double touchMin = 48;

  // Icons
  static const double iconXs = 16;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double icon = 24;
  static const double iconLg = 32;

  // Avatars
  static const double avatarXs = 20;
  static const double avatarSm = 28;
  static const double avatar = 40;
  static const double avatarLg = 72;
  static const double searchResultAvatar = 36;
  static const double libraryHistoryCardWidth = 160;
  static const double libraryRowHeight = 52;

  // Controls
  static const double chipHeight = 36;
  static const double chipHeightCompact = 32;
  static const double buttonCompact = 36;
  static const double buttonStandard = 40;
  static const double buttonLarge = 48;
  static const double buttonIcon = 40;
  static const double buttonIconTouch = 48;
  static const double buttonHeight = 44;
  static const double textFieldHeight = 44;
  static const double popupMenuItemHeight = 48;
  static const double appBarHeight = 56;
  static const double sheetHeaderHeight = 56;
  static const double sheetHandleWidth = 32;
  static const double sheetHandleHeight = 4;
  static const double sheetMaxWidth = 640;
  static const double sheetCardMaxWidth = 480;
  static const double snackbarMaxWidth = 560;
  static const double miniPlayerHeightFraction =
      0.55; // fraction of screen width

  // Icons
  static const double iconInline = 18;

  // Seek bar
  static const double seekBarHeight = 4;
  static const double seekBarThumb = 14;
  static const double seekBarThumbPressed = 20;

  // Cards
  static const double cardThumbRadius = 12; // matches AppRadius.md
  static const double progressBarHeight = 3;

  // Nav / rail
  static const double navHeight = 64;
  static const double navIconSize = 24;
  static const double railWidth = 80;

  // List rows
  static const double listRowHeight = 72;
  static const double settingsRowHeight = 56;
  static const double horizontalThumbCardHeight = 140;
  static const double searchCompactThumbnailWidth = 120;

  // Shorts
  static const double shortsRailWidth = 64;
  static const double shortsRailIconSize = 28;
}
