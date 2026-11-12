import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';
  bool _historyPaused = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(dbProvider);
    final paused = await db.getValue('history_paused');
    if (mounted) {
      setState(() => _historyPaused = paused == 'true');
    }
  }

  Future<void> _togglePauseHistory() async {
    final db = ref.read(dbProvider);
    final next = !_historyPaused;
    await db.setValue('history_paused', next.toString());
    setState(() => _historyPaused = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? 'Watch history paused' : 'Watch history resumed',
          ),
        ),
      );
    }
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Clear watch history?'),
        content: const Text(
          'This will clear your watch history from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(dbProvider).historyDao.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch history cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: Icon(
              _historyPaused ? LucideIcons.play : LucideIcons.pause,
            ),
            tooltip: _historyPaused ? 'Resume history' : 'Pause history',
            onPressed: _togglePauseHistory,
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: 'Clear history',
            onPressed: _clearAllHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search history...',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (val) =>
                  setState(() => _query = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (items) {
                final filtered = items.where((i) {
                  if (_query.isEmpty) return true;
                  final title = i.media?.title.toLowerCase() ?? '';
                  final channel = i.media?.channelName.toLowerCase() ?? '';
                  return title.contains(_query) || channel.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No watch history'
                          : 'No matching history items',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                final groups = _groupByDay(filtered);

                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (ctx, gIdx) {
                    final group = groups[gIdx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            group.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        ...group.items.map((item) => _buildHistoryRow(item, theme)),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(HistoryItemWithMedia item, ThemeData theme) {
    final media = item.media;
    final title = media?.title ?? item.history.videoId;
    final channel = media?.channelName ?? '';
    final thumbUrl = media?.thumbUrl ??
        'https://i.ytimg.com/vi/${item.history.videoId}/hqdefault.jpg';

    final posMs = item.history.positionMs;
    final durMs = item.history.durationMs;
    final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

    return Dismissible(
      key: ValueKey('hist_${item.history.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(LucideIcons.trash2, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        ref.read(dbProvider).historyDao.deleteHistoryItem(item.history.id);
      },
      child: InkWell(
        onTap: () => context.push('/watch/${item.history.videoId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with watched progress bar
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 120,
                      height: 68,
                      child: CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: const Icon(LucideIcons.video, size: 24),
                        ),
                      ),
                    ),
                  ),
                  if (progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.md),
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.black45,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${_formatDuration(posMs ~/ 1000)} / ${_formatDuration(durMs ~/ 1000)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () {
                  ref
                      .read(dbProvider)
                      .historyDao
                      .deleteHistoryItem(item.history.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_HistoryGroup> _groupByDay(List<HistoryItemWithMedia> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayItems = <HistoryItemWithMedia>[];
    final yesterdayItems = <HistoryItemWithMedia>[];
    final weekItems = <HistoryItemWithMedia>[];
    final earlierItems = <HistoryItemWithMedia>[];

    for (final item in items) {
      final date = DateTime.fromMillisecondsSinceEpoch(item.history.at);
      final itemDay = DateTime(date.year, date.month, date.day);

      if (itemDay == today) {
        todayItems.add(item);
      } else if (itemDay == yesterday) {
        yesterdayItems.add(item);
      } else if (itemDay.isAfter(weekAgo)) {
        weekItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    final groups = <_HistoryGroup>[];
    if (todayItems.isNotEmpty) {
      groups.add(_HistoryGroup(title: 'Today', items: todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      groups.add(_HistoryGroup(title: 'Yesterday', items: yesterdayItems));
    }
    if (weekItems.isNotEmpty) {
      groups.add(_HistoryGroup(title: 'This Week', items: weekItems));
    }
    if (earlierItems.isNotEmpty) {
      groups.add(_HistoryGroup(title: 'Earlier', items: earlierItems));
    }
    return groups;
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _HistoryGroup {
  const _HistoryGroup({required this.title, required this.items});
  final String title;
  final List<HistoryItemWithMedia> items;
}
