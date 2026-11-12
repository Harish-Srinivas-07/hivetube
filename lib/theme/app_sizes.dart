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

  // Controls
  static const double chipHeight = 36;
  static const double buttonHeight = 44;
  static const double appBarHeight = 56;
  static const double miniPlayerHeightFraction = 0.55; // fraction of screen width

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

  // Shorts
  static const double shortsRailWidth = 64;
  static const double shortsRailIconSize = 28;
}

