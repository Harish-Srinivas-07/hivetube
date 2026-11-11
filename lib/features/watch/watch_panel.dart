import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/playback/playback_service.dart';
import '../../core/playback/player_ui_state.dart';
import '../../core/playback/audio_handler.dart';
import '../../core/playback/watch_session.dart';
import '../../core/playback/player_interactions.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/streams/stream_selector.dart';
import '../../core/yt/models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/player/player_controls.dart';
import '../shorts/shorts_screen.dart';

final watchPanelProvider = NotifierProvider<WatchPanelController, String?>(
  WatchPanelController.new,
);

final watchPanelExpandProvider =
    NotifierProvider<WatchPanelExpandController, int>(
      WatchPanelExpandController.new,
    );

class WatchPanelExpandController extends Notifier<int> {
  @override
  int build() => 0;
  void expand() => state++;
}

class WatchPanelController extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String id) => state = id;
  void close() => state = null;
}

final relatedVideosProvider =
    AsyncNotifierProvider.family<
      RelatedVideosController,
      List<VideoItem>,
      String
    >(RelatedVideosController.new);

class RelatedVideosController extends AsyncNotifier<List<VideoItem>> {
  RelatedVideosController(this.id);
  final String id;
  @override
  Future<List<VideoItem>> build() async =>
      (await (await ref.watch(ytApiProvider.future)).next.related(id)).items;
}

class WatchPanel extends ConsumerStatefulWidget {
  const WatchPanel({super.key, this.videoOverride});
  @visibleForTesting
  final Widget? videoOverride;
  @override
  ConsumerState<WatchPanel> createState() => _WatchPanelState();
}

class MiniPlayerCloseButton extends StatelessWidget {
  const MiniPlayerCloseButton({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Close player',
    onPressed: onDismiss,
    icon: const Icon(LucideIcons.x),
  );
}

class _WatchPanelState extends ConsumerState<WatchPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  bool _skipHistory = false;
  bool dragging = false;
  String? started;
  PlaybackService? active;
  Timer? countdown;
  String? countdownId;
  String? cancelledAutoplayId;
  int remaining = 5;

  void _syncAutoplay(
    String id,
    PlaybackService? service,
    List<VideoItem> related,
    bool enabled,
  ) {
    if (service?.state.status != PlayerStatus.ended &&
        cancelledAutoplayId == id) {
      cancelledAutoplayId = null;
    }
    if (!enabled ||
        service?.state.status != PlayerStatus.ended ||
        related.isEmpty ||
        cancelledAutoplayId == id) {
      if (countdown != null) {
        countdown?.cancel();
        countdown = null;
        countdownId = null;
      }
      return;
    }
    if (countdownId == id) return;
    countdown?.cancel();
    countdownId = id;
    remaining = 5;
    countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          ref.read(watchPanelProvider) != id ||
          !ref.read(appSettingsProvider).autoplay) {
        timer.cancel();
        countdown = null;
        countdownId = null;
        return;
      }
      setState(() => remaining--);
      if (remaining <= 0) {
        timer.cancel();
        countdown = null;
        countdownId = null;
        _open(related.first.id);
      }
    });
  }

  void _previous(PlaybackService? service) {
    if (service == null) return;
    if (service.state.position > const Duration(seconds: 3)) {
      unawaited(service.seek(Duration.zero));
      return;
    }
    final previous = ref.read(watchSessionProvider.notifier).popPrevious();
    if (previous != null) _open(previous, record: false);
  }

  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, value: 0)
      ..addListener(() {
        ref.read(playerUiProvider.notifier).setPanelProgress(animation.value);
      });
  }

  void _animate(double target, [double velocity = 0]) {
    animation.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 450, damping: 38),
        animation.value,
        target,
        velocity,
      ),
    );
  }

  void _open(String id, {bool record = true}) {
    _skipHistory = !record;
    ref.read(watchPanelProvider.notifier).open(id);
    ref.read(playerUiProvider.notifier).setDismissed(false);
    _animate(0);
  }

  void _dismiss({bool stop = true}) {
    if (ref.read(playerUiProvider).isFullscreen) unawaited(_exitFullscreen());
    ref.read(watchPanelProvider.notifier).close();
    ref.read(playerUiProvider.notifier).setDismissed(true);
    ref.read(playerUiProvider.notifier).setFullscreen(false);
    started = null;
    if (stop) unawaited(active?.stop());
  }

  Future<void> _exitFullscreen() async {
    ref.read(playerUiProvider.notifier).setFullscreen(false);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _start(String id, PlaybackService? service) async {
    if (service == null || (started == id && identical(active, service))) {
      return;
    }
    started = id;
    active = service;
    if (!ref.read(watchSessionProvider).watched.contains(id)) {
      ref.read(watchSessionProvider.notifier).opened(null, id, record: false);
    }
    ref.read(playerUiProvider.notifier).setDismissed(false);
    final history = await ref.read(historyRepoProvider).recent();
    if (!mounted || ref.read(watchPanelProvider) != id || started != id) return;
    final saved = history.where((entry) => entry.videoId == id).firstOrNull;
    final start = resumePosition(saved);
    await service.setLoop(false);
    if (!mounted || ref.read(watchPanelProvider) != id || started != id) return;
    await service.play(
      PlayRequest(videoId: id, mode: PlaybackMode.video, startAt: start),
    );
  }

  @override
  void dispose() {
    countdown?.cancel();
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(watchPanelExpandProvider, (_, _) => _animate(0));
    ref.listen<String?>(watchPanelProvider, (previous, next) {
      if (next != null && next != previous) {
        ref
            .read(watchSessionProvider.notifier)
            .opened(previous, next, record: !_skipHistory);
        _skipHistory = false;
        ref.read(playerUiProvider.notifier).setDismissed(false);
        _animate(0);
      }
    });
    final id = ref.watch(watchPanelProvider);
    if (id == null) return const SizedBox.shrink();
    final service = ref.watch(playbackProvider);
    final ui = ref.watch(playerUiProvider);
    final metadata = ref.watch(shortMetadataProvider(id)).value;
    final related =
        ref.watch(relatedVideosProvider(id)).value ?? const <VideoItem>[];
    ref.watch(watchSessionProvider);
    final nextId = ref
        .read(watchSessionProvider.notifier)
        .firstUnplayed(related.map((v) => v.id));
    final unplayed = related.where((v) => v.id == nextId).toList();
    final autoplay = ref.watch(appSettingsProvider.select((s) => s.autoplay));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(watchPanelProvider) == id) {
        unawaited(_start(id, service));
        _syncAutoplay(id, service, unplayed, autoplay);
        final handler = ref.read(audioHandlerProvider);
        handler?.setMetadata(
          id,
          metadata?.title ?? '',
          metadata?.channelName ?? '',
        );
        handler?.onNext = () async {
          if (mounted && nextId != null) _open(nextId);
        };
        handler?.onPrevious = () async {
          if (mounted) _previous(service);
        };
      }
    });
    return PopScope(
      canPop: !ui.isFullscreen && animation.value >= .99,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ui.isFullscreen) {
          unawaited(_exitFullscreen());
        } else {
          _animate(1);
        }
      },
      child: LayoutBuilder(
        builder: (context, bounds) {
          final bottom =
              MediaQuery.paddingOf(context).bottom +
              AppSpacing.navHeight +
              AppSpacing.lg * 2;
          final miniY = bounds.maxHeight - bottom - 64;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final p = ui.isFullscreen ? 0.0 : animation.value;
              final videoWidth = lerpDouble(bounds.maxWidth, 114, p)!;
              final videoHeight = ui.isFullscreen
                  ? bounds.maxHeight
                  : lerpDouble(
                      bounds.maxWidth / AppSpacing.thumbnailRatio,
                      64,
                      p,
                    )!;
              final y = ui.isFullscreen
                  ? 0.0
                  : lerpDouble(MediaQuery.paddingOf(context).top, miniY, p)!;
              return Stack(
                children: [
                  if (p < .99 && !ui.isFullscreen)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: bottom,
                      child: IgnorePointer(
                        ignoring: p > .8,
                        child: Opacity(
                          opacity: 1 - p,
                          child: ColoredBox(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Padding(
                              padding: EdgeInsets.only(top: y + videoHeight),
                              child: ListView(
                                children: [
                                  if (countdownId == id && unplayed.isNotEmpty)
                                    ListTile(
                                      title: Text(
                                        'Up next in $remaining seconds',
                                      ),
                                      subtitle: Text(
                                        unplayed.first.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: TextButton(
                                        onPressed: () {
                                          countdown?.cancel();
                                          countdown = null;
                                          setState(() {
                                            cancelledAutoplayId = id;
                                            countdownId = null;
                                          });
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.lg,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          metadata?.title ?? '',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        Text(
                                          metadata?.channelName ?? '',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final item in related)
                                    ListTile(
                                      title: Text(
                                        item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        item.channelName,
                                        maxLines: 1,
                                      ),
                                      onTap: () => _open(item.id),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (p > .01 && !ui.isFullscreen)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: miniY,
                      height: 64,
                      child: Opacity(
                        opacity: p,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 114),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _animate(0),
                                    onVerticalDragEnd: (d) {
                                      if ((d.primaryVelocity ?? 0) < -200) {
                                        _animate(0);
                                      } else if ((d.primaryVelocity ?? 0) >
                                          200) {
                                        _dismiss();
                                      }
                                    },
                                    onHorizontalDragEnd: (d) {
                                      if ((d.primaryVelocity ?? 0).abs() >
                                          200) {
                                        _dismiss();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            metadata?.title ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            metadata?.channelName ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      service?.state.status ==
                                          PlayerStatus.playing
                                      ? service?.pause()
                                      : service?.resume(),
                                  icon: Icon(
                                    service?.state.status ==
                                            PlayerStatus.playing
                                        ? LucideIcons.pause
                                        : LucideIcons.play,
                                  ),
                                ),
                                MiniPlayerCloseButton(onDismiss: _dismiss),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: y,
                    width: videoWidth,
                    height: videoHeight,
                    child: service == null
                        ? const Center(child: CircularProgressIndicator())
                        : GestureDetector(
                            onTap: p > .95 ? () => _animate(0) : null,
                            onVerticalDragEnd: p > .95
                                ? (d) {
                                    if ((d.primaryVelocity ?? 0) < -200) {
                                      _animate(0);
                                    } else if ((d.primaryVelocity ?? 0) > 200) {
                                      _dismiss();
                                    }
                                  }
                                : null,
                            onHorizontalDragEnd: p > .95
                                ? (d) {
                                    if ((d.primaryVelocity ?? 0).abs() > 200) {
                                      _dismiss();
                                    }
                                  }
                                : null,
                            child: SharedPlayer(
                              service: service,
                              videoOverride: widget.videoOverride,
                              compact: p > .95 && !dragging,
                              onMinimize: () async {
                                if (ui.isFullscreen) await _exitFullscreen();
                                _animate(1);
                              },
                              onPrevious:
                                  ref
                                          .read(watchSessionProvider)
                                          .previous
                                          .isEmpty &&
                                      ui.position <= const Duration(seconds: 3)
                                  ? null
                                  : () => _previous(service),
                              onNext: nextId == null
                                  ? null
                                  : () => _open(nextId),
                              onPanelDragUpdate: (dy) {
                                dragging = true;
                                animation.stop();
                                animation.value =
                                    (animation.value +
                                            dy / (miniY > 1 ? miniY : 1))
                                        .clamp(0, 1);
                              },
                              onPanelDragEnd: (velocity) {
                                dragging = false;
                                final target = panelReleaseTarget(
                                  animation.value,
                                  velocity,
                                );
                                _animate(
                                  target,
                                  velocity / (miniY > 1 ? miniY : 1),
                                );
                              },
                            ),
                          ),
                  ),
                  if (p > .95 && ui.duration.inMilliseconds > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: miniY,
                      height: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor:
                              (ui.position.inMilliseconds /
                                      ui.duration.inMilliseconds)
                                  .clamp(0.0, 1.0),
                          child: const ColoredBox(color: Color(0xFFFF0000)),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
