import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../widgets/common.dart';
import '../../widgets/video_options_menu.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shorts/shorts_screen.dart';
import '../watch/watch_panel.dart';
import '../watch/mini_player_inset.dart';
import '../../core/playback/player_ui_state.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/yt/models.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui/ui.dart';
import 'home_controller.dart';

final homeHistoryProvider = FutureProvider<List<HistoryEntry>>(
  (ref) => ref.watch(historyRepoProvider).recent(),
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final controller = ScrollController();
  final _avatarRequestsScheduled = <String>{};
  String chip = 'All';
  static const chips = [
    'All',
    'Music',
    'Movies',
    'Gaming',
    'Live',
    'News',
    'Podcasts',
    'Sports',
    'Comedy',
    'Cooking',
    'Science',
    'Tech',
    'Education',
    'Recently uploaded',
    'Trending',
    'Live kiosk',
    'Gaming kiosk',
    'Podcasts kiosk',
  ];
  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.offset > 0) ref.read(homeProvider.notifier).interact();
      if (controller.position.extentAfter < AppSpacing.xxxl) {
        ref.read(homeProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabRefreshProvider, (_, request) {
      if (request?.index != 0) return;
      if (controller.hasClients) controller.jumpTo(0);
      unawaited(ref.read(homeProvider.notifier).refresh());
    });
    final home = ref.watch(homeProvider);
    final history =
        ref.watch(homeHistoryProvider).value ?? const <HistoryEntry>[];
    final historyById = {for (final entry in history) entry.videoId: entry};
    final leadCount = AppSpacing.homeLeadItems;
    return Listener(
      onPointerDown: (_) => ref.read(homeProvider.notifier).interact(),
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        body: Column(
          children: [
            _ChipRow(
              selected: chip,
              chips: chips,
              onSelected: (item) {
                setState(() => chip = item);
                ref.read(homeProvider.notifier).select(item);
              },
            ),
            Expanded(
              child: home.when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => const _HomeSkeleton(),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unable to load Home'),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Retry',
                        variant: AppButtonVariant.tonal,
                        onPressed: () =>
                            ref.read(homeProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () => ref.read(homeProvider.notifier).refresh(),
                  child: CustomScrollView(
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (data.chip == 'All' && history.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'Watch videos and follow channels to personalize Home.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      if (data.videos.isNotEmpty)
                        _grid(
                          data.videos.take(leadCount).toList(),
                          historyById,
                        ),
                      if (data.shorts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _Shorts(
                            items: data.shorts,
                            onTap: (index) async {
                              ref.read(homeProvider.notifier).interact();
                              unawaited(
                                ref
                                    .read(homeProvider.notifier)
                                    .rememberChannel(
                                      data.shorts[index].id,
                                      data.shorts[index].channelName ?? '',
                                      isShort: true,
                                    ),
                              );
                              if (ref.read(watchPanelProvider) != null) {
                                ref.read(watchPanelProvider.notifier).close();
                                ref
                                    .read(playerUiProvider.notifier)
                                    .setDismissed(true);
                              }
                              ref
                                  .read(shortsSelectionProvider.notifier)
                                  .open(data.shorts, index);
                              context.go('/shorts');
                            },
                          ),
                        ),
                      for (final error in data.errors)
                        SliverToBoxAdapter(
                          child: TextButton(
                            onPressed: () =>
                                ref.read(homeProvider.notifier).refresh(),
                            child: Text('$error could not load. Retry'),
                          ),
                        ),
                      if (data.videos.isEmpty &&
                          data.trending.isEmpty &&
                          data.shorts.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: Text('No videos found')),
                        ),
                      _grid(data.videos.skip(leadCount).toList(), historyById),
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: data.loadingMore
                                ? const CircularProgressIndicator()
                                : data.continuations.isEmpty
                                ? Text(
                                    'You’re all caught up',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      if (data.trending.isNotEmpty)
                        _trendingShelf(data.trending, historyById),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              MediaQuery.sizeOf(context).width <
                                  AppSpacing.navigationBreakpoint
                              ? AppSpacing.navHeight +
                                    AppSpacing.lg +
                                    AppSpacing.lg +
                                    MediaQuery.paddingOf(context).bottom
                              : AppSpacing.lg,
                        ),
                      ),
                      const SliverBottomInset(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(
    List<VideoItem> items,
    Map<String, HistoryEntry> history,
  ) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final wide =
          MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
      Widget card(int index) {
        final item = items[index];
        if (item.channelAvatarUrl.isEmpty &&
            (item.channelId.isNotEmpty || item.id.isNotEmpty) &&
            _avatarRequestsScheduled.add(
              item.channelId.isNotEmpty ? item.channelId : 'video:${item.id}',
            )) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(ref.read(homeProvider.notifier).ensureAvatar(item));
            }
          });
        }
        return _VideoCard(
          item,
          wide: wide,
          history: history[items[index].id],
          onTap: () {
            ref.read(homeProvider.notifier).interact();
            unawaited(
              ref
                  .read(homeProvider.notifier)
                  .rememberChannel(item.id, item.channelName),
            );
            openWatchPanel(ref, item.id);
          },
        );
      }

      if (!wide) {
        return SliverList.builder(
          itemCount: items.length,
          itemBuilder: (_, index) => card(index),
        );
      }
      final usable = constraints.crossAxisExtent - AppSpacing.lg * 2;
      final columns = (usable / AppSpacing.videoMaxWidth).ceil();
      final count = columns < 1 ? 1 : columns;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, index) => card(index),
            childCount: items.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent:
                (usable - (count - 1) * AppSpacing.lg) /
                    count /
                    AppSpacing.thumbnailRatio +
                AppSpacing.cardInfoHeight,
          ),
        ),
      );
    },
  );

  Widget _trendingShelf(
    List<VideoItem> items,
    Map<String, HistoryEntry> history,
  ) {
    final shelfItems = items.take(5).toList();
    final cardHeight =
        AppSpacing.videoMaxWidth / AppSpacing.thumbnailRatio +
        AppSpacing.cardInfoHeight;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Trending'),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: shelfItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
              itemBuilder: (context, index) {
                final item = shelfItems[index];
                return SizedBox(
                  width: AppSpacing.videoMaxWidth,
                  child: _VideoCard(
                    item,
                    wide: false,
                    history: history[item.id],
                    onTap: () {
                      ref.read(homeProvider.notifier).interact();
                      unawaited(
                        ref
                            .read(homeProvider.notifier)
                            .rememberChannel(item.id, item.channelName),
                      );
                      openWatchPanel(ref, item.id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.selected,
    required this.chips,
    required this.onSelected,
  });
  final String selected;
  final List<String> chips;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    return AppChipBar(
      children: [
        AppChip(
          label: '',
          leading: const Icon(LucideIcons.compass, size: AppSizes.iconSm),
          onTap: () {},
        ),
        for (final item in chips)
          AppChip(
            label: item,
            selected: item == selected,
            onTap: () => onSelected(item),
          ),
      ],
    );
  }
}

class _VideoCard extends ConsumerWidget {
  const _VideoCard(
    this.item, {
    required this.onTap,
    required this.wide,
    required this.history,
  });
  final VideoItem item;
  final VoidCallback onTap;
  final bool wide;
  final HistoryEntry? history;
  // The preview slot stays hidden until inline playback is supported.
  static const showInlinePreviewControls = false;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress =
        history != null &&
            history!.position > Duration.zero &&
            history!.duration > Duration.zero
        ? (history!.position.inMilliseconds / history!.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : null;
    final colors = theme.brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final thumbnail = CachedNetworkImage(
      imageUrl: item.thumbUrl,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => const Icon(LucideIcons.imageOff),
    );
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            key: ValueKey('homeThumbnail:${item.id}'),
            aspectRatio: AppSpacing.thumbnailRatio,
            child: ClipRRect(
              borderRadius: wide ? AppRadius.mdBorder : AppRadius.noneBorder,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnail,
                  if (item.durationText.isNotEmpty)
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.thumbnailBadge,
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xxs,
                          ),
                          child: Text(
                            item.durationText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.thumbnailBadgeText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        key: ValueKey('watchedProgress:${item.id}'),
                        value: progress,
                        minHeight: AppSpacing.progressHeight,
                        color: AppColors.progressFill,
                        backgroundColor: colors.progressTrack,
                      ),
                    ),
                  if (showInlinePreviewControls)
                    Positioned(
                      right: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: Column(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(LucideIcons.volumeX),
                            iconSize: AppSpacing.homeInlineIconSize,
                            color: AppColors.thumbnailBadgeText,
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(LucideIcons.captions),
                            iconSize: AppSpacing.homeInlineIconSize,
                            color: AppColors.thumbnailBadgeText,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 0 : AppSpacing.lg,
              AppSpacing.md,
              wide ? 0 : AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.channelId.isNotEmpty ||
                    item.channelName.isNotEmpty) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: item.channelId.isNotEmpty
                        ? () => context.push('/channel/${item.channelId}')
                        : null,
                    child: Avatar(name: item.channelName, url: item.channelAvatarUrl),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      InkWell(
                        onTap: item.channelId.isNotEmpty
                            ? () => context.push('/channel/${item.channelId}')
                            : null,
                        child: Text(
                          [
                            item.channelName,
                            item.viewsText,
                            item.publishedText,
                          ].where((v) => v.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'More options',
                  onPressed: () => showVideoOptionsMenu(
                    context,
                    videoId: item.id,
                    ref: ref,
                    media: MediaCompanion.insert(
                      videoId: item.id,
                      title: item.title,
                      channelId: item.channelId,
                      channelName: item.channelName,
                      thumbUrl: item.thumbUrl,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                  iconSize: AppSizes.icon,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.touchMin,
                    minHeight: AppSizes.touchMin,
                  ),
                  icon: const Icon(LucideIcons.ellipsisVertical),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shorts extends ConsumerWidget {
  const _Shorts({required this.items, required this.onTap});
  final List<ShortItem> items;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading('Shorts'),
      SizedBox(
        height: AppSpacing.shortWidth / AppSpacing.shortRatio,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => InkWell(
            onTap: () => onTap(index),
            child: SizedBox(
              width: AppSpacing.shortWidth,
              child: ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: items[index].thumbUrl,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      left: AppSpacing.sm,
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.shelfTitleScrim,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Text(
                            [
                              items[index].title ?? '',
                              items[index].viewsText ?? '',
                            ].where((v) => v.isNotEmpty).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.thumbnailBadgeText),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: const [
      SkeletonVideoCard(),
      SizedBox(height: AppSpacing.lg),
      SkeletonVideoCard(),
    ],
  );
}
