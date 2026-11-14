import 'package:flutter/material.dart';

/// Animation duration and curve tokens.
/// All motion in the app should use these — no raw Duration / Curves literals outside lib/theme/.
abstract final class AppMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration imageFade = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 350);
  static const Duration feedback = Duration(milliseconds: 650);
  static const Duration snackbar = Duration(seconds: 4);
  static const Duration pulse = Duration(milliseconds: 1000);
  static const Duration shimmer = Duration(milliseconds: 1200);
  static const Duration shimmerLoop = shimmer;

  // Curves
  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;

  // Composed
  static final enterCurve = CurveTween(curve: enter);
  static final exitCurve = CurveTween(curve: exit);
}
