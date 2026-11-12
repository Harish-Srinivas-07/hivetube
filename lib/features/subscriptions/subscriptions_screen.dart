import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:drift/drift.dart' show Value;
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/takeout_parser.dart';
import '../../widgets/common.dart';
import '../playlist/save_to_playlist_sheet.dart';

enum SubscriptionsFilter { all, today, videos, shorts }

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String? _selectedChannelId;
  SubscriptionsFilter _currentFilter = SubscriptionsFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(subscriptionsFeedServiceProvider);
      service.markTabOpened();
      service.refreshFeed(force: false);
    });
  }

  Future<void> _importTakeout() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (file == null) return;

      final content = file.path != null
          ? await File(file.path!).readAsString()
          : await file.xFile.readAsString();

      final parsed = parseTakeoutCsv(content);
      if (parsed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No subscriptions found in CSV file.')),
          );
        }
        return;
      }

      final db = ref.read(dbProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        for (final item in parsed) {
          await db.into(db.subscriptions).insertOnConflictUpdate(
            SubscriptionsCompanion.insert(
              channelId: item.channelId,
              name: item.title,
              avatarUrl: '',
              subscribedAt: now,
              lastFeedAt: const Value(0),
            ),
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${parsed.length} subscriptions! Refreshing feed...'),
          ),
        );
      }

      ref.read(subscriptionsFeedServiceProvider).refreshFeed(force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(subscriptionsStreamProvider);
    final feedAsync = ref.watch(feedItemsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileSpreadsheet),
            tooltip: 'Import from Google Takeout',
            onPressed: _importTakeout,
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: subsAsync.when(
        data: (subs) {
          if (subs.isEmpty) {
            return _buildEmptyState(theme);
          }

          return RefreshIndicator(
            onRefresh: () => ref
                .read(subscriptionsFeedServiceProvider)
                .refreshFeed(force: true),
            child: CustomScrollView(
              slivers: [
                // Top channels horizontal avatar bar
                SliverToBoxAdapter(
                  child: _buildChannelBar(subs, theme),
                ),
                // Filter chips
                SliverToBoxAdapter(
                  child: _buildFilterChips(theme),
                ),
                // Feed list
                feedAsync.when(
                  data: (items) {
                    final filtered = _filterItems(items);
                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No videos match this filter',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, idx) => _buildFeedItemCard(filtered[idx], theme),
                        childCount: filtered.length,
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Error loading feed: $e')),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading subscriptions: $e')),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.bellOff,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No subscriptions yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Subscribe to channels from search and home, or import your existing subscriptions from a Google Takeout CSV.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _importTakeout,
              icon: const Icon(LucideIcons.uploadCloud, size: 20),
              label: const Text('Import from Google Takeout'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push('/search'),
              icon: const Icon(LucideIcons.compass, size: 20),
              label: const Text('Explore channels'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelBar(List<SubscriptionRow> subs, ThemeData theme) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: subs.length + 1,
        itemBuilder: (ctx, idx) {
          if (idx == subs.length) {
            // "All" button at the end
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => context.push('/subscriptions/manage'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      child: Icon(
                        LucideIcons.layoutGrid,
                        color: theme.colorScheme.onSurface,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'All',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final sub = subs[idx];
          final isSelected = _selectedChannelId == sub.channelId;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () {
                setState(() {
                  _selectedChannelId = isSelected ? null : sub.channelId;
                });
              },
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Avatar(
                        name: sub.name,
                        url: sub.avatarUrl,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      sub.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _currentFilter == SubscriptionsFilter.all,
            onSelected: (_) =>
                setState(() => _currentFilter = SubscriptionsFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Today'),
            selected: _currentFilter == SubscriptionsFilter.today,
            onSelected: (_) =>
                setState(() => _currentFilter = SubscriptionsFilter.today),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Videos'),
            selected: _currentFilter == SubscriptionsFilter.videos,
            onSelected: (_) =>
                setState(() => _currentFilter = SubscriptionsFilter.videos),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Shorts'),
            selected: _currentFilter == SubscriptionsFilter.shorts,
            onSelected: (_) =>
                setState(() => _currentFilter = SubscriptionsFilter.shorts),
          ),
        ],
      ),
    );
  }

  List<FeedItemRow> _filterItems(List<FeedItemRow> items) {
    return items.where((item) {
      if (_selectedChannelId != null && item.channelId != _selectedChannelId) {
        return false;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDayMs = 24 * 60 * 60 * 1000;

      switch (_currentFilter) {
        case SubscriptionsFilter.all:
          return true;
        case SubscriptionsFilter.today:
          return (now - item.publishedAt) <= oneDayMs;
        case SubscriptionsFilter.videos:
          final sec = item.durationSec;
          return sec == null || sec > 60;
        case SubscriptionsFilter.shorts:
          final sec = item.durationSec;
          return sec != null && sec <= 60;
      }
    }).toList();
  }

  Widget _buildFeedItemCard(FeedItemRow item, ThemeData theme) {
    final publishedDate = DateTime.fromMillisecondsSinceEpoch(item.publishedAt);
    final timeAgo = _formatTimeAgo(publishedDate);

    return InkWell(
      onTap: () => context.push('/watch/${item.videoId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with duration overlay
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: item.thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: const Icon(LucideIcons.video),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Icon(LucideIcons.video),
                      ),
              ),
              if (item.durationSec != null && item.durationSec! > 0)
                Positioned(
                  bottom: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      _formatDuration(item.durationSec!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.push('/channel/${item.channelId}'),
                  child: Avatar(
                    name: item.channelId,
                    url: '',
                    size: 40,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  onSelected: (val) => _handleCardAction(val, item),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'save_playlist',
                      child: Row(
                        children: [
                          Icon(LucideIcons.listPlus, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Save to playlist'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'watch_later',
                      child: Row(
                        children: [
                          Icon(LucideIcons.clock, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Save to Watch Later'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'unsubscribe',
                      child: Row(
                        children: [
                          Icon(LucideIcons.bellOff, size: 18),
                          SizedBox(width: AppSpacing.sm),
                          Text('Unsubscribe'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCardAction(String action, FeedItemRow item) async {
    final db = ref.read(dbProvider);
    if (action == 'save_playlist') {
      showSaveToPlaylistSheet(
        context,
        videoId: item.videoId,
        media: MediaCompanion.insert(
          videoId: item.videoId,
          title: item.title,
          channelId: item.channelId,
          channelName: '',
          durationSec: Value(item.durationSec),
          thumbUrl: item.thumbUrl,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else if (action == 'watch_later') {
      final watchLater = await db.playlistsDao.getOrCreateWatchLater();
      await db.playlistsDao.addPlaylistItem(
        watchLater.id,
        item.videoId,
        mediaItem: MediaCompanion.insert(
          videoId: item.videoId,
          title: item.title,
          channelId: item.channelId,
          channelName: '',
          durationSec: Value(item.durationSec),
          thumbUrl: item.thumbUrl,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Watch Later')),
        );
      }
    } else if (action == 'unsubscribe') {
      await db.subscriptionsDao.unsubscribe(item.channelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsubscribed')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
