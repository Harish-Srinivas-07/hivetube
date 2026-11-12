import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, pill = 999;

  // Flat BorderRadius constants (all corners equal)
  static const noneBorder = BorderRadius.zero;
  static const xsBorder = BorderRadius.all(Radius.circular(xs));
  static const smBorder = BorderRadius.all(Radius.circular(sm));
  static const mdBorder = BorderRadius.all(Radius.circular(md));
  static const lgBorder = BorderRadius.all(Radius.circular(lg));
  static const xlBorder = BorderRadius.all(Radius.circular(xl));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));

  // Sheet top-only radius (bottom corners stay square for bottom sheets)
  static const sheetTopBorder = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );

  // Card thumbnail in grids (top corners only — bottom aligns with text block)
  static const thumbnailTopBorder = BorderRadius.only(
    topLeft: Radius.circular(md),
    topRight: Radius.circular(md),
  );
}
