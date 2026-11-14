import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/widgets/sheets/app_sheet.dart';

void main() {
  testWidgets('fullscreen sheet is capped and bottom anchored', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
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
                    children: [AppSheetRow(label: 'Queue item')],
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
    expect(rect.width, lessThanOrEqualTo(480));
    expect(rect.width, 480);
    expect(rect.bottom, 360);
    expect(tester.takeException(), isNull);
  });
}
