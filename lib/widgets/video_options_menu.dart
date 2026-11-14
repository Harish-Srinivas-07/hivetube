import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../core/db/app_db.dart';
import '../core/providers.dart';
import '../features/playlist/save_to_playlist_sheet.dart';
import 'sheets/app_sheet.dart';
import 'ui/app_feedback.dart';

/// Content actions can be supplied by the caller; unavailable actions are omitted.
Future<void> showVideoOptionsMenu(
  BuildContext context, {
  required String videoId,
  VoidCallback? onPlayNext,
  VoidCallback? onAddToQueue,
  bool onVideo = false,
  WidgetRef? ref,
  MediaCompanion? media,
}) async {
  final action = await showAppSheet<String>(
    context,
    fit: true,
    onVideo: onVideo,
    builder: (sheetContext, _) => ListView(
      shrinkWrap: true,
      children: [
        if (onPlayNext != null)
          AppSheetRow(
            icon: LucideIcons.listStart,
            label: 'Play next',
            onTap: () => Navigator.pop(sheetContext, 'next'),
          ),
        if (onAddToQueue != null)
          AppSheetRow(
            icon: LucideIcons.listPlus,
            label: 'Add to queue',
            onTap: () => Navigator.pop(sheetContext, 'queue'),
          ),
        AppSheetRow(
          icon: LucideIcons.bookmark,
          label: 'Save to playlist',
          onTap: () => Navigator.pop(sheetContext, 'save_playlist'),
        ),
        AppSheetRow(
          icon: LucideIcons.clock,
          label: 'Save to Watch Later',
          onTap: () => Navigator.pop(sheetContext, 'watch_later'),
        ),
        AppSheetRow(
          icon: LucideIcons.share,
          label: 'Share',
          onTap: () => Navigator.pop(sheetContext, 'share'),
        ),
        AppSheetRow(
          icon: LucideIcons.copy,
          label: 'Copy link',
          onTap: () => Navigator.pop(sheetContext, 'copy'),
        ),
      ],
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case 'next':
      onPlayNext?.call();
    case 'queue':
      onAddToQueue?.call();
    case 'save_playlist':
      await showSaveToPlaylistSheet(context, videoId: videoId, media: media);
    case 'watch_later':
      if (ref != null) {
        final db = ref.read(dbProvider);
        final wl = await db.playlistsDao.getOrCreateWatchLater();
        await db.playlistsDao.addPlaylistItem(wl.id, videoId, mediaItem: media);
        if (context.mounted) {
          AppSnackbar.show(context, 'Saved to Watch Later');
        }
      }
    case 'share':
      unawaited(
        SharePlus.instance.share(
          ShareParams(
            uri: Uri.https('www.youtube.com', '/watch', {'v': videoId}),
          ),
        ),
      );
    case 'copy':
      await Clipboard.setData(
        ClipboardData(
          text: Uri.https('www.youtube.com', '/watch', {
            'v': videoId,
          }).toString(),
        ),
      );
      if (context.mounted) {
        AppSnackbar.show(context, 'Link copied');
      }
  }
}
