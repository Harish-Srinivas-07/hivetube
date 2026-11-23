import 'package:material_ui/material_ui.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/update/update_controller.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/features/settings/about_screen.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _CheckingUpdate extends UpdateController {
  @override
  UpdateState build() => const UpdateChecking();
}

class _CountingUpdate extends UpdateController {
  int checks = 0;
  @override
  UpdateState build() => const UpdateIdle();
  @override
  Future<void> check({bool manual = false}) async => checks++;
}

void main() {
  testWidgets('automatic update check waits for an available connection', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'HiveTube',
      packageName: 'com.hiveminds.hivetube',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    for (final connection in [
      ConnectivityResult.none,
      ConnectivityResult.wifi,
    ]) {
      final container = ProviderContainer(
        overrides: [
          connectivityProvider.overrideWith(
            (ref) => Stream.value([connection]),
          ),
          updateControllerProvider.overrideWith(_CountingUpdate.new),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AboutScreen()),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        (container.read(updateControllerProvider.notifier) as _CountingUpdate)
            .checks,
        connection == ConnectivityResult.none ? 0 : 1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });
  testWidgets('about sections align text and use full width separators', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'HiveTube',
      packageName: 'com.hiveminds.hivetube',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [updateControllerProvider.overrideWith(_CheckingUpdate.new)],
        child: const MaterialApp(home: AboutScreen()),
      ),
    );
    await tester.pump();
    final header = find.text('Disclaimer & Legal Notice');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final body = find.textContaining(
      'HiveTube is an independent video player',
      findRichText: true,
    );
    expect(tester.getTopLeft(header).dx, tester.getTopLeft(body).dx);
    final separators = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.width == double.infinity &&
          widget.height == AppSpacing.borderWidth,
    );
    expect(separators, findsWidgets);
    expect(
      tester.getSize(separators.first).width,
      tester.getSize(find.byType(Scaffold)).width,
    );
    expect(find.textContaining('•', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
