import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/parser.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/features/channel/channel_screen.dart';
import 'package:hivetube/theme/app_colors.dart';
import 'package:hivetube/theme/app_spacing.dart';

class _ChannelApi extends Fake implements YtApi {
  @override
  YtBrowse get browse => _ChannelBrowse();
}

class _ChannelBrowse extends Fake implements YtBrowse {
  static Completer<ChannelPageData>? pendingVideos;
  @override
  Future<ChannelAboutData> channelAbout(String channelId) async =>
      const ChannelAboutData(
        description: 'Channel description',
        joinedDate: 'Joined Aug 22, 2007',
        views: '500 views',
      );
  @override
  Future<ChannelPageData> channelPage(
    String channelId, {
    String? params,
    String? continuation,
    CancelToken? cancelToken,
  }) async {
    if (params == YtBrowse.tabParamsVideos && pendingVideos != null) {
      return pendingVideos!.future;
    }
    return ChannelPageData(
      id: channelId,
      name: 'Test channel',
      handle: '@testchannel',
      subscribersText: '100 subscribers',
      videosCountText: '12 videos',
      description:
          'This channel description should use two full lines before the more link appears.',
      bannerUrl: 'https://example.invalid/banner.jpg',
      tabs: const ['Home', 'Videos', 'Shorts'],
      currentTabItems: params == YtBrowse.tabParamsShorts
          ? const [
              ShortItem(
                id: 'short-1',
                thumbUrl: 'https://i.ytimg.com/vi/short-1/hqdefault.jpg',
                title: 'A Short title',
                viewsText: '1K views',
              ),
            ]
          : const [],
    );
  }
}

void main() {
  testWidgets('channel Shorts prefer high resolution with supplied fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ytApiProvider.overrideWith((ref) async => _ChannelApi()),
          subscriptionRepoProvider.overrideWithValue(EmptySubscriptionRepo()),
        ],
        child: const MaterialApp(home: ChannelScreen(channelId: 'UCtest')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Shorts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final tile = find.byKey(const ValueKey('short-1'));
    final imageFinder = find.descendant(
      of: tile,
      matching: find.byType(CachedNetworkImage),
    );
    final image = tester.widget<CachedNetworkImage>(imageFinder);
    expect(image.imageUrl, 'https://i.ytimg.com/vi/short-1/maxresdefault.jpg');
    final fallback = image.errorWidget!(
      tester.element(imageFinder),
      '',
      Object(),
    );
    expect(fallback, isA<LayoutBuilder>());
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 150, child: fallback)),
    );
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .imageUrl,
      'https://i.ytimg.com/vi/short-1/hqdefault.jpg',
    );
  });
  testWidgets(
    'unloaded channel tab shows loading skeleton until data arrives',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<ChannelPageData>();
      _ChannelBrowse.pendingVideos = pending;
      addTearDown(() => _ChannelBrowse.pendingVideos = null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ytApiProvider.overrideWith((ref) async => _ChannelApi()),
            subscriptionRepoProvider.overrideWithValue(EmptySubscriptionRepo()),
          ],
          child: const MaterialApp(home: ChannelScreen(channelId: 'UCtest')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Videos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('channelTabLoading:Videos')),
        findsOneWidget,
      );
      expect(find.text('This channel has no videos'), findsNothing);
      pending.complete(
        ChannelPageData(
          id: 'UCtest',
          name: 'Test channel',
          handle: '@testchannel',
          tabs: const ['Home', 'Videos', 'Shorts'],
          currentTabItems: const [
            VideoItem(
              id: 'video-1',
              title: 'Loaded video',
              channelId: 'UCtest',
              channelName: 'Test channel',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('channelTabLoading:Videos')),
        findsNothing,
      );
      expect(find.text('Loaded video'), findsOneWidget);
    },
  );

  testWidgets('channel Shorts show titles and a working options menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          ytApiProvider.overrideWith((ref) async => _ChannelApi()),
          subscriptionRepoProvider.overrideWithValue(EmptySubscriptionRepo()),
        ],
        child: const MaterialApp(home: ChannelScreen(channelId: 'UCtest')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Shorts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('A Short title'), findsOneWidget);
    final tile = find.byKey(const ValueKey('short-1'));
    final menu = find.descendant(
      of: tile,
      matching: find.byTooltip('More options'),
    );
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Save to playlist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('parses channel description and verified About fields', () {
    final header = parseChannelPage({
      'channelMetadataRenderer': {
        'title': 'Test',
        'description': 'Full description',
      },
    }, 'UCtest');
    expect(header.description, 'Full description');
    final about = parseChannelAbout({
      'aboutChannelViewModel': {
        'description': 'Full description',
        'joinedDateText': {'content': 'Joined Aug 22, 2007'},
        'viewCountText': '500 views',
        'country': 'India',
      },
    });
    expect(about.description, 'Full description');
    expect(about.joinedDate, 'Joined Aug 22, 2007');
    expect(about.views, '500 views');
    expect(about.country, 'India');
  });
  testWidgets('loaded channel header shows the Subscribe action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ytApiProvider.overrideWith((ref) async => _ChannelApi()),
          subscriptionRepoProvider.overrideWithValue(EmptySubscriptionRepo()),
        ],
        child: const MaterialApp(home: ChannelScreen(channelId: 'UCtest')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Test channel'), findsWidgets);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Join'), findsNothing);
    expect(find.byTooltip('Community'), findsNothing);
    final description = find.byKey(const ValueKey('channelDescription'));
    expect(description, findsOneWidget);
    expect(
      tester
          .widget<RichText>(
            find.descendant(of: description, matching: find.byType(RichText)),
          )
          .maxLines,
      2,
    );
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.indicatorColor, AppColors.primary);
    expect(tabs.labelColor, AppColors.primary);
    expect(tabs.dividerHeight, AppSpacing.none);
    expect(
      tabs.labelPadding,
      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Channel description'), findsOneWidget);
    expect(find.text('Joined Aug 22, 2007'), findsOneWidget);
    expect(find.text('500 views'), findsOneWidget);
    Navigator.of(tester.element(find.text('Channel description'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('About').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Channel description'), findsOneWidget);
  });
}
