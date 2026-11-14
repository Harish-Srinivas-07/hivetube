import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const feedTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
  static const feedMeta = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
  static const homeShelfTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const homeShortTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static const displayLarge = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
  );
  static const headline = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
  );
  static const title = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
  );
  static const titleSmall = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );
  static const profileName = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );
  static const libraryRowTitle = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
  );
  static const body = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
  );
  static const bodySmall = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
  );
  static const label = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );
  static const chipLabel = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );
  static const buttonLabel = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );
  static const caption = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
  );
}
