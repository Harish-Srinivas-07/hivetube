import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/downloads/download_manager.dart';
import '../../core/downloads/download_export.dart';
import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../core/yt/watch_info.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import '../watch/watch_panel.dart';
import '../watch/mini_player_inset.dart';

void _downloadFeedback(BuildContext context, String message) {
  final hasBottomNav =
      shellRouteVisible.value &&
      MediaQuery.sizeOf(context).shortestSide < AppSpacing.navigationBreakpoint;
  AppSnackbar.show(
    context,
    message,
    extraBottom: hasBottomNav
        ? AppSizes.navHeight +
              AppSpacing.sm +
              MediaQuery.paddingOf(context).bottom
        : 0,
  );
}

Future<void> showDownloadChoices(
  BuildContext context,
  WidgetRef ref,
  MediaCompanion media, {
  WatchInfo? info,
  VideoItem? video,
}) async {
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
    final existing =
        await (ref.read(dbProvider).select(ref.read(dbProvider).downloads)
              ..where((row) => row.videoId.equals(media.videoId.value))
              ..where((row) => row.kind.equals(choice)))
            .get();
    if (!context.mounted) return;
    if (existing.isNotEmpty) {
      final row = existing.last;
      if (row.status == 'failed' || row.status == 'paused') {
        await manager.retry(row.id);
        if (context.mounted) _downloadFeedback(context, 'Download queued');
      } else if (row.status == 'completed') {
        _downloadFeedback(context, 'Already downloaded');
      } else {
        _downloadFeedback(context, 'Already in downloads');
      }
      return;
    }
    int? height;
    if (choice == 'video') {
      List<int> heights;
      try {
        heights = await manager.availableVideoHeights(media.videoId.value);
      } catch (_) {
        if (context.mounted) {
          _downloadFeedback(
            context,
            'Could not load video quality. Check your connection.',
          );
        }
        return;
      }
      if (!context.mounted) return;
      if (heights.isEmpty) {
        _downloadFeedback(context, 'No video quality is available');
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
    if (info == null) {
      try {
        info = await (await ref.read(
          ytApiProvider.future,
        )).next.watch(media.videoId.value);
      } catch (_) {
        if (video != null) {
          info = WatchInfo(
            id: video.id,
            title: video.title,
            channelName: video.channelName,
            channelId: video.channelId,
            avatar: video.channelAvatarUrl,
            subscribers: '',
            description: '',
            likes: '',
            views: video.viewsText,
            date: video.publishedText,
            handle: '',
            commentsToken: null,
            related: const VideoPage([], null),
            chapters: const [],
            chips: const {},
            thumbnail: video.thumbUrl,
          );
        }
      }
    }
    final details = info;
    final savedMedia = details == null
        ? media
        : media.copyWith(
            title: Value(details.title),
            channelId: Value(details.channelId),
            channelName: Value(details.channelName),
            durationSec: Value(details.durationSec),
            thumbUrl: Value(
              details.thumbnail.isNotEmpty
                  ? details.thumbnail
                  : media.thumbUrl.value,
            ),
          );
    await manager.enqueue(
      savedMedia,
      audioOnly: choice == 'audio',
      height: height,
      info: details,
      onQueued: () {
        if (context.mounted) _downloadFeedback(context, 'Added to downloads');
      },
    );
  } catch (_) {
    if (context.mounted) {
      _downloadFeedback(context, 'Could not queue download');
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
        return FutureBuilder<Map<String, dynamic>>(
          future: ref.read(downloadManagerProvider).metadata.read(row.videoId),
          builder: (context, metadataSnapshot) {
            final metadata = metadataSnapshot.data ?? {};
            final video = VideoItem(
              id: row.videoId,
              title: media?.title ?? row.videoId,
              channelId: media?.channelId ?? '',
              channelName: media?.channelName ?? '',
              thumbUrl:
                  metadata['thumbnail'] as String? ?? media?.thumbUrl ?? '',
              channelAvatarUrl: metadata['avatar'] as String? ?? '',
              durationText: (media?.durationSec ?? 0) > 0
                  ? AppFormatters.formatDurationSeconds(media!.durationSec!)
                  : '',
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
                  thumbnailOverlay:
                      row.status == 'downloading' ||
                          (row.status == 'paused' && progress != null)
                      ? _DownloadProgressOverlay(progress: progress)
                      : null,
                  onTap: () {
                    if (row.status == 'completed') {
                      Navigator.pop(context);
                      openWatchPanel(ref, row.videoId);
                    } else {
                      _showActions(context, ref, media?.title ?? row.videoId);
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.ellipsisVertical),
                    onPressed: () =>
                        _showActions(context, ref, media?.title ?? row.videoId),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
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
      },
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, String title) {
    final manager = ref.read(downloadManagerProvider);
    showAppSheet<void>(
      context,
      title: 'Download',
      fit: true,
      builder: (ctx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.status == 'completed' && row.path != null)
            AppSheetRow(
              icon: LucideIcons.save,
              label: row.kind == 'video'
                  ? 'Save to Gallery and Downloads'
                  : 'Save to Downloads',
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(downloadExportProvider).export(row, title);
                  if (context.mounted) {
                    _downloadFeedback(
                      context,
                      row.kind == 'video'
                          ? 'Saved to Gallery and Downloads'
                          : 'Saved to Downloads',
                    );
                  }
                } on GalleryExportException {
                  if (context.mounted) {
                    _downloadFeedback(
                      context,
                      'Saved to Downloads, but Gallery save failed',
                    );
                  }
                } on UnsupportedError catch (error) {
                  if (context.mounted) {
                    _downloadFeedback(
                      context,
                      error.message ?? 'Unable to save this file',
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    _downloadFeedback(context, 'Could not save download');
                  }
                }
              },
            ),
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

class _DownloadProgressOverlay extends StatelessWidget {
  const _DownloadProgressOverlay({required this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final percentage = progress == null ? null : (progress! * 100).floor();
    return ColoredBox(
      color: AppColors.playerControlGlass,
      child: Center(
        child: SizedBox.square(
          dimension: AppSizes.touchMin,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: AppSpacing.xs,
                color: AppColors.white,
                backgroundColor: AppColors.shortsProgressTrack,
                semanticsLabel: 'Download progress',
              ),
              if (percentage != null)
                Text(
                  '$percentage%',
                  style: AppTextStyles.badge.copyWith(color: AppColors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
