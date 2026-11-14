import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:drift/drift.dart' show Value, BaseAggregate;
import '../../theme/app_sizes.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_motion.dart';
import 'library_skeleton.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/takeout_parser.dart';
import '../../core/yt/models.dart';
import '../watch/mini_player_inset.dart';
import '../../widgets/ui/ui.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: AppMotion.shimmerLoop,
  )..repeat(reverse: true);
  late final Stream<int> _historyCount = _watchHistoryCount();

  Stream<int> _watchHistoryCount() {
    final db = ref.read(dbProvider);
    final count = db.history.videoId.count();
    final query = db.selectOnly(db.history)
      ..addColumns([count])
      ..where(db.history.scope.equals('yt'));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

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

    final updated = await showAppSheet<bool>(
      context,
      title: 'Edit profile',
      fit: true,
      builder: (ctx, _) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: AppSizes.avatarLg / 2,
                    backgroundImage:
                        avatarPath != null && File(avatarPath!).existsSync()
                        ? FileImage(File(avatarPath!))
                        : null,
                    child: avatarPath == null
                        ? const Icon(LucideIcons.user)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  AppButton.tonal(
                    label: 'Change',
                    onPressed: () async {
                      final file = await FilePicker.pickFile(
                        type: FileType.image,
                      );
                      if (file?.path != null && ctx.mounted) {
                        setSheetState(() => avatarPath = file!.path);
                      }
                    },
                  ),
                  if (avatarPath != null)
                    AppButton.text(
                      label: 'Remove',
                      onPressed: () => setSheetState(() => avatarPath = null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                onChanged: (_) => setSheetState(() {}),
                decoration: InputDecoration(
                  labelText: 'Name',
                  filled: true,
                  fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.mdBorder,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.mdBorder,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.mdBorder,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.text(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  AppButton.filled(
                    label: 'Save',
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (updated == true && mounted && name.isNotEmpty) {
      await ref
          .read(dbProvider)
          .profileDao
          .setProfile(name: name, avatarPath: avatarPath);
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
          decoration: InputDecoration(
            hintText: 'Playlist title...',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: const OutlineInputBorder(
              borderRadius: AppRadius.mdBorder,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdBorder,
              borderSide: BorderSide.none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdBorder,
              borderSide: BorderSide.none,
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdBorder,
              borderSide: BorderSide.none,
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdBorder,
              borderSide: BorderSide.none,
            ),
          ),
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
    Key? key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? count,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      key: key,
      height: AppSizes.settingsRowHeight,
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
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.settingsTitle.copyWith(
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

  Widget _buildPlaylistTile(PlaylistRow playlist, {Key? key}) => Consumer(
    builder: (context, ref, _) {
      final items = ref.watch(playlistItemsStreamProvider(playlist.id));
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: PlaylistCard(
          key: key,
          title: playlist.name,
          thumbnail: playlist.thumbUrl ?? '',
          count: items.asData?.value.length ?? 0,
          onTap: () => context.push('/playlist/${playlist.id}'),
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileStreamProvider);
          ref.invalidate(historyStreamProvider);
          ref.invalidate(playlistsStreamProvider);
          ref.invalidate(likedVideosStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                key: const ValueKey('libraryHeader'),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: profileAsync.when(
                  data: (profile) {
                    final avatarPath = profile?.avatarPath;
                    final hasAvatar =
                        avatarPath != null && File(avatarPath).existsSync();
                    return Row(
                      children: [
                        CircleAvatar(
                          key: const ValueKey('libraryAvatar'),
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
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key: const ValueKey('libraryName'),
                                profile?.name ?? 'HiveUser',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.pageTitle.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              StreamBuilder<int>(
                                stream: _historyCount,
                                builder: (context, snapshot) => Text(
                                  '${snapshot.data ?? 0} videos watched · ${playlists.where((item) => item.remoteId != 'watch_later').length} playlists',
                                  style: AppTextStyles.meta.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => LibraryHeaderSkeleton(animation: _shimmer),
                  error: (_, _) => EmptyState(
                    icon: LucideIcons.user,
                    title: 'Unable to load profile',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(profileStreamProvider),
                    compact: true,
                  ),
                ),
              ),
              profileAsync.when(
                data: (profile) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.none,
                  ),
                  child: SizedBox(
                    height: AppSizes.buttonStandard,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        key: const ValueKey('libraryButtons'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton.tonal(
                            onPressed: () => _editProfile(profile),
                            label: 'Edit profile',
                            size: AppButtonSize.standard,
                            horizontalPadding: AppSpacing.md,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppButton.tonal(
                            onPressed: _showBackupSheet,
                            label: 'Backup',
                            size: AppButtonSize.standard,
                            horizontalPadding: AppSpacing.md,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                loading: () => const SizedBox(height: AppSpacing.xl),
                error: (_, _) => const SizedBox(height: AppSpacing.xl),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!historyAsync.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: SizedBox(
                    key: const ValueKey('historyHeader'),
                    height: AppSizes.touchMin,
                    child: SectionHeader(
                      title: 'History',
                      titleStyle: AppTextStyles.sectionTitle.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      padding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () => context.push('/history'),
                        child: const Text('View all'),
                      ),
                    ),
                  ),
                ),
              historyAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: EmptyState(
                          icon: LucideIcons.history,
                          title: 'Videos you watch will show here',
                          compact: true,
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    key: const ValueKey('historyShelf'),
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
                          child: SizedBox(
                            key: idx == 0
                                ? const ValueKey('historyFirstCard')
                                : null,
                            width: AppSizes.libraryHistoryCardWidth,
                            child: VideoCard.shelf(
                              key: ValueKey(item.history.videoId),
                              video: VideoItem(
                                id: item.history.videoId,
                                title:
                                    item.media?.title.isNotEmpty == true &&
                                        item.media?.title !=
                                            item.history.videoId
                                    ? item.media!.title
                                    : 'Untitled video',
                                channelName: item.media?.channelName ?? '',
                                thumbUrl: thumbUrl,
                              ),
                              progress: progress,
                              onTap: () => context.push(
                                '/watch/${item.history.videoId}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => LibraryShelfSkeleton(animation: _shimmer),
                error: (_, _) => EmptyState(
                  icon: LucideIcons.history,
                  title: 'Unable to load history',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(historyStreamProvider),
                  compact: true,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              if (!playlistsAsync.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: SizedBox(
                    key: const ValueKey('playlistsHeader'),
                    height: AppSizes.touchMin,
                    child: SectionHeader(
                      title: 'Playlists',
                      titleStyle: AppTextStyles.sectionTitle.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      padding: EdgeInsets.zero,
                      trailing: TextButton(
                        onPressed: () => showAppSheet<void>(
                          context,
                          title: 'Playlists',
                          fit: true,
                          builder: (sheetContext, _) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(LucideIcons.plus),
                                title: const Text('Create playlist'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _createPlaylistDialog();
                                },
                              ),
                              for (final playlist in playlists.where(
                                (item) => item.remoteId != 'watch_later',
                              ))
                                ListTile(
                                  title: Text(playlist.name),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    context.push('/playlist/${playlist.id}');
                                  },
                                ),
                            ],
                          ),
                        ),
                        child: const Text('View all'),
                      ),
                    ),
                  ),
                ),
              playlistsAsync.when(
                data: (items) {
                  final userPlaylists = items
                      .where((playlist) => playlist.remoteId != 'watch_later')
                      .toList();
                  if (userPlaylists.isEmpty) {
                    return _libraryTile(
                      key: const ValueKey('playlistsFirstCard'),
                      icon: LucideIcons.plus,
                      title: 'Create playlist',
                      onTap: _createPlaylistDialog,
                    );
                  }
                  return SizedBox(
                    key: const ValueKey('playlistsShelf'),
                    height:
                        AppSizes.horizontalThumbCardHeight +
                        AppSizes.listRowHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: userPlaylists.length,
                      itemBuilder: (context, index) => _buildPlaylistTile(
                        userPlaylists[index],
                        key: index == 0
                            ? const ValueKey('playlistsFirstCard')
                            : null,
                      ),
                    ),
                  );
                },
                loading: () => LibraryShelfSkeleton(animation: _shimmer),
                error: (_, _) => EmptyState(
                  icon: LucideIcons.listMusic,
                  title: 'Unable to load playlists',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(playlistsStreamProvider),
                  compact: true,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              StreamBuilder<List<DownloadRow>>(
                stream: ref
                    .read(dbProvider)
                    .select(ref.read(dbProvider).downloads)
                    .watch(),
                builder: (context, snapshot) =>
                    snapshot.connectionState == ConnectionState.waiting
                    ? LibraryRowSkeleton(animation: _shimmer)
                    : _libraryTile(
                        key: const ValueKey('rowDownloads'),
                        icon: LucideIcons.download,
                        title: 'Downloads',
                        count: '${snapshot.data?.length ?? 0}',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Downloads are not available yet'),
                          ),
                        ),
                      ),
              ),
              likedVideosAsync.when(
                data: (liked) => _libraryTile(
                  key: const ValueKey('rowLiked'),
                  icon: LucideIcons.thumbsUp,
                  title: 'Liked videos',
                  count: '${liked.length}',
                  onTap: () => context.push('/playlist/liked'),
                ),
                loading: () => LibraryRowSkeleton(animation: _shimmer),
                error: (_, _) => _libraryTile(
                  key: const ValueKey('rowLiked'),
                  icon: LucideIcons.thumbsUp,
                  title: 'Liked videos',
                  onTap: () => context.push('/playlist/liked'),
                ),
              ),

              if (watchLaterItems?.isLoading == true)
                LibraryRowSkeleton(animation: _shimmer)
              else
                _libraryTile(
                  key: const ValueKey('rowWatchLater'),
                  icon: LucideIcons.clock,
                  title: 'Watch later',
                  count: '${watchLaterItems?.asData?.value.length ?? 0}',
                  onTap: () => context.push('/playlist/watch_later'),
                ),
              if (historyAsync.isLoading)
                LibraryRowSkeleton(animation: _shimmer)
              else
                _libraryTile(
                  key: const ValueKey('rowStats'),
                  icon: LucideIcons.chartColumn,
                  title: 'Stats',
                  count: '${historyAsync.asData?.value.length ?? 0}',
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AppDialog(
                      title: 'Stats',
                      content: Text(
                        '${historyAsync.asData?.value.length ?? 0} videos watched',
                      ),
                      actions: [
                        AppButton.text(
                          label: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
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
      ),
    );
  }
}
