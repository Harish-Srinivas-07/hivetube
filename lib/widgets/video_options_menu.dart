import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'app_menu.dart';

/// Content actions can be supplied by the caller; unavailable actions are omitted.
Future<void> showVideoOptionsMenu(
  BuildContext context, {
  required String videoId,
  VoidCallback? onPlayNext,
  VoidCallback? onAddToQueue,
  bool onVideo = false,
}) async {
  final action = await showAppMenu<String>(
    context: context,
    onVideo: onVideo,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      children: [
        if (onPlayNext != null)
          AppMenuRow(
            icon: LucideIcons.listStart,
            label: 'Play next',
            onTap: () => Navigator.pop(sheetContext, 'next'),
          ),
        if (onAddToQueue != null)
          AppMenuRow(
            icon: LucideIcons.listPlus,
            label: 'Add to queue',
            onTap: () => Navigator.pop(sheetContext, 'queue'),
          ),
        AppMenuRow(
          icon: LucideIcons.share,
          label: 'Share',
          onTap: () => Navigator.pop(sheetContext, 'share'),
        ),
        AppMenuRow(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link copied')));
      }
  }
}
