import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:drift/drift.dart' show Value;
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/takeout_parser.dart';
import '../watch/mini_player_inset.dart';
import '../../widgets/ui/ui.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final Set<String> _historyMetadataBackfills = {};

  Future<void> _backfillHistoryMetadata(String videoId) async {
    if (!_historyMetadataBackfills.add(videoId)) return;
    final db = ref.read(dbProvider);
    try {
      final api = await ref.read(ytApiProvider.future);
      final info = await api.next.watch(videoId);
      await db.historyDao.updateMediaMetadata(
        videoId: videoId,
        title: info.title,
        channelId: info.channelId,
        channelName: info.channelName,
        thumbUrl: info.thumbnail.isNotEmpty
            ? info.thumbnail
            : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        durationSec: info.durationSec,
      );
    } catch (_) {
      await db.historyDao.updateMediaMetadata(
        videoId: videoId,
        title: 'Untitled video',
        channelId: '',
        channelName: '',
        thumbUrl: '',
      );
    }
  }

  Future<void> _editProfile(ProfileRow? current) async {
    final controller = TextEditingController(text: current?.name ?? 'HiveUser');
    String? avatarPath = current?.avatarPath;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Edit profile',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final file = await FilePicker.pickFile(type: FileType.image);
                  if (file != null && file.path != null) {
                    setDialogState(() => avatarPath = file.path);
                  }
                },
                child: CircleAvatar(
                  radius: AppSizes.avatarLg / 2,
                  backgroundImage:
                      avatarPath != null && File(avatarPath!).existsSync()
                      ? FileImage(File(avatarPath!)) as ImageProvider
                      : null,
                  child: avatarPath == null
                      ? const Icon(LucideIcons.camera, size: AppSizes.avatarSm)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ],
          ),
          actions: [
            AppButton.text(
              onPressed: () => Navigator.of(ctx).pop(false),
              label: 'Cancel',
            ),
            AppButton.filled(
              onPressed: () => Navigator.of(ctx).pop(true),
              label: 'Save',
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      final db = ref.read(dbProvider);
      await db.profileDao.setProfile(
        name: controller.text.trim().isEmpty
            ? 'HiveUser'
            : controller.text.trim(),
        avatarPath: avatarPath,
      );
    }
  }

  Future<void> _showBackupSheet() async {
    final backupService = ref.read(backupServiceProvider);

    showAppSheet<void>(
      context,
      fit: true,
      title: 'Backup & Restore',
      builder: (bCtx, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.download),
            title: const Text('Export JSON backup'),
            subtitle: const Text(
              'Export subscriptions, history, playlists and reactions',
            ),
            onTap: () async {
              Navigator.of(bCtx).pop();
              final json = await backupService.exportJson();
              await SharePlus.instance.share(
                ShareParams(text: json, subject: 'hivetube_backup.json'),
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.upload),
            title: const Text('Import JSON backup'),
            subtitle: const Text(
              'Restore from a previously exported JSON backup',
            ),
            onTap: () async {
              Navigator.of(bCtx).pop();
              _importBackupJson();
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.fileSpreadsheet),
            title: const Text('Import Google Takeout subscriptions.csv'),
            subtitle: const Text(
              'Import YouTube subscriptions exported from Google Takeout',
            ),
            onTap: () async {
              Navigator.of(bCtx).pop();
              _importTakeoutCsv();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importBackupJson() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;

      final content = file.path != null
          ? await File(file.path!).readAsString()
          : await file.xFile.readAsString();

      final backupService = ref.read(backupServiceProvider);
      final preview = backupService.inspectJson(content);

      if (!mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (dCtx) => AppDialog(
          title: 'Restore backup',
          content: Text(
            'Found in backup:\n'
            '• ${preview.subscriptionCount} subscriptions\n'
            '• ${preview.playlistCount} playlists\n'
            '• ${preview.historyCount} history items\n'
            '• ${preview.reactionCount} reactions\n\n'
            'Would you like to merge with existing data or replace?',
          ),
          actions: [
            AppButton.text(
              onPressed: () => Navigator.of(dCtx).pop('cancel'),
              label: 'Cancel',
            ),
            AppButton.outlined(
              onPressed: () => Navigator.of(dCtx).pop('replace'),
              label: 'Replace all',
            ),
            AppButton.filled(
              onPressed: () => Navigator.of(dCtx).pop('merge'),
              label: 'Merge',
            ),
          ],
        ),
      );

      if (mode == 'merge' || mode == 'replace') {
        await backupService.importJson(content, replace: mode == 'replace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup restored successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import backup: $e')));
      }
    }
  }

  Future<void> _importTakeoutCsv() async {
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
            const SnackBar(content: Text('No subscriptions found in CSV.')),
          );
        }
        return;
      }

      final db = ref.read(dbProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      var added = 0;
      await db.transaction(() async {
        for (final item in parsed) {
          final existing = await db.subscriptionsDao.getSubscription(
            item.channelId,
          );
          if (existing == null) {
            await db
                .into(db.subscriptions)
                .insert(
                  SubscriptionsCompanion.insert(
                    channelId: item.channelId,
                    name: item.title,
                    avatarUrl: '',
                    subscribedAt: now,
                    lastFeedAt: const Value(0),
                  ),
                );
            added++;
          } else if ((existing.name.isEmpty ||
                  existing.name == existing.channelId) &&
              item.title != item.channelId) {
            await (db.update(db.subscriptions)
                  ..where((row) => row.channelId.equals(item.channelId)))
                .write(SubscriptionsCompanion(name: Value(item.title)));
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $added subscriptions${parsed.length > added ? ' (${parsed.length - added} already existed)' : ''}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import Takeout CSV: $e')),
        );
      }
    }
  }

  Future<void> _createPlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'New playlist',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist title...'),
        ),
        actions: [
          AppButton.text(
            onPressed: () => Navigator.of(ctx).pop(),
            label: 'Cancel',
          ),
          AppButton.filled(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            label: 'Create',
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      final id = await ref.read(dbProvider).playlistsDao.createPlaylist(name);
      if (mounted) {
        context.push('/playlist/$id');
      }
    }
  }

  Widget _libraryTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? count,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppSizes.libraryRowHeight,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppSizes.icon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.libraryRowTitle.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  count,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(PlaylistRow playlist) => Consumer(
    builder: (context, ref, _) {
      final theme = Theme.of(context);
      final items = ref.watch(playlistItemsStreamProvider(playlist.id));
      final count = items.asData?.value.length;

      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: InkWell(
          onTap: () => context.push('/playlist/${playlist.id}'),
          child: SizedBox(
            width: AppSizes.horizontalThumbCardHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.libraryThumbnailBorder,
                  child: SizedBox.square(
                    dimension: AppSizes.horizontalThumbCardHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (playlist.thumbUrl?.isNotEmpty == true)
                          CachedNetworkImage(
                            imageUrl: playlist.thumbUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                LucideIcons.listMusic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              LucideIcons.listMusic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Positioned(
                          right: AppSpacing.xs,
                          bottom: AppSpacing.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.thumbnailBadge,
                              borderRadius: AppRadius.xsBorder,
                            ),
                            child: Text(
                              '${count ?? 0} videos',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.thumbnailBadgeText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(tabRefreshProvider, (_, request) {
      if (request?.index != 3) return;
      ref.invalidate(profileStreamProvider);
      ref.invalidate(historyStreamProvider);
      ref.invalidate(playlistsStreamProvider);
      ref.invalidate(likedVideosStreamProvider);
      ref.invalidate(subscriptionsStreamProvider);
    });
    final profileAsync = ref.watch(profileStreamProvider);
    final historyAsync = ref.watch(historyStreamProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final likedVideosAsync = ref.watch(likedVideosStreamProvider);
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider);
    final theme = Theme.of(context);
    final playlists = playlistsAsync.asData?.value ?? const <PlaylistRow>[];
    PlaylistRow? watchLaterPlaylist;
    for (final playlist in playlists) {
      if (playlist.remoteId == 'watch_later') {
        watchLaterPlaylist = playlist;
        break;
      }
    }
    final watchLaterItems = watchLaterPlaylist == null
        ? null
        : ref.watch(playlistItemsStreamProvider(watchLaterPlaylist.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('You'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: profileAsync.when(
                data: (profile) {
                  final avatarPath = profile?.avatarPath;
                  final hasAvatar =
                      avatarPath != null && File(avatarPath).existsSync();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: AppSizes.avatarLg / 2,
                            backgroundImage: hasAvatar
                                ? FileImage(File(avatarPath))
                                : null,
                            child: hasAvatar
                                ? null
                                : const Icon(
                                    LucideIcons.user,
                                    size: AppSizes.iconLg,
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.name ?? 'HiveUser',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.profileName.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Local profile',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _editProfile(profile),
                            icon: const Icon(LucideIcons.pencil),
                            label: const Text('Edit profile'),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: theme.colorScheme.onSurface,
                              minimumSize: Size.fromHeight(
                                AppSizes.buttonCompact,
                              ),
                              side: BorderSide.none,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadius.profileChipBorder,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _showBackupSheet,
                            icon: const Icon(LucideIcons.hardDriveDownload),
                            label: const Text('Backup'),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: theme.colorScheme.onSurface,
                              minimumSize: Size.fromHeight(
                                AppSizes.buttonCompact,
                              ),
                              side: BorderSide.none,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadius.profileChipBorder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: AppSizes.listRowHeight),
                error: (_, _) => const SizedBox(height: AppSizes.listRowHeight),
              ),
            ),
            SectionHeader(
              title: 'History',
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              trailing: TextButton(
                onPressed: () => context.push('/history'),
                child: const Text('View all'),
              ),
            ),
            historyAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.history,
                    title: 'No watch history yet',
                    actionLabel: 'Explore videos',
                    onAction: () => context.go('/home'),
                    compact: true,
                  );
                }
                return SizedBox(
                  height: AppSizes.libraryHistoryCardWidth + AppSpacing.md,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: items.take(15).length,
                    itemBuilder: (ctx, idx) {
                      final item = items[idx];
                      if (item.media == null ||
                          item.media!.title.isEmpty ||
                          item.media!.title == item.history.videoId) {
                        unawaited(
                          _backfillHistoryMetadata(item.history.videoId),
                        );
                      }
                      final thumbUrl =
                          item.media?.thumbUrl ??
                          'https://i.ytimg.com/vi/${item.history.videoId}/hqdefault.jpg';
                      final pos = item.history.positionMs;
                      final dur = item.history.durationMs;
                      final progress = dur > 0
                          ? (pos / dur).clamp(0.0, 1.0)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: InkWell(
                          onTap: () =>
                              context.push('/watch/${item.history.videoId}'),
                          child: SizedBox(
                            width: AppSizes.libraryHistoryCardWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ThumbnailWithDuration(
                                  url: thumbUrl,
                                  progress: progress,
                                  borderRadius:
                                      AppRadius.libraryThumbnailBorder,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  item.media?.title.isNotEmpty == true &&
                                          item.media?.title !=
                                              item.history.videoId
                                      ? item.media!.title
                                      : 'Untitled video',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  item.media?.channelName.isNotEmpty == true
                                      ? item.media!.channelName
                                      : 'Unknown channel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
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
              },
              loading: () =>
                  const SizedBox(height: AppSizes.horizontalThumbCardHeight),
              error: (_, _) =>
                  const SizedBox(height: AppSizes.horizontalThumbCardHeight),
            ),

            SectionHeader(
              title: 'Playlists',
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              trailing: TextButton.icon(
                onPressed: _createPlaylistDialog,
                icon: const Icon(LucideIcons.plus, size: AppSizes.iconSm),
                label: const Text('Create'),
              ),
            ),
            playlistsAsync.when(
              data: (items) {
                final userPlaylists = items
                    .where((playlist) => playlist.remoteId != 'watch_later')
                    .toList();
                if (userPlaylists.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.listMusic,
                    title: 'Create a playlist to save videos',
                    actionLabel: 'Create playlist',
                    onAction: _createPlaylistDialog,
                    compact: true,
                  );
                }
                return SizedBox(
                  height:
                      AppSizes.horizontalThumbCardHeight +
                      AppSizes.listRowHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: userPlaylists.length,
                    itemBuilder: (context, index) =>
                        _buildPlaylistTile(userPlaylists[index]),
                  ),
                );
              },
              loading: () =>
                  const SizedBox(height: AppSizes.horizontalThumbCardHeight),
              error: (_, _) =>
                  const SizedBox(height: AppSizes.horizontalThumbCardHeight),
            ),

            // Liked Videos Tile
            likedVideosAsync.when(
              data: (liked) => _libraryTile(
                icon: LucideIcons.thumbsUp,
                title: 'Liked videos',
                count: '${liked.length}',
                onTap: () => context.push('/playlist/liked'),
              ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),

            _libraryTile(
              icon: LucideIcons.clock,
              title: 'Watch later',
              count: '${watchLaterItems?.asData?.value.length ?? 0}',
              onTap: () => context.push('/playlist/watch_later'),
            ),
            subscriptionsAsync.when(
              data: (subscriptions) => _libraryTile(
                icon: LucideIcons.circlePlay,
                title: 'Subscriptions',
                count: '${subscriptions.length}',
                onTap: () => context.push('/subscriptions'),
              ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
            _libraryTile(
              icon: LucideIcons.download,
              title: 'Downloads',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Downloads are not available yet'),
                  ),
                );
              },
            ),
            SizedBox(
              height:
                  MediaQuery.paddingOf(context).bottom +
                  MiniPlayerInset.of(context) +
                  AppSpacing.xl,
            ),
          ],
        ),
      ),
    );
  }
}
