import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_spacing.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../widgets/ui/ui.dart';

Future<void> showSaveToPlaylistSheet(
  BuildContext context, {
  required String videoId,
  MediaCompanion? media,
}) {
  return showAppSheet<void>(
    context,
    fit: true,
    title: 'Save video to...',
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
      builder: (ctx) => AppDialog(
        title: 'New playlist',
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter title...'),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButton(
            label: 'Create',
            variant: AppButtonVariant.filled,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'New playlist',
                  icon: LucideIcons.plus,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.compact,
                  onPressed: _createNewPlaylist,
                ),
              ),
            ),
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
