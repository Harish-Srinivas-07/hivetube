# HIVETUBE TASK TEMPLATES AND PATTERNS
Rules and commands are in AGENTS.md. Orchestrator: docs/orchestrator.md. Features: docs/features.md.

## 3. KEY APIs (grounding, don't reinvent)
- Providers: homeProvider (HomeController), watchPanelProvider, watchPanelExpandProvider, playerUiProvider, playbackProvider, shortsSelectionProvider, tabRefreshProvider, contentPrefsProvider, ytApiProvider, historyRepoProvider, subscriptionRepoProvider, dbProvider, channelAvatarCacheProvider.
- Open a video: `openWatchPanel(ref, video.id);` Open Shorts: `ref.read(shortsSelectionProvider.notifier).open(items, index); context.go('/shorts');`
- Routes: /search, /channel/:id, /playlist/:id, /shorts, /history.
- Widgets: VideoCard(mode: feed|grid|compact|searchResult), ThumbnailWithDuration, ChannelAvatar, SectionHeader, AppChip/AppChipBar, AppButton(.filled/.tonal/.text), AppIconButton, AppListTile, EmptyState, ErrorRetry, InlineBanner, FeedSkeleton, SliverBottomInset, PlaylistCard, showAppSheet + AppSheetRow.
- Models: VideoItem{id,title,channelId,channelName,channelAvatarUrl,thumbUrl,durationText,viewsText,publishedText,publishedAt,isShort}, ShortItem{id,thumbUrl,title,viewsText,channelName}.

## 4. CODE PATTERNS

Bottom sheet (always bottom-anchored, via showAppSheet):
```dart
final action = await showAppSheet<String>(
  context,
  fit: true,
  builder: (ctx, _) => ListView(shrinkWrap: true, children: [
    AppSheetRow(icon: LucideIcons.share, label: 'Share',
        onTap: () => Navigator.pop(ctx, 'share')),
  ]),
);
```

Per-item data without rebuilding the list (avatars, progress, like state):
```dart
final channelAvatarProvider = FutureProvider.family<String, String>((ref, channelId) async {
  final cache = ref.watch(channelAvatarCacheProvider);
  return cache.get(channelId) ?? await ref.read(ytApiProvider.future).then((a) => a.browse.channelAvatar(channelId));
});
// in ChannelAvatar: ref.watch(channelAvatarProvider(id)); the parent list never watches it.
```

Feed sliver (keyed, no keep-alives, repaint boundary):
```dart
SliverList.builder(
  addAutomaticKeepAlives: false,
  itemCount: items.length,
  itemBuilder: (_, i) => RepaintBoundary(
    key: ValueKey(items[i].id),
    child: VideoCard(video: items[i], mode: VideoCardMode.feed, onTap: () => openWatchPanel(ref, items[i].id)),
  ),
)
```

Load more (once per extent):
```dart
controller.addListener(() {
  if (controller.position.extentAfter < AppSpacing.xxxl) ref.read(provider.notifier).loadMore();
});
```

Image sizing:
```dart
CachedNetworkImage(imageUrl: url, memCacheWidth: (w * dpr).round(), fadeInDuration: const Duration(milliseconds: 150),
  placeholder: (_, _) => ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest))
```

Allowed-exception marker (lint reads it):
```dart
// allowed: shorts scrim
```

Widget test with a fake notifier (pattern used in test/home_interaction_test.dart):
```dart
class FakeHome extends HomeController { 
  final calls = <String>[];
  @override FutureOr<HomeData> build() => HomeData(videos: fixtureVideos);
  @override void interact() => calls.add('interact');
  @override Future<void> loadMore() async => calls.add('loadMore');
}
await tester.pumpWidget(ProviderScope(overrides: [homeProvider.overrideWith(FakeHome.new)], child: const MaterialApp(home: HomeScreen())));
```

## 5. STATES (every list screen, docs/design.md section 6)
skeleton (matches final layout) | data | empty (EmptyState: icon + one line + one button) | fatal error (ErrorRetry) | partial error (ONE InlineBanner) | pull to refresh | footer spinner 24 for load more | bottom inset applied ONCE.

## 7. TASK TEMPLATES (copy, fill the <>)

BUGFIX
```
Task: fix <symptom> in <screen/feature>. Read docs/design.md. Rules: AGENTS.md.
1. Find the cause by reading the code. State it in one line. Don't guess.
2. Fix the code. Smallest change.
3. Add one test that fails before and passes after.
4. dart analyze, design_lint, non-golden tests = clean.
Final reply = ONE line: CAUSE: <...> | FIX: <files> | analyze=<ok/errors> | lint=<0/n> | tests=<pass/fail> | blocker=<none/exact>
```

NEW OR RESTYLED SCREEN
```
Task: build/restyle <screen> per docs/design.md section <5.x>. Rules: AGENTS.md.
Files: <list>. Use components from docs/design.md section 4. All states from docs/design.md section 6.
Then dart analyze, design_lint, tests.
Final reply = ONE line: <SCREEN> | files=<list> | analyze=<ok/errors> | lint=<0/n> | tests=<pass/fail> | blocker=<none/exact>
```

PERF
```
Task: reduce rebuilds/jank in <screen>. Measure first with a counter test (build count per action). Apply docs/design.md section 7. Per-item data via family providers. Show before/after counts.
Final reply = ONE line: PERF | rebuilds before=<n> after=<n> | files=<list> | analyze=<ok/errors> | tests=<pass/fail>
```

TEST REPAIR
```
Task: fix failing tests. For each: STALE / BUG / ENV / FLAKY. STALE = update to new spec. BUG = fix code. ENV = make deterministic (inject clock, fake client). FLAKY = fake timers/awaits. Never delete or skip.
Final reply = ONE line: TESTS | failing before=<n> | STALE=<n> BUG=<n> ENV=<n> FLAKY=<n> | unresolved=<none/names>
```

RELEASE (commit + version)
```
Task: commit then bump version. No push/tag/amend. 1) git status; skip secrets/build artifacts. 2) analyze + non-golden tests must pass, else stop. 3) commit "<type>(<scope>): <summary>". 4) bump pubspec version: minor+1, patch 0, build+1 (patch bump if I say so). Update hardcoded old version strings. 5) commit "chore: bump version to <new>". 6) git status clean.
Final reply = ONE line: COMMIT | version <old> -> <new> | commit1=<hash> commit2=<hash> | skipped=<none/names> | status clean=<yes/no> | blocker=<none/exact>
```

STATUS REPORT (read-only)
```
Task: STATUS ONLY. Edit nothing. Report: analyze counts, test pass/fail + failing names, design_lint counts, git status count + diff stat, duplicate widgets (VideoCard/showAppSheet defs), JSON parse errors, TODO/FIXME count, version in pubspec.
Final reply = block, one line per item.
```

LIVE FEED PROBE
```
Task: verify Home feed LIVE (real network, signed-out). Use tool/probe.dart. Log counts per stage: fetched -> after filter -> shown, plus HTTP status and client name. Don't loosen filters to pass. 
Final reply = ONE line: PROOF: <N> videos | client=<name> | sources=<list> | first3=<id: title; ...>  or  FAIL: <stage> | <status/error>
```

## 8. OUTPUT FORMAT RULES
- Final reply is ONE line in the template's format. No recap, no prose.
- Before editing, no plan essays. After finishing, no summaries.
- If a decision needs me (schema change, new dependency, deleting a feature), STOP and ask in one line. Don't pick silently.
- New dependency: allowed only if the task needs it. Report it in the final line (pubspec changed).
