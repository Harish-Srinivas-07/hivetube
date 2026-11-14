import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double none = 0,
      xs = 4,
      sm = 8,
      md = 12,
      libraryThumbnail = 10,
      lg = 16,
      profileChip = 18,
      xl = 24,
      pill = 999;

  // Flat BorderRadius constants (all corners equal)
  static const noneBorder = BorderRadius.zero;
  static const xsBorder = BorderRadius.all(Radius.circular(xs));
  static const smBorder = BorderRadius.all(Radius.circular(sm));
  static const mdBorder = BorderRadius.all(Radius.circular(md));
  static const libraryThumbnailBorder = BorderRadius.all(
    Radius.circular(libraryThumbnail),
  );
  static const profileChipBorder = BorderRadius.all(
    Radius.circular(profileChip),
  );
  static const lgBorder = BorderRadius.all(Radius.circular(lg));
  static const xlBorder = BorderRadius.all(Radius.circular(xl));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));

  // Sheet top-only radius (bottom corners stay square for bottom sheets)
  static const sheetTopBorder = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
  );

  // Card thumbnail in grids (top corners only — bottom aligns with text block)
  static const thumbnailTopBorder = BorderRadius.only(
    topLeft: Radius.circular(md),
    topRight: Radius.circular(md),
  );
}
