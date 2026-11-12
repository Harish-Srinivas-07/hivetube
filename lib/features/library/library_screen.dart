import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:drift/drift.dart' show Value;
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/takeout_parser.dart';
import '../../widgets/ui/ui.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Future<void> _editProfile(ProfileRow? current) async {
    final controller = TextEditingController(text: current?.name ?? 'HiveUser');
    String? avatarPath = current?.avatarPath;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
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
                  radius: 36,
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
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
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
        builder: (dCtx) => AlertDialog(
          title: const Text('Restore backup'),
          content: Text(
            'Found in backup:\n'
            '• ${preview.subscriptionCount} subscriptions\n'
            '• ${preview.playlistCount} playlists\n'
            '• ${preview.historyCount} history items\n'
            '• ${preview.reactionCount} reactions\n\n'
            'Would you like to merge with existing data or replace?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(dCtx).pop('replace'),
              child: const Text('Replace all'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dCtx).pop('merge'),
              child: const Text('Merge'),
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
      await db.transaction(() async {
        for (final item in parsed) {
          await db
              .into(db.subscriptions)
              .insertOnConflictUpdate(
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
          SnackBar(content: Text('Imported ${parsed.length} subscriptions!')),
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
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist title...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileStreamProvider);
    final historyAsync = ref.watch(historyStreamProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final likedVideosAsync = ref.watch(likedVideosStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('You'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.hardDriveDownload),
            tooltip: 'Backup & Restore',
            onPressed: _showBackupSheet,
          ),
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
            // Profile Card
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: profileAsync.when(
                data: (profile) => Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage:
                          profile?.avatarPath != null &&
                              File(profile!.avatarPath!).existsSync()
                          ? FileImage(File(profile.avatarPath!))
                                as ImageProvider
                          : null,
                      child: profile?.avatarPath == null
                          ? const Icon(LucideIcons.user, size: AppSizes.iconLg)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'HiveUser',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
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
                    OutlinedButton.icon(
                      onPressed: () => _editProfile(profile),
                      icon: const Icon(
                        LucideIcons.pencil,
                        size: AppSizes.iconXs,
                      ),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                loading: () => const SizedBox(height: AppSizes.listRowHeight),
                error: (_, _) => const SizedBox(height: AppSizes.listRowHeight),
              ),
            ),
            const Divider(),

            // History Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'History',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/history'),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            historyAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No watch history yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: items.take(15).length,
                    itemBuilder: (ctx, idx) {
                      final item = items[idx];
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
                            width: 150,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: AppRadius.mdBorder,
                                      child: SizedBox(
                                        width: 150,
                                        height: 84,
                                        child: CachedNetworkImage(
                                          imageUrl: thumbUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHigh,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (progress > 0)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                bottom: Radius.circular(
                                                  AppRadius.md,
                                                ),
                                              ),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight:
                                                AppSizes.progressBarHeight,
                                            backgroundColor:
                                                AppColors.thumbnailBadge,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  theme.colorScheme.primary,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  item.media?.title ?? item.history.videoId,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
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
            const Divider(),

            // Playlists Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Playlists',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _createPlaylistDialog,
                    icon: const Icon(LucideIcons.plus, size: AppSizes.iconXs),
                    label: const Text('New playlist'),
                  ),
                ],
              ),
            ),

            // Watch Later Tile
            ListTile(
              leading: const CircleAvatar(
                child: Icon(LucideIcons.clock, size: AppSizes.avatarXs),
              ),
              title: const Text('Watch Later'),
              subtitle: const Text('Saved videos'),
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: AppSizes.iconSm,
              ),
              onTap: () => context.push('/playlist/watch_later'),
            ),

            // Liked Videos Tile
            likedVideosAsync.when(
              data: (liked) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(LucideIcons.thumbsUp, size: AppSizes.avatarXs),
                ),
                title: const Text('Liked videos'),
                subtitle: Text('${liked.length} videos'),
                trailing: const Icon(
                  LucideIcons.chevronRight,
                  size: AppSizes.iconSm,
                ),
                onTap: () => context.push('/playlist/liked'),
              ),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),

            // User Playlists
            playlistsAsync.when(
              data: (playlists) {
                final userPlaylists = playlists
                    .where((p) => p.remoteId != 'watch_later')
                    .toList();
                return Column(
                  children: userPlaylists.map((pl) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(
                          LucideIcons.listMusic,
                          size: AppSizes.avatarXs,
                        ),
                      ),
                      title: Text(pl.name),
                      trailing: const Icon(
                        LucideIcons.chevronRight,
                        size: AppSizes.iconSm,
                      ),
                      onTap: () => context.push('/playlist/${pl.id}'),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
            const Divider(),

            // Downloads Placeholder
            ListTile(
              leading: const Icon(LucideIcons.download),
              title: const Text('Downloads'),
              subtitle: const Text('Coming in Phase 5'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.smBorder,
                ),
                child: Text('Soon', style: theme.textTheme.labelSmall),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Downloads will be available in Phase 5!'),
                  ),
                );
              },
            ),

            // Settings Tile
            ListTile(
              leading: const Icon(LucideIcons.settings),
              title: const Text('Settings'),
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: AppSizes.iconSm,
              ),
              onTap: () => context.push('/settings'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
