import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/downloads/download_manager.dart';
import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import '../watch/watch_panel.dart';
import '../watch/mini_player_inset.dart';

Future<void> showDownloadChoices(
  BuildContext context,
  WidgetRef ref,
  MediaCompanion media,
) async {
  final choice = await showAppSheet<String>(
    context,
    title: 'Download',
    fit: true,
    builder: (sheetContext, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetRow(
          icon: LucideIcons.video,
          label: 'Video',
          onTap: () => Navigator.pop(sheetContext, 'video'),
        ),
        AppSheetRow(
          icon: LucideIcons.music,
          label: 'Audio only',
          onTap: () => Navigator.pop(sheetContext, 'audio'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    final manager = ref.read(downloadManagerProvider);
    int? height;
    if (choice == 'video') {
      final heights = await manager.availableVideoHeights(media.videoId.value);
      if (!context.mounted) return;
      if (heights.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No video quality is available')),
        );
        return;
      }
      height = await showAppSheet<int>(
        context,
        title: 'Video quality',
        fit: true,
        builder: (sheetContext, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in heights)
              AppSheetRow(
                icon: LucideIcons.video,
                label: '${option}p${option == heights.first ? ' · Best' : ''}',
                onTap: () => Navigator.pop(sheetContext, option),
              ),
          ],
        ),
      );
      if (height == null || !context.mounted) return;
    }
    await manager.enqueue(media, audioOnly: choice == 'audio', height: height);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to downloads')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not queue download')));
    }
  }
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: StreamBuilder<List<DownloadRow>>(
        stream: db.select(db.downloads).watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorRetry(
              message: 'Unable to load downloads',
              onRetry: () => ref.invalidate(downloadManagerProvider),
            );
          }
          if (!snapshot.hasData) {
            return ListView(
              children: const [
                VideoSkeleton(compact: true),
                VideoSkeleton(compact: true),
                VideoSkeleton(compact: true),
              ],
            );
          }
          final rows = snapshot.data!.reversed.toList();
          if (rows.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.download,
              title: 'No downloads',
              message: 'Videos you download will appear here',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(downloadManagerProvider).start();
            },
            child: CustomScrollView(
              slivers: [
                SliverList.builder(
                  itemCount: rows.length,
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) => RepaintBoundary(
                    key: ValueKey(rows[index].id),
                    child: _DownloadItem(row: rows[index]),
                  ),
                ),
                SliverBottomInset(
                  extra: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DownloadItem extends ConsumerWidget {
  const _DownloadItem({required this.row});
  final DownloadRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    return FutureBuilder<MediaRow?>(
      future: (db.select(
        db.media,
      )..where((m) => m.videoId.equals(row.videoId))).getSingleOrNull(),
      builder: (context, snapshot) {
        final media = snapshot.data;
        final video = VideoItem(
          id: row.videoId,
          title: media?.title ?? row.videoId,
          channelId: media?.channelId ?? '',
          channelName: media?.channelName ?? '',
          thumbUrl: media?.thumbUrl ?? '',
        );
        final progress = row.total > 0
            ? (row.done / row.total).clamp(0.0, 1.0)
            : null;
        final status = switch (row.status) {
          'downloading' =>
            progress == null
                ? 'Downloading'
                : 'Downloading ${(progress * 100).floor()}%',
          'queued' => 'Queued',
          'paused' => 'Paused',
          'failed' => 'Failed',
          'completed' => 'Downloaded',
          _ => row.status,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoCard.compact(
              video: video,
              progress: row.status == 'downloading' ? progress : null,
              onTap: () {
                if (row.status == 'completed') {
                  Navigator.pop(context);
                  openWatchPanel(ref, row.videoId);
                } else {
                  _showActions(context, ref);
                }
              },
              trailing: IconButton(
                icon: const Icon(LucideIcons.ellipsisVertical),
                onPressed: () => _showActions(context, ref),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                '${row.kind == 'audio'
                    ? 'Audio · '
                    : row.height == null
                    ? ''
                    : '${row.height}p · '}$status',
                style: AppTextStyles.meta.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider);
    showAppSheet<void>(
      context,
      title: 'Download',
      fit: true,
      builder: (ctx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.status == 'failed' || row.status == 'paused')
            AppSheetRow(
              icon: LucideIcons.refreshCw,
              label: 'Retry',
              onTap: () {
                Navigator.pop(ctx);
                manager.retry(row.id);
              },
            ),
          if (row.status == 'downloading' || row.status == 'queued')
            AppSheetRow(
              icon: LucideIcons.pause,
              label: 'Pause',
              onTap: () {
                Navigator.pop(ctx);
                manager.pause(row.id);
              },
            ),
          AppSheetRow(
            icon: LucideIcons.trash2,
            label: 'Remove download',
            onTap: () {
              Navigator.pop(ctx);
              manager.remove(row);
            },
          ),
        ],
      ),
    );
  }
}
