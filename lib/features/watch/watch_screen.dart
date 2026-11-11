import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/playback/playback_service.dart';
import '../../core/streams/stream_selector.dart';
import '../../features/shorts/shorts_screen.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/player/player_controls.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  PlaybackService? active;
  void _start(PlaybackService? service) {
    if (service == null || service == active) return;
    active = service;
    service.setLoop(false);
    service.play(PlayRequest(videoId: widget.id, mode: PlaybackMode.video));
  }

  @override
  void dispose() {
    active?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(playbackProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start(service);
    });
    final metadata = ref.watch(shortMetadataProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: AppSpacing.thumbnailRatio,
            child: service == null
                ? const Center(child: CircularProgressIndicator())
                : SharedPlayer(service: service),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: metadata.when(
              data: (v) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v?.title ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    v?.channelName ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
