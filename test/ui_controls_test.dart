import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hivetube/theme/app_sizes.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/widgets/content_language_button.dart';
import 'package:hivetube/widgets/hive_logo.dart';
import 'package:hivetube/widgets/home_top_bar.dart';
import 'package:hivetube/widgets/ui/app_controls.dart';
import 'package:hivetube/widgets/ui/app_sheet.dart';

class _LinkPlayerUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState();
}

void main() {
  test('YouTube links accept supported forms and reject unrelated hosts', () {
    expect(
      parseYouTubeLink('https://www.youtube.com/watch?v=abcdefghijk&t=1')?.id,
      'abcdefghijk',
    );
    expect(
      parseYouTubeLink('https://youtu.be/abcdefghijk?si=abc')?.id,
      'abcdefghijk',
    );
    expect(
      parseYouTubeLink('https://m.youtube.com/shorts/abcdefghijk')?.isShort,
      isTrue,
    );
    expect(
      parseYouTubeLink('https://youtube.com.evil.test/watch?v=abcdefghijk'),
      isNull,
    );
    expect(parseYouTubeLink('https://youtube.com/watch?v=bad'), isNull);
  });

  testWidgets('link dialog validates and opens videos and Shorts', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [playerUiProvider.overrideWith(_LinkPlayerUi.new)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HomeTopBar()),
        ),
        GoRoute(
          path: '/shorts',
          builder: (_, _) => const Scaffold(body: Text('Shorts route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.byTooltip('Open YouTube link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.com/watch?v=abcdefghijk',
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.text('Enter a valid YouTube video link'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/abcdefghijk',
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(container.read(watchPanelProvider), 'abcdefghijk');
    await tester.tap(find.byTooltip('Open YouTube link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://youtube.com/shorts/12345678901',
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      container.read(shortsSelectionProvider).items.single.id,
      '12345678901',
    );
    expect(container.read(watchPanelProvider), isNull);
    expect(find.text('Shorts route'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
          AppButton.filled(label: 'Subscribe', onPressed: () => tapped = true),
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
          const AppButton.tonal(label: 'Share', icon: LucideIcons.share2),
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

      final compactSize = tester.getSize(
        find.widgetWithText(AppButton, 'Compact'),
      );
      final largeSize = tester.getSize(find.widgetWithText(AppButton, 'Large'));
      expect(compactSize.height, AppSizes.buttonCompact);
      expect(largeSize.height, AppSizes.buttonLarge);
    });

    testWidgets('loading button shows progress indicator and ignores tap', (
      tester,
    ) async {
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
        buildApp(const AppButton(label: 'Disabled', onPressed: null)),
      );

      expect(find.text('Disabled'), findsOneWidget);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.38);
    });
  });

  group('AppLikeDislikeSegment tests', () {
    testWidgets('renders like and dislike counts and dispatches taps', (
      tester,
    ) async {
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

    testWidgets('reaction segments respond at the top and bottom edges', (
      tester,
    ) async {
      var likes = 0;
      var dislikes = 0;
      await tester.pumpWidget(
        buildApp(
          AppLikeDislikeSegment(
            likeCount: '18K',
            dislikeCount: '236',
            reaction: 0,
            onLike: () => likes++,
            onDislike: () => dislikes++,
          ),
        ),
      );

      final bounds = tester.getRect(find.byType(AppLikeDislikeSegment));
      final likeX = tester.getCenter(find.text('18K')).dx;
      final dislikeX = tester.getCenter(find.text('236')).dx;
      await tester.tapAt(Offset(likeX, bounds.top + 1));
      await tester.tapAt(Offset(dislikeX, bounds.bottom - 1));
      expect(likes, 1);
      expect(dislikes, 1);
    });
  });

  group('AppSubscribedButton tests', () {
    testWidgets('shows Subscribe and Unsubscribe states without extra icons', (
      tester,
    ) async {
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

      expect(find.text('Unsubscribe'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell), findsNothing);
      expect(find.byIcon(LucideIcons.chevronDown), findsNothing);
    });
  });

  group('AppChip and AppChipBar tests', () {
    testWidgets('compact chip has height 32 and handles tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          AppChip(label: 'All', selected: true, onTap: () => tapped = true),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      final chipSize = tester.getSize(find.byType(AppChip));
      expect(chipSize.height, AppSizes.chipHeightCompact);

      await tester.tap(find.byType(AppChip));
      expect(tapped, isTrue);
    });

    testWidgets('AppChipBar renders horizontal chip row with gutter', (
      tester,
    ) async {
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
    testWidgets(
      'renders pinned header with title, drag handle and close button',
      (tester) async {
        await tester.pumpWidget(
          buildApp(const AppSheetHeader(title: 'Comments', showClose: true)),
        );

        expect(find.text('Comments'), findsOneWidget);
        expect(find.byIcon(LucideIcons.x), findsOneWidget);
      },
    );

    testWidgets('renders back button without a divider when scrolled under', (
      tester,
    ) async {
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
      expect(find.byType(Divider), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      expect(backed, isTrue);
    });
  });

  group('HomeTopBar tests', () {
    testWidgets(
      'Home bar has logo, language button and search; NO cast or notification bell',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(body: HomeTopBar()),
            ),
          ),
        );

        // Verify Cast and Bell are absent
        expect(find.byIcon(LucideIcons.cast), findsNothing);
        expect(find.byIcon(LucideIcons.bell), findsNothing);

        // Verify Search icon is present
        expect(find.byIcon(LucideIcons.search), findsOneWidget);
        expect(find.byType(HiveLogo), findsOneWidget);
        expect(find.byType(ContentLanguageButton), findsOneWidget);
      },
    );
  });
}
