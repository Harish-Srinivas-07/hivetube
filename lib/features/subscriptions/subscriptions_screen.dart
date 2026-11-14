import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/channel_metadata.dart';
import '../../core/yt/models.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../watch/mini_player_inset.dart';
import '../../widgets/common/common.dart';
import '../../widgets/ui/app_controls.dart';

enum SubscriptionsFilter { all, today, videos, shorts, continueWatching }

final _subscriptionNameProvider = StreamProvider.family<String, String>((
  ref,
  channelId,
) {
  final db = ref.watch(dbProvider);
  return (db.select(
    db.subscriptions,
  )..where((row) => row.channelId.equals(channelId))).watchSingleOrNull().map(
    (subscription) =>
        subscription == null ||
            isMissingChannelName(subscription.name, channelId)
        ? 'Channel'
        : subscription.name,
  );
});

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String? _selectedChannelId;
  SubscriptionsFilter _currentFilter = SubscriptionsFilter.all;
  Set<String> _failedChannelIds = const {};
  int _lastOpenedAt = 0;
  Object? _refreshError;
  bool _refreshing = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeFeed());
    });
  }

  Future<void> _initializeFeed() async {
    final service = ref.read(subscriptionsFeedServiceProvider);
    try {
      final lastOpened = await service.getLastOpenedAt();
      if (!mounted) return;
      setState(() => _lastOpenedAt = lastOpened);
      await service.markTabOpened();
      await service.backfillSubscriptionDetails();
      await _refreshFeed(force: false);
    } catch (error, stackTrace) {
      dev.log(
        'Subscriptions initialization failed: $error',
        name: 'SubscriptionsScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _refreshError = error);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _refreshFeed({required bool force}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
      _failedChannelIds = const {};
    });
    final service = ref.read(subscriptionsFeedServiceProvider);
    try {
      await service.refreshFeed(force: force);
    } catch (error, stackTrace) {
      dev.log(
        'Subscriptions feed refresh failed: $error',
        name: 'SubscriptionsScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _refreshError = error);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _failedChannelIds = service.lastFailedChannelIds;
        });
      }
      ref.invalidate(feedItemsStreamProvider);
      ref.invalidate(hasUnreadUploadsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabRefreshProvider, (_, request) {
      if (request?.index != 2) return;
      unawaited(_refreshFeed(force: true));
    });

    final feedAsync = ref.watch(feedItemsStreamProvider);
    final feedItems = feedAsync.asData?.value;
    final historyAsync = ref.watch(historyStreamProvider);
    final subscriptionStatus = ref.watch(
      subscriptionsStreamProvider.select(
        (value) => (
          loading: value.isLoading,
          error: value.hasError,
          empty: value.asData?.value.isEmpty ?? false,
        ),
      ),
    );
    final continueIds =
        historyAsync.asData?.value
            .where(
              (entry) =>
                  entry.history.positionMs > 0 &&
                  entry.history.durationMs > 0 &&
                  entry.history.durationMs - entry.history.positionMs >
                      const Duration(seconds: 30).inMilliseconds,
            )
            .map((entry) => entry.history.videoId)
            .toSet() ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text('Subscriptions', style: AppTextStyles.pageTitle),
        actions: [
          IconButton(
            tooltip: 'Search',
            constraints: const BoxConstraints.tightFor(
              width: AppSizes.buttonIconTouch,
              height: AppSizes.buttonIconTouch,
            ),
            onPressed: () => context.push('/search'),
            icon: const Icon(LucideIcons.search, size: AppSizes.icon),
          ),
          TextButton(
            onPressed: () => context.push('/subscriptions/manage'),
            child: const Text('Manage'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshFeed(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (subscriptionStatus.loading)
              const SliverToBoxAdapter(child: ChannelStripSkeleton())
            else if (subscriptionStatus.empty)
              const SliverToBoxAdapter(child: SizedBox.shrink())
            else
              SliverToBoxAdapter(
                child: _SubscriptionsChannelStrip(
                  selectedChannelId: _selectedChannelId,
                  lastOpenedAt: _lastOpenedAt,
                  onSelect: (channelId) =>
                      setState(() => _selectedChannelId = channelId),
                ),
              ),
            if (!subscriptionStatus.loading && !subscriptionStatus.empty)
              SliverToBoxAdapter(
                child: _buildFilterChips(historyAsync.hasValue),
              ),
            if (subscriptionStatus.error)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorRetry(
                  message: 'Unable to load subscriptions.',
                  onRetry: () => ref.invalidate(subscriptionsStreamProvider),
                ),
              )
            else if (subscriptionStatus.loading)
              const FeedSkeletonSliver(count: 3)
            else if (subscriptionStatus.empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _SubscriptionsEmptyState(
                  title: 'No subscriptions yet',
                  message: 'Subscribe to channels to see their videos here',
                  actionLabel: 'Find channels',
                  onAction: () => context.push('/search'),
                ),
              )
            else if (feedAsync.hasError ||
                (_refreshError != null && feedItems?.isEmpty == true))
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorRetry(
                  message: 'Unable to load subscription videos.',
                  onRetry: () => _refreshFeed(force: true),
                ),
              )
            else if (feedAsync.isLoading ||
                (_initializing && feedItems?.isEmpty == true) ||
                (_refreshing && feedItems?.isEmpty == true)) ...[
              const FeedSkeletonSliver(count: 3),
            ] else ...[
              if (_failedChannelIds.isNotEmpty ||
                  (_refreshError != null && feedItems?.isNotEmpty == true))
                SliverToBoxAdapter(
                  child: _PartialFeedBanner(
                    onRetry: () => _refreshFeed(force: true),
                  ),
                ),
              _feedSliver(feedItems ?? const [], continueIds),
            ],
            SliverBottomInset(
              extra:
                  MediaQuery.paddingOf(context).bottom +
                  AppSizes.bottomNav +
                  AppSpacing.lg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedSliver(List<FeedItemRow> items, Set<String> continueIds) {
    final filtered = _filterItems(items, continueIds)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _SubscriptionsEmptyState(
          title: 'No videos match this filter',
          message: 'Choose another filter to see subscription videos.',
          actionLabel: 'Show all',
          onAction: () => setState(() {
            _selectedChannelId = null;
            _currentFilter = SubscriptionsFilter.all;
          }),
        ),
      );
    }

    return SliverList.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return RepaintBoundary(
          key: ValueKey(item.videoId),
          child: _SubscriptionFeedCard(item: item),
        );
      },
    );
  }

  List<FeedItemRow> _filterItems(
    List<FeedItemRow> items,
    Set<String> continueIds,
  ) => items.where((item) {
    if (_selectedChannelId != null && item.channelId != _selectedChannelId) {
      return false;
    }
    final published = DateTime.fromMillisecondsSinceEpoch(item.publishedAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_currentFilter) {
      case SubscriptionsFilter.all:
        return true;
      case SubscriptionsFilter.today:
        return !published.isBefore(today);
      case SubscriptionsFilter.videos:
        return item.durationSec == null || item.durationSec! > 60;
      case SubscriptionsFilter.shorts:
        return item.durationSec != null && item.durationSec! <= 60;
      case SubscriptionsFilter.continueWatching:
        return continueIds.contains(item.videoId);
    }
  }).toList();

  Widget _buildFilterChips(bool hasHistorySource) => AppChipBar(
    children: [
      _filterChip('All', SubscriptionsFilter.all),
      _filterChip('Today', SubscriptionsFilter.today),
      _filterChip('Videos', SubscriptionsFilter.videos),
      _filterChip('Shorts', SubscriptionsFilter.shorts),
      if (hasHistorySource)
        _filterChip('Continue watching', SubscriptionsFilter.continueWatching),
    ],
  );

  Widget _filterChip(String label, SubscriptionsFilter filter) => AppChip(
    label: label,
    selected: _currentFilter == filter,
    onTap: () => setState(() => _currentFilter = filter),
  );
}

class _SubscriptionsChannelStrip extends ConsumerWidget {
  const _SubscriptionsChannelStrip({
    required this.selectedChannelId,
    required this.lastOpenedAt,
    required this.onSelect,
  });

  final String? selectedChannelId;
  final int lastOpenedAt;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsStreamProvider).asData?.value;
    final feedItems = ref.watch(feedItemsStreamProvider).asData?.value ?? [];
    if (subscriptions == null || subscriptions.isEmpty) {
      return const ChannelStripSkeleton();
    }
    final unreadIds = feedItems
        .where((item) => item.publishedAt > lastOpenedAt)
        .map((item) => item.channelId)
        .toSet();

    return SizedBox(
      height:
          AppSizes.subscriptionsAvatar +
          AppSpacing.xs +
          AppSizes.iconXs +
          AppSpacing.sm * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        itemCount: subscriptions.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final sub = isAll ? null : subscriptions[index - 1];
          final selected = isAll
              ? selectedChannelId == null
              : selectedChannelId == sub!.channelId;
          final name = isAll
              ? 'All'
              : isMissingChannelName(sub!.name, sub.channelId)
              ? 'Channel'
              : sub.name;
          return SizedBox(
            width: AppSizes.subscriptionsChannelWidth,
            child: InkWell(
              onTap: () => onSelect(isAll ? null : sub!.channelId),
              child: Column(
                children: [
                  if (isAll)
                    Container(
                      width: AppSizes.subscriptionsAvatar,
                      height: AppSizes.subscriptionsAvatar,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.layoutGrid,
                        size: AppSizes.icon,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  else
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ChannelAvatar(
                          name: name,
                          url: sub!.avatarUrl,
                          size: AppSizes.subscriptionsAvatar,
                        ),
                        if (unreadIds.contains(sub.channelId))
                          Positioned(
                            top: 0,
                            right: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(
                                dimension: AppSizes.iconXs / 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: selected
                        ? AppTextStyles.subscriptionChannelSelected
                        : AppTextStyles.meta,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubscriptionFeedCard extends ConsumerWidget {
  const _SubscriptionFeedCard({required this.item});

  final FeedItemRow item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelName = ref.watch(
      _subscriptionNameProvider(
        item.channelId,
      ).select((value) => value.asData?.value ?? 'Channel'),
    );
    final video = VideoItem(
      id: item.videoId,
      title: item.title,
      channelId: item.channelId,
      channelName: channelName,
      channelAvatarUrl: '',
      thumbUrl: item.thumbUrl,
      durationText: item.durationSec != null && item.durationSec! > 0
          ? AppFormatters.formatDurationSeconds(item.durationSec!)
          : '',
      publishedText: AppFormatters.formatTimeAgo(
        DateTime.fromMillisecondsSinceEpoch(item.publishedAt),
      ),
    );
    return VideoCard.feed(
      video: video,
      onTap: () => context.push('/watch/${item.videoId}'),
    );
  }
}

class _PartialFeedBanner extends StatelessWidget {
  const _PartialFeedBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: AppRadius.mdBorder,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Some channels could not load',
            style: AppTextStyles.settingsSub,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _SubscriptionsEmptyState extends StatelessWidget {
  const _SubscriptionsEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.bellOff,
            size: AppSizes.iconLg,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton.tonal(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}
