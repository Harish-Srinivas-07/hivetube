import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/main.dart';

void main() {
  final outDir = Directory('docs/ui_audit/after');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final devices = [
    (name: 'phone_360x800', size: const Size(360, 800)),
    (name: 'phone_412x915', size: const Size(412, 915)),
    (name: 'tablet_834x1194', size: const Size(834, 1194)),
    (name: 'desktop_1280x800', size: const Size(1280, 800)),
  ];

  final themes = [
    (name: 'dark', brightness: Brightness.dark),
    (name: 'light', brightness: Brightness.light),
  ];

  final textScales = [1.0, 1.3];

  final routes = [
    (name: 'home', path: '/home'),
    (name: 'shorts', path: '/shorts'),
    (name: 'subscriptions', path: '/subscriptions'),
    (name: 'library', path: '/library'),
    (name: 'settings', path: '/settings'),
  ];

  group('UI Multi-device Golden & Overflow Verification', () {
    for (final dev in devices) {
      for (final th in themes) {
        for (final scale in textScales) {
          testWidgets('${dev.name} ${th.name} scale_$scale full screen audit', (tester) async {
            tester.view.physicalSize = dev.size;
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.platformBrightnessTestValue = th.brightness;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

            final db = AppDb(NativeDatabase.memory());
            addTearDown(db.close);

            int overflowErrors = 0;
            final prevOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.exceptionAsString().contains('overflowed') ||
                  details.exceptionAsString().contains('RenderFlex')) {
                overflowErrors++;
              }
              prevOnError?.call(details);
            };

            for (final r in routes) {
              appRouter.go(r.path);

              final repaintKey = GlobalKey();
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [dbProvider.overrideWithValue(db)],
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: dev.size,
                      textScaler: TextScaler.linear(scale),
                      platformBrightness: th.brightness,
                    ),
                    child: RepaintBoundary(
                      key: repaintKey,
                      child: const HiveTubeApp(),
                    ),
                  ),
                ),
              );

              await tester.pump(const Duration(milliseconds: 300));

              // Capture image for screenshot documentation
              try {
                final ro = repaintKey.currentContext?.findRenderObject();
                if (ro is RenderRepaintBoundary) {
                  final image = await ro.toImage(pixelRatio: 1.0);
                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  if (byteData != null) {
                    final filename = '${dev.name}_${th.name}_scale${scale}_${r.name}.png';
                    File('${outDir.path}/$filename').writeAsBytesSync(byteData.buffer.asUint8List());
                  }
                }
              } catch (_) {}
            }

            FlutterError.onError = prevOnError;
            expect(overflowErrors, 0, reason: 'RenderFlex overflow detected on ${dev.name} ${th.name} scale $scale');
          });
        }
      }
    }
  });
}

