import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/widgets/sheets/app_sheet.dart';

void main() {
  testWidgets('fit sheet fills width and ends above bottom safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  fit: true,
                  showClose: false,
                  builder: (_, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 4; i++) AppSheetRow(label: 'Row $i'),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('appSheetSurface')));
    expect(rect.width, 400);
    expect(rect.bottom, 776);
  });
}
