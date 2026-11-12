import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';

Future<void> showSaveToPlaylistSheet(
  BuildContext context, {
  required String videoId,
  MediaCompanion? media,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) =>
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final db = ref.read(dbProvider);
    await db.playlistsDao.getOrCreateWatchLater();
    final playlists = await db.playlistsDao.getPlaylists();
    for (final pl in playlists) {
      _membership[pl.id] = await db.playlistsDao.isInPlaylist(
        pl.id,
        widget.videoId,
      );
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePlaylist(PlaylistRow pl, bool current) async {
    final db = ref.read(dbProvider);
    setState(() => _membership[pl.id] = !current);

    if (current) {
      await db.playlistsDao.removePlaylistItem(pl.id, widget.videoId);
    } else {
      await db.playlistsDao.addPlaylistItem(
        pl.id,
        widget.videoId,
        mediaItem: widget.media,
      );
    }
  }

  Future<void> _createNewPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter title...'),
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
      final db = ref.read(dbProvider);
      final id = await db.playlistsDao.createPlaylist(name);
      await db.playlistsDao.addPlaylistItem(
        id,
        widget.videoId,
        mediaItem: widget.media,
      );
      setState(() {
        _membership[id] = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Save video to...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _createNewPlaylist,
                    icon: const Icon(LucideIcons.plus, size: AppSizes.iconSm),
                    label: const Text('New playlist'),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('No playlists available'),
                    );
                  }
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (ctx, idx) {
                        final pl = playlists[idx];
                        final isChecked = _membership[pl.id] ?? false;
                        final isWatchLater = pl.remoteId == 'watch_later';
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(pl.name),
                          secondary: Icon(
                            isWatchLater
                                ? LucideIcons.clock
                                : LucideIcons.listMusic,
                          ),
                          onChanged: (_) => _togglePlaylist(pl, isChecked),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Error loading playlists: $e'),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
