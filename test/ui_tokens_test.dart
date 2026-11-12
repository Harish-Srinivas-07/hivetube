import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/theme/app_layout.dart';
import 'package:hivetube/theme/app_motion.dart';
import 'package:hivetube/theme/app_radius.dart';
import 'package:hivetube/theme/app_sizes.dart';
import 'package:hivetube/theme/app_spacing.dart';

void main() {
  group('UI Design Tokens Guard', () {
    test('AppSpacing follows 4-pt grid tokens', () {
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xxl, 32.0);
      expect(AppSpacing.xxxl, 48.0);
    });

    test('AppRadius defines soft consistent scales', () {
      expect(AppRadius.xs, 4.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 24.0);
      expect(AppRadius.pill, 999.0);
    });

    test('AppSizes defines accessibility minimums and control standards', () {
      expect(AppSizes.touchMin, greaterThanOrEqualTo(48.0));
      expect(AppSizes.chipHeight, 36.0);
      expect(AppSizes.buttonHeight, 44.0);
      expect(AppSizes.iconSm, 18.0);
      expect(AppSizes.icon, 24.0);
      expect(AppSizes.iconLg, 32.0);
      expect(AppSizes.avatar, 40.0);
    });

    test('AppMotion durations follow consistent progression', () {
      expect(AppMotion.fast < AppMotion.base, isTrue);
      expect(AppMotion.base < AppMotion.slow, isTrue);
      expect(AppMotion.slow <= AppMotion.page, isTrue);
      expect(AppMotion.page < AppMotion.feedback, isTrue);
    });

    test('AppLayout constants are consistent', () {
      expect(AppLayout.sectionGap, 24.0);
      expect(AppLayout.itemGap, 12.0);
      expect(AppLayout.cardPadding, 12.0);
      expect(AppLayout.sheetPadding, 20.0);
    });

    test('Screen files avoid raw BorderRadius.circular magic literals', () {
      final libDir = Directory('lib/features');
      if (!libDir.existsSync()) return;

      final radiusPattern = RegExp(r'BorderRadius\.circular\(\s*\d+\s*\)');
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (radiusPattern.hasMatch(lines[i])) {
            violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Screens should use AppRadius tokens instead of raw BorderRadius.circular literals:\n${violations.join('\n')}',
      );
    });
  });
}

