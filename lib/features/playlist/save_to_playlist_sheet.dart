import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

Future<void> showSaveToPlaylistSheet(
  BuildContext context, {
  required String videoId,
  MediaCompanion? media,
}) {
  return showAppSheet<void>(
    context,
    fit: true,
    title: 'Save to',
    builder: (sheetContext, _) =>
        _SaveToPlaylistSheet(videoId: videoId, media: media),
  );
}

class _SaveToPlaylistSheet extends ConsumerStatefulWidget {
  const _SaveToPlaylistSheet({required this.videoId, this.media});

  final String videoId;
  final MediaCompanion? media;

  @override
  ConsumerState<_SaveToPlaylistSheet> createState() =>
      _SaveToPlaylistSheetState();
}

class _SaveToPlaylistSheetState extends ConsumerState<_SaveToPlaylistSheet> {
  final Map<int, bool> _membership = {};
  List<PlaylistRow> _playlists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final db = ref.read(dbProvider);
      await db.playlistsDao.getOrCreateWatchLater();
      final playlists = await db.playlistsDao.getPlaylists();
      final membership = <int, bool>{};
      for (final playlist in playlists) {
        membership[playlist.id] = await db.playlistsDao.isInPlaylist(
          playlist.id,
          widget.videoId,
        );
      }
      playlists.sort((a, b) {
        final aWatchLater = a.remoteId == 'watch_later';
        final bWatchLater = b.remoteId == 'watch_later';
        if (aWatchLater == bWatchLater) return 0;
        return aWatchLater ? -1 : 1;
      });
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _membership
          ..clear()
          ..addAll(membership);
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[SaveToPlaylist] load failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _togglePlaylist(PlaylistRow playlist) async {
    final wasSaved = _membership[playlist.id] ?? false;
    setState(() => _membership[playlist.id] = !wasSaved);
    try {
      final dao = ref.read(dbProvider).playlistsDao;
      if (wasSaved) {
        await dao.removePlaylistItem(playlist.id, widget.videoId);
      } else {
        await dao.addPlaylistItem(
          playlist.id,
          widget.videoId,
          mediaItem: widget.media,
        );
      }
      if (mounted) {
        AppSnackbar.show(
          context,
          wasSaved
              ? 'Removed from ${playlist.name}'
              : 'Saved to ${playlist.name}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[SaveToPlaylist] toggle failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _membership[playlist.id] = wasSaved);
      AppSnackbar.showError(context, 'Could not update ${playlist.name}');
    }
  }

  Future<void> _createNewPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'New playlist',
        content: ClipRRect(
          borderRadius: AppRadius.mdBorder,
          child: ColoredBox(
            color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Playlist name',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ),
        ),
        actions: [
          AppButton.text(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton.text(
            label: 'Create',
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    try {
      final dao = ref.read(dbProvider).playlistsDao;
      final id = await dao.createPlaylist(name);
      await dao.addPlaylistItem(id, widget.videoId, mediaItem: widget.media);
      final playlist = await dao.getPlaylist(id);
      if (!mounted || playlist == null) return;
      setState(() {
        _playlists = [playlist, ..._playlists];
        _membership[id] = true;
      });
      AppSnackbar.show(context, 'Saved to $name');
    } catch (error, stackTrace) {
      debugPrint('[SaveToPlaylist] create failed: $error\n$stackTrace');
      if (mounted) AppSnackbar.showError(context, 'Could not create playlist');
    }
  }

  Widget _newPlaylistRow() => InkWell(
    onTap: _createNewPlaylist,
    child: SizedBox(
      height: AppSizes.settingsRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              LucideIcons.plus,
              size: AppSizes.icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xxl),
            Text('New playlist', style: AppTextStyles.settingsTitle),
          ],
        ),
      ),
    ),
  );

  Widget _playlistRow(PlaylistRow playlist) {
    final selected = _membership[playlist.id] ?? false;
    return InkWell(
      key: ValueKey('save-playlist:${playlist.id}'),
      onTap: () => _togglePlaylist(playlist),
      child: SizedBox(
        height: AppSizes.settingsRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(
                playlist.remoteId == 'watch_later'
                    ? LucideIcons.clock3
                    : LucideIcons.listMusic,
                size: AppSizes.icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.settingsTitle,
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (_) => _togglePlaylist(playlist),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _newPlaylistRow(),
        if (_loading)
          const PlaylistSheetSkeleton()
        else if (_error != null)
          InlineBanner(
            message: 'Could not load playlists',
            actionLabel: 'Retry',
            onAction: _loadStatus,
          )
        else if (_playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('No playlists available'),
          )
        else
          for (final playlist in _playlists) _playlistRow(playlist),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );
}
