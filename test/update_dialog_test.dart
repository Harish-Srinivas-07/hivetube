import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/update/update_service.dart';
import 'package:hivetube/widgets/update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('release notes render Markdown in the update dialog', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'HiveTube',
      packageName: 'com.hiveminds.hivetube',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final info = UpdateInfo(
      available: true,
      version: '1.1.0',
      releaseUrl: Uri.parse(
        'https://github.com/example/repo/releases/tag/v1.1.0',
      ),
      apkUrl: null,
      apkSize: null,
      changelog:
          '## Improvements\n\n- **Faster** playback\n- [Details](https://example.com)',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showUpdateDialog(context, ref, info),
                child: const Text('Open update'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open update'));
    await tester.pumpAndSettle();
    expect(find.text('What’s new'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    final rendered = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((text) => text.text.toPlainText());
    expect(rendered, contains('Improvements'));
    expect(rendered.any((text) => text.contains('Faster playback')), isTrue);
    expect(rendered.any((text) => text.contains('**Faster**')), isFalse);
  });
}
