import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
  static const xsBorder = BorderRadius.all(Radius.circular(xs));
  static const smBorder = BorderRadius.all(Radius.circular(sm));
  static const mdBorder = BorderRadius.all(Radius.circular(md));
  static const lgBorder = BorderRadius.all(Radius.circular(lg));
  static const xlBorder = BorderRadius.all(Radius.circular(xl));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
}
