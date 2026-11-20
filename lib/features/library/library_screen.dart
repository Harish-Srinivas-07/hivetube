import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:drift/drift.dart' show Value;
import '../../theme/app_sizes.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_motion.dart';
import 'library_skeleton.dart';
import '../downloads/downloads_screen.dart';
import '../playlist/playlist_dialog_content.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/takeout_parser.dart';
import '../../core/yt/models.dart';
import '../watch/mini_player_inset.dart';
import '../watch/watch_panel.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/video_options_menu.dart';
import '../../widgets/home_top_bar.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _shimmer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final Set<String> _historyMetadataBackfills = {};
  String _libraryFilter = 'Recent';

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
                    backgroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    foregroundColor: Theme.of(ctx).colorScheme.surface,
                    backgroundImage:
                        avatarPath != null && File(avatarPath!).existsSync()
                        ? FileImage(File(avatarPath!))
                        : null,
                    child: avatarPath == null || !File(avatarPath!).existsSync()
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
        content: PlaylistDialogContent(
          icon: LucideIcons.listPlus,
          title: 'New playlist',
          actionLabel: 'Create',
          onCancel: () => Navigator.of(ctx).pop(),
          onAction: () => Navigator.of(ctx).pop(controller.text.trim()),
          details: TextField(
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
        ),
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      final id = await ref.read(dbProvider).playlistsDao.createPlaylist(name);
      if (mounted) {
        context.push('/playlist/$id');
      }
    }
  }

  String _profileHandle(String name) {
    final compact = name.trim().replaceAll(RegExp(r'\s+'), '');
    return compact.isEmpty ? '@local' : '@$compact';
  }

  Widget _profileTopBar({required double topInset}) {
    final colors = Theme.of(context).colorScheme;
    return GlassAppBar(
      scrollController: _scrollController,
      topInset: topInset,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Library',
                style: AppTextStyles.pageTitle.copyWith(
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppIconButton(
              icon: LucideIcons.search,
              tooltip: 'Search',
              tonal: false,
              onPressed: () => context.push('/search'),
            ),
            AppIconButton(
              icon: LucideIcons.settings2,
              tooltip: 'Settings',
              tonal: false,
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(HistoryItemWithMedia item) {
    final id = item.history.videoId;
    final media = item.media;
    if (media == null || media.title.isEmpty || media.title == id) {
      unawaited(_backfillHistoryMetadata(id));
    }
    final video = VideoItem(
      id: id,
      title: media?.title.isNotEmpty == true && media?.title != id
          ? media!.title
          : 'Untitled video',
      channelName: media?.channelName ?? '',
      thumbUrl: media?.thumbUrl.isNotEmpty == true
          ? media!.thumbUrl
          : 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
      durationText: media?.durationSec == null
          ? ''
          : AppFormatters.formatDurationSeconds(media!.durationSec!),
    );
    final durationMs = item.history.durationMs;
    final progress = durationMs > 0
        ? (item.history.positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: AppSizes.libraryHistoryCardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => openWatchPanel(ref, id),
            child: ThumbnailWithDuration(
              url: video.thumbUrl,
              videoId: id,
              duration: video.durationText,
              progress: progress,
              borderRadius: AppRadius.mdBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => openWatchPanel(ref, id),
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitle.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
              AppIconButton(
                key: const ValueKey('historyVideoMenu'),
                icon: LucideIcons.ellipsisVertical,
                tooltip: 'More options',
                tonal: false,
                compact: true,
                onPressed: () => showVideoOptionsMenu(
                  context,
                  videoId: id,
                  ref: ref,
                  video: video,
                ),
              ),
            ],
          ),
          Text(
            video.channelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _showLibraryItemMenu(String title, VoidCallback onOpen) async {
    await showAppSheet<void>(
      context,
      fit: true,
      showClose: false,
      builder: (sheetContext, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetRow(
            icon: LucideIcons.arrowUpRight,
            label: 'Open $title',
            onTap: () {
              Navigator.pop(sheetContext);
              onOpen();
            },
          ),
        ],
      ),
    );
  }

  Widget _playlistRow(PlaylistRow playlist) => Consumer(
    builder: (context, ref, _) {
      final items = ref.watch(playlistItemsStreamProvider(playlist.id));
      final values = items.asData?.value ?? const <PlaylistItemWithMedia>[];
      final thumb = playlist.thumbUrl?.isNotEmpty == true
          ? playlist.thumbUrl!
          : values.firstOrNull?.media?.thumbUrl ?? '';
      return _LibraryEntryRow(
        key: ValueKey('playlist-${playlist.id}'),
        title: playlist.name,
        subtitle: '${values.length} videos',
        thumbnail: thumb,
        badgeIcon: LucideIcons.listVideo,
        onTap: () => context.push('/playlist/${playlist.id}'),
        onMore: () => _showLibraryItemMenu(
          playlist.name,
          () => context.push('/playlist/${playlist.id}'),
        ),
      );
    },
  );

  Widget _downloadsShortcut({bool showEmpty = false}) =>
      StreamBuilder<List<DownloadRow>>(
        stream: ref
            .read(dbProvider)
            .select(ref.read(dbProvider).downloads)
            .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LibraryRowSkeleton(animation: _shimmer);
          }
          if (snapshot.data?.isNotEmpty != true && !showEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: LucideIcons.download,
                title: 'No downloads',
                compact: true,
              ),
            );
          }
          void openDownloads() => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
          );
          return _LibraryEntryRow(
            key: const ValueKey('downloadsShortcut'),
            title: 'Downloads',
            subtitle: '${snapshot.data?.length ?? 0} items',
            thumbnail: '',
            badgeIcon: LucideIcons.download,
            onTap: openDownloads,
            onMore: openDownloads,
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
    final offline = ref.watch(isOfflineProvider);
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final likedVideosAsync = ref.watch(likedVideosStreamProvider);
    final playlists = playlistsAsync.asData?.value ?? const <PlaylistRow>[];
    final userPlaylists = playlists
        .where((playlist) => playlist.remoteId != 'watch_later')
        .toList();
    final watchLaterPlaylist = playlists
        .where((playlist) => playlist.remoteId == 'watch_later')
        .firstOrNull;
    final watchLaterItems = watchLaterPlaylist == null
        ? null
        : ref.watch(playlistItemsStreamProvider(watchLaterPlaylist.id));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(profileStreamProvider);
                ref.invalidate(historyStreamProvider);
                ref.invalidate(playlistsStreamProvider);
                ref.invalidate(likedVideosStreamProvider);
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height:
                          AppSizes.appBarHeight +
                          MediaQuery.viewPaddingOf(context).top,
                    ),
                    profileAsync.when(
                      data: (value) {
                        final avatarPath = value?.avatarPath;
                        final hasAvatar =
                            avatarPath != null && File(avatarPath).existsSync();
                        final name = value?.name.trim().isNotEmpty == true
                            ? value!.name.trim()
                            : 'HiveUser';
                        return Padding(
                          key: const ValueKey('libraryHeader'),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                key: const ValueKey('libraryAvatar'),
                                radius: AppSizes.avatarLg / 2,
                                backgroundColor: colors.onSurfaceVariant,
                                backgroundImage: hasAvatar
                                    ? FileImage(File(avatarPath))
                                    : null,
                                child: hasAvatar
                                    ? null
                                    : Icon(
                                        LucideIcons.userRound,
                                        size: AppSizes.iconLg,
                                        color: colors.surface,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      key: const ValueKey('libraryName'),
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.profileName.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      _profileHandle(name),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.meta.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => LibraryHeaderSkeleton(animation: _shimmer),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: EmptyState(
                          icon: LucideIcons.userRound,
                          title: 'Unable to load profile',
                          actionLabel: 'Retry',
                          onAction: () => ref.invalidate(profileStreamProvider),
                          compact: true,
                        ),
                      ),
                    ),
                    profileAsync.when(
                      data: (value) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: AppSizes.buttonLarge,
                                child: FilledButton(
                                  onPressed: () => _editProfile(value),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.onSurface,
                                    foregroundColor: colors.surface,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Edit profile'),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: SizedBox(
                                height: AppSizes.buttonLarge,
                                child: FilledButton.tonal(
                                  onPressed: _showBackupSheet,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        colors.surfaceContainerHighest,
                                    foregroundColor: colors.onSurface,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Backup'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox(height: AppSpacing.lg),
                      error: (_, _) => const SizedBox(height: AppSpacing.lg),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (offline) _downloadsShortcut(showEmpty: true),
                    if (!historyAsync.isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: SectionHeader(
                          key: const ValueKey('historyHeader'),
                          title: 'History',
                          titleStyle: AppTextStyles.sectionTitle.copyWith(
                            color: colors.onSurface,
                          ),
                          padding: EdgeInsets.zero,
                          trailing: AppIconButton(
                            icon: LucideIcons.chevronRight,
                            tooltip: 'View history',
                            tonal: false,
                            onPressed: () => context.push('/history'),
                          ),
                        ),
                      ),
                    historyAsync.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.none,
                            ),
                            child: EmptyState(
                              icon: LucideIcons.history,
                              title: 'Videos you watch will show here',
                              compact: true,
                            ),
                          );
                        }
                        return SizedBox(
                          key: const ValueKey('historyShelf'),
                          height:
                              AppSizes.libraryHistoryCardWidth /
                                  AppSpacing.thumbnailRatio +
                              AppSizes.listRowHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            itemCount: items.take(15).length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.lg),
                            itemBuilder: (_, index) =>
                                _historyCard(items[index]),
                          ),
                        );
                      },
                      loading: () => LibraryShelfSkeleton(animation: _shimmer),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: EmptyState(
                          icon: LucideIcons.history,
                          title: 'Unable to load history',
                          actionLabel: 'Retry',
                          onAction: () => ref.invalidate(historyStreamProvider),
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: SectionHeader(
                        title: 'Library',
                        titleStyle: AppTextStyles.sectionTitle.copyWith(
                          color: colors.onSurface,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    AppChipBar(
                      children: [
                        AppChip(
                          label: 'Recent',
                          selected: _libraryFilter == 'Recent',
                          leading: const Icon(
                            LucideIcons.history,
                            size: AppSizes.iconXs,
                          ),
                          onTap: () =>
                              setState(() => _libraryFilter = 'Recent'),
                        ),
                        AppChip(
                          label: 'Downloaded',
                          selected: _libraryFilter == 'Downloaded',
                          leading: const Icon(
                            LucideIcons.download,
                            size: AppSizes.iconXs,
                          ),
                          onTap: () =>
                              setState(() => _libraryFilter = 'Downloaded'),
                        ),
                        AppChip(
                          label: 'Playlists',
                          selected: _libraryFilter == 'Playlists',
                          leading: const Icon(
                            LucideIcons.listVideo,
                            size: AppSizes.iconXs,
                          ),
                          onTap: () =>
                              setState(() => _libraryFilter = 'Playlists'),
                        ),
                      ],
                    ),
                    if (_libraryFilter == 'Downloaded')
                      offline ? const SizedBox.shrink() : _downloadsShortcut()
                    else ...[
                      if (_libraryFilter == 'Recent')
                        likedVideosAsync.when(
                          data: (liked) => _LibraryEntryRow(
                            key: const ValueKey('rowLiked'),
                            title: 'Liked videos',
                            subtitle: 'Private',
                            thumbnail: liked.firstOrNull?.thumbUrl ?? '',
                            badgeIcon: LucideIcons.thumbsUp,
                            onTap: () => context.push('/playlist/liked'),
                            onMore: () => _showLibraryItemMenu(
                              'Liked videos',
                              () => context.push('/playlist/liked'),
                            ),
                          ),
                          loading: () =>
                              LibraryRowSkeleton(animation: _shimmer),
                          error: (_, _) => EmptyState(
                            icon: LucideIcons.thumbsUp,
                            title: 'Unable to load liked videos',
                            actionLabel: 'Retry',
                            onAction: () =>
                                ref.invalidate(likedVideosStreamProvider),
                            compact: true,
                          ),
                        ),
                      if (_libraryFilter == 'Recent')
                        watchLaterItems?.isLoading == true
                            ? LibraryRowSkeleton(animation: _shimmer)
                            : _LibraryEntryRow(
                                key: const ValueKey('rowWatchLater'),
                                title: 'Watch later',
                                subtitle:
                                    '${watchLaterItems?.asData?.value.length ?? 0} videos',
                                thumbnail:
                                    watchLaterItems
                                        ?.asData
                                        ?.value
                                        .firstOrNull
                                        ?.media
                                        ?.thumbUrl ??
                                    watchLaterPlaylist?.thumbUrl ??
                                    '',
                                badgeIcon: LucideIcons.clock,
                                onTap: () =>
                                    context.push('/playlist/watch_later'),
                                onMore: () => _showLibraryItemMenu(
                                  'Watch later',
                                  () => context.push('/playlist/watch_later'),
                                ),
                              ),
                      if (_libraryFilter == 'Recent' ||
                          _libraryFilter == 'Playlists') ...[
                        if (playlistsAsync.isLoading)
                          LibraryRowSkeleton(animation: _shimmer)
                        else if (playlistsAsync.hasError)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: EmptyState(
                              icon: LucideIcons.listVideo,
                              title: 'Unable to load playlists',
                              actionLabel: 'Retry',
                              onAction: () =>
                                  ref.invalidate(playlistsStreamProvider),
                              compact: true,
                            ),
                          )
                        else ...[
                          _LibraryEntryRow(
                            key: const ValueKey('playlistsFirstCard'),
                            title: 'Create playlist',
                            subtitle: 'Add videos to a playlist',
                            thumbnail: '',
                            badgeIcon: LucideIcons.plus,
                            onTap: _createPlaylistDialog,
                            onMore: _createPlaylistDialog,
                          ),
                          for (final playlist in userPlaylists)
                            _playlistRow(playlist),
                        ],
                      ],
                    ],
                    SizedBox(
                      key: const ValueKey('libraryBottomInset'),
                      height:
                          MediaQuery.paddingOf(context).bottom +
                          AppSizes.bottomNav +
                          MiniPlayerInset.of(context) +
                          AppSpacing.xl,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.none,
              left: AppSpacing.none,
              right: AppSpacing.none,
              child: _profileTopBar(
                topInset: MediaQuery.viewPaddingOf(context).top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryEntryRow extends StatelessWidget {
  const _LibraryEntryRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.badgeIcon,
    required this.onTap,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final String thumbnail;
  final IconData badgeIcon;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSizes.listRowHeight + AppSpacing.md,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: AppSizes.searchCompactThumbnailWidth,
                child: AspectRatio(
                  aspectRatio: AppSpacing.thumbnailRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnail.trim().isEmpty
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: AppRadius.smBorder,
                              ),
                              child: Center(
                                child: Icon(
                                  badgeIcon,
                                  size: AppSizes.iconLg,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ThumbnailWithDuration(
                              url: thumbnail,
                              borderRadius: AppRadius.smBorder,
                            ),
                      if (thumbnail.trim().isNotEmpty)
                        Positioned(
                          right: AppSpacing.xs,
                          bottom: AppSpacing.xs,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: AppColors.badgeBg,
                              borderRadius: AppRadius.pillBorder,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: Icon(
                                badgeIcon,
                                size: AppSizes.iconXs,
                                color: AppColors.badgeFg,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.videoTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: LucideIcons.ellipsisVertical,
                tooltip: 'More options',
                tonal: false,
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
