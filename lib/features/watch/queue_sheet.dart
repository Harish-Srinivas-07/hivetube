import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/playback/session_queue.dart';
import '../../core/yt/models.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui/ui.dart';

Future<void> showQueueSheet(
  BuildContext context, {
  required VideoItem current,
  required ValueChanged<String> onPlay,
}) async {
  await showAppSheet<void>(
    context,
    title: 'Queue',
    headerAction: TextButton(
      onPressed: () => _clearQueue(context),
      child: const Text('Clear'),
    ),
    fraction: 0.7,
    builder: (context, controller) => _QueueSheetBody(
      current: current,
      onPlay: onPlay,
      scrollController: controller,
    ),
  );
}

void _clearQueue(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(sessionQueueProvider.notifier).clear();
}

class _QueueSheetBody extends ConsumerWidget {
  const _QueueSheetBody({
    required this.current,
    required this.onPlay,
    required this.scrollController,
  });

  final VideoItem current;
  final ValueChanged<String> onPlay;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(sessionQueueProvider);
    if (queue.isEmpty) {
      return ListView(
        controller: scrollController,
        children: [
          _CurrentVideoRow(video: current),
          const SizedBox(
            height: AppSizes.compactRowMinHeight,
            child: Center(child: Text('Queue is empty')),
          ),
        ],
      );
    }
    return ReorderableListView.builder(
      scrollController: scrollController,
      itemCount: queue.length,
      header: _CurrentVideoRow(video: current),
      onReorderItem: ref.read(sessionQueueProvider.notifier).reorder,
      itemBuilder: (context, index) {
        final entry = queue[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey('queue:${entry.video.id}'),
          index: index,
          child: VideoCard.compact(
            video: entry.video,
            onTap: () {
              ref.read(sessionQueueProvider.notifier).remove(entry.video.id);
              Navigator.of(context).pop();
              onPlay(entry.video.id);
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.gripVertical, size: AppSizes.iconSm),
                IconButton(
                  tooltip: 'Remove from queue',
                  icon: const Icon(LucideIcons.x, size: AppSizes.iconSm),
                  onPressed: () => ref
                      .read(sessionQueueProvider.notifier)
                      .remove(entry.video.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrentVideoRow extends StatelessWidget {
  const _CurrentVideoRow({required this.video});

  final VideoItem video;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(LucideIcons.circlePlay, size: AppSizes.icon),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      video.channelName.isEmpty
          ? 'Now playing'
          : 'Now playing · ${video.channelName}',
    ),
  );
}
