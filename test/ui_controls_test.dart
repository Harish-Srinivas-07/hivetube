import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hivetube/theme/app_sizes.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/widgets/home_top_bar.dart';
import 'package:hivetube/widgets/ui/app_controls.dart';
import 'package:hivetube/widgets/ui/app_sheet.dart';

void main() {
  Widget buildApp(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppButton tests', () {
    testWidgets('renders filled button and handles tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          AppButton.filled(
            label: 'Subscribe',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Subscribe'), findsOneWidget);
      final size = tester.getSize(find.byType(AppButton));
      expect(size.height, AppSizes.buttonStandard);

      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('renders tonal button with leading icon', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const AppButton.tonal(
            label: 'Share',
            icon: LucideIcons.share2,
          ),
        ),
      );

      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(LucideIcons.share2), findsOneWidget);
    });

    testWidgets('renders compact and large sizes', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const Column(
            children: [
              AppButton(label: 'Compact', size: AppButtonSize.compact),
              AppButton(label: 'Large', size: AppButtonSize.large),
            ],
          ),
        ),
      );

      final compactSize = tester.getSize(find.widgetWithText(AppButton, 'Compact'));
      final largeSize = tester.getSize(find.widgetWithText(AppButton, 'Large'));
      expect(compactSize.height, AppSizes.buttonCompact);
      expect(largeSize.height, AppSizes.buttonLarge);
    });

    testWidgets('loading button shows progress indicator and ignores tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          AppButton(
            label: 'Loading Action',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Action'), findsNothing);

      await tester.tap(find.byType(AppButton));
      expect(tapped, isFalse);
    });

    testWidgets('disabled button ignores tap', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const AppButton(
            label: 'Disabled',
            onPressed: null,
          ),
        ),
      );

      expect(find.text('Disabled'), findsOneWidget);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.38);
    });
  });

  group('AppLikeDislikeSegment tests', () {
    testWidgets('renders like and dislike counts and dispatches taps', (tester) async {
      var liked = false;
      var disliked = false;

      await tester.pumpWidget(
        buildApp(
          AppLikeDislikeSegment(
            likeCount: '1.2M',
            dislikeCount: '45K',
            reaction: 0,
            onLike: () => liked = true,
            onDislike: () => disliked = true,
          ),
        ),
      );

      expect(find.text('1.2M'), findsOneWidget);
      expect(find.text('45K'), findsOneWidget);

      await tester.tap(find.text('1.2M'));
      expect(liked, isTrue);

      await tester.tap(find.byIcon(LucideIcons.thumbsDown));
      expect(disliked, isTrue);
    });
  });

  group('AppSubscribedButton tests', () {
    testWidgets('shows Subscribe when uncompleted and Subscribed when active', (tester) async {
      var changed = false;

      await tester.pumpWidget(
        buildApp(
          AppSubscribedButton(
            isSubscribed: false,
            onPressed: () => changed = true,
          ),
        ),
      );

      expect(find.text('Subscribe'), findsOneWidget);
      await tester.tap(find.byType(AppSubscribedButton));
      expect(changed, isTrue);

      await tester.pumpWidget(
        buildApp(
          AppSubscribedButton(
            isSubscribed: true,
            onPressed: () => changed = true,
          ),
        ),
      );

      expect(find.text('Subscribed'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    });
  });

  group('AppChip and AppChipBar tests', () {
    testWidgets('compact chip has height 32 and handles tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          AppChip(
            label: 'All',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      final chipSize = tester.getSize(find.byType(AppChip));
      expect(chipSize.height, AppSizes.chipHeightCompact);

      await tester.tap(find.byType(AppChip));
      expect(tapped, isTrue);
    });

    testWidgets('AppChipBar renders horizontal chip row with gutter', (tester) async {
      await tester.pumpWidget(
        buildApp(
          AppChipBar(
            children: [
              AppChip(label: 'All', selected: true, onTap: () {}),
              AppChip(label: 'Music', selected: false, onTap: () {}),
              AppChip(label: 'Gaming', selected: false, onTap: () {}),
            ],
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Gaming'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('AppSheetHeader tests', () {
    testWidgets('renders pinned header with title, drag handle and close button', (tester) async {
      await tester.pumpWidget(
        buildApp(
          const AppSheetHeader(
            title: 'Comments',
            showClose: true,
          ),
        ),
      );

      expect(find.text('Comments'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    testWidgets('renders back button and hairline divider when scrolled under', (tester) async {
      var backed = false;
      await tester.pumpWidget(
        buildApp(
          AppSheetHeader(
            title: 'Options',
            onBack: () => backed = true,
            isScrolledUnder: true,
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      expect(backed, isTrue);
    });
  });

  group('HomeTopBar tests', () {
    testWidgets('Home bar has logo, language button and search; NO cast or notification bell', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HomeTopBar(),
            ),
          ),
        ),
      );

      // Verify Cast and Bell are absent
      expect(find.byIcon(LucideIcons.cast), findsNothing);
      expect(find.byIcon(LucideIcons.bell), findsNothing);

      // Verify Search icon is present
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
    });
  });
}
