import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../widgets/video_options_menu.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_motion.dart';
import '../shorts/shorts_screen.dart';
import '../watch/watch_panel.dart';
import '../watch/mini_player_inset.dart';
import '../../core/playback/player_ui_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/yt/models.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui/ui.dart';
import 'home_controller.dart';
import 'home_variety.dart';

final homeHistoryProvider = FutureProvider<List<HistoryEntry>>(
  (ref) => ref.watch(historyRepoProvider).recent(),
);
final homeHistoryByIdProvider = Provider<Map<String, HistoryEntry>>((ref) {
  final entries =
      ref.watch(homeHistoryProvider).value ?? const <HistoryEntry>[];
  return {for (final entry in entries) entry.videoId: entry};
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onCardBuilt});
  @visibleForTesting
  final void Function(String id)? onCardBuilt;
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final controller = ScrollController();
  String chip = 'All';
  static const chips = homeChips;
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
    ref.watch(
      homeProvider.select(
        (value) => (
          value.isLoading,
          value.error,
          value.value?.videos,
          value.value?.shorts,
          value.value?.trending,
          value.value?.errors,
          value.value?.chip,
          value.value?.loadingMore,
          value.value?.continuations,
        ),
      ),
    );
    final home = ref.read(homeProvider);
    final historyById = ref.watch(homeHistoryByIdProvider);
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
                loading: () => const FeedSkeleton(),
                error: (_, _) => ErrorRetry(
                  message: 'Unable to load Home',
                  onRetry: () => ref.read(homeProvider.notifier).refresh(),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () => ref.read(homeProvider.notifier).refresh(),
                  child: CustomScrollView(
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (data.errors.isNotEmpty && data.videos.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(AppSpacing.md),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: AppRadius.mdBorder,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Some sources could not load',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      ref.read(homeProvider.notifier).refresh(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _grid(data, historyById),
                      if (data.videos.isEmpty &&
                          data.trending.isEmpty &&
                          data.shorts.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.videoOff),
                                const Text('No videos found'),
                                TextButton(
                                  onPressed: () =>
                                      ref.read(homeProvider.notifier).refresh(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xl,
                            ),
                            child: data.loadingMore
                                ? const CircularProgressIndicator()
                                : data.continuations.isEmpty
                                ? Text(
                                    'You’re all caught up',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      if (data.trending.isNotEmpty)
                        _trendingShelf(data.trending, historyById),
                      SliverBottomInset(
                        extra:
                            MediaQuery.sizeOf(context).width <
                                AppSpacing.navigationBreakpoint
                            ? AppSpacing.navHeight +
                                  AppSpacing.xl +
                                  MediaQuery.paddingOf(context).bottom
                            : AppSpacing.lg,
                      ),
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
    HomeData data,
    Map<String, HistoryEntry> history,
  ) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final items = data.videos;
      final wide =
          MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
      Widget card(int index) {
        final item = items[index];
        widget.onCardBuilt?.call(item.id);
        final hist = history[items[index].id];
        final progress =
            hist != null &&
                hist.position > Duration.zero &&
                hist.duration > Duration.zero
            ? (hist.position.inMilliseconds / hist.duration.inMilliseconds)
                  .clamp(0.0, 1.0)
            : null;
        return RepaintBoundary(
          key: ValueKey(item.id),
          child: VideoCard(
            video: item,
            mode: wide ? VideoCardMode.grid : VideoCardMode.feed,
            progress: progress,
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
      }

      final columns =
          ((constraints.crossAxisExtent - AppSpacing.lg * 2) /
                  AppSpacing.videoMaxWidth)
              .ceil();
      final count = wide && columns > 1 ? columns : 1;
      final first = items.length < 4 ? items.length : 4;
      final beforeRows = (first / count).ceil();
      final afterRows = ((items.length - first) / count).ceil();
      final hasShorts = data.shorts.isNotEmpty;
      return SliverList.builder(
        addAutomaticKeepAlives: false,
        itemCount: beforeRows + afterRows + (hasShorts ? 1 : 0),
        itemBuilder: (context, row) {
          if (hasShorts && row == beforeRows) {
            return _Shorts(
              items: data.shorts,
              onTap: (index) {
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
                  ref.read(playerUiProvider.notifier).setDismissed(true);
                }
                ref
                    .read(shortsSelectionProvider.notifier)
                    .open(data.shorts, index);
                context.go('/shorts');
              },
            );
          }
          final after = row >= beforeRows;
          final rowIndex = after ? row - beforeRows - (hasShorts ? 1 : 0) : row;
          final start = after ? first + rowIndex * count : rowIndex * count;
          final end = after ? items.length : first;
          if (!wide) return card(start);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < count; col++) ...[
                  if (col > 0) const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: start + col < end
                        ? card(start + col)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );

  Widget _trendingShelf(
    List<VideoItem> items,
    Map<String, HistoryEntry> history,
  ) {
    final shelfItems = items.take(5).toList();
    final cardHeight =
        AppSpacing.homeTrendingWidth / AppSpacing.thumbnailRatio +
        (AppSpacing.cardInfoHeight *
            MediaQuery.textScalerOf(context).scale(1.0));
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Trending',
              style: AppTextStyles.homeShelfTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: shelfItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = shelfItems[index];
                final hist = history[item.id];
                final progress =
                    hist != null &&
                        hist.position > Duration.zero &&
                        hist.duration > Duration.zero
                    ? (hist.position.inMilliseconds /
                              hist.duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                    : null;
                return RepaintBoundary(
                  key: ValueKey('trending:${item.id}'),
                  child: SizedBox(
                    width: AppSpacing.homeTrendingWidth,
                    child: VideoCard(
                      video: item,
                      mode: VideoCardMode.grid,
                      progress: progress,
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

class _Shorts extends ConsumerWidget {
  const _Shorts({required this.items, required this.onTap});
  final List<ShortItem> items;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(LucideIcons.clapperboard, size: AppSizes.icon),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Shorts',
              style: AppTextStyles.homeShelfTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: AppSpacing.homeShortWidth / AppSpacing.homeShortRatio,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => InkWell(
            onTap: () => onTap(index),
            child: SizedBox(
              width: AppSpacing.homeShortWidth,
              child: ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: items[index].thumbUrl,
                      fit: BoxFit.cover,
                      memCacheWidth:
                          (AppSpacing.homeShortWidth *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      maxWidthDiskCache:
                          (AppSpacing.homeShortWidth *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      fadeInDuration: AppMotion.imageFade,
                      placeholder: (_, _) => ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.xs,
                      top: AppSpacing.xs,
                      child: IconButton(
                        tooltip: 'More options',
                        onPressed: () => showVideoOptionsMenu(
                          context,
                          videoId: items[index].id,
                          onVideo: true,
                        ),
                        icon: const Icon(
                          LucideIcons.ellipsisVertical,
                          color: AppColors.shortsForeground,
                        ),
                      ),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[index].title ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.homeShortTitle.copyWith(
                                  color: AppColors.thumbnailBadgeText,
                                ),
                              ),
                              if ((items[index].viewsText ?? '').isNotEmpty)
                                Text(
                                  items[index].viewsText!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.thumbnailBadgeText,
                                  ),
                                ),
                            ],
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
