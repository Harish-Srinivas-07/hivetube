// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:math';
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
import '../../theme/app_radius.dart';
import '../../theme/app_colors.dart';
import '../../widgets/player/player_controls.dart';
import '../shorts/shorts_screen.dart';
import '../home/home_variety.dart';
import 'mini_player_inset.dart';
import 'watch_screen.dart';

// ─────────────────────────── providers ───────────────────────────────────────

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
  void minimize() => state--;
}

class WatchPanelController extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String id) => state = id;
  void close() => state = null;
}

/// Helper to open a video and expand the watch panel
void openWatchPanel(WidgetRef ref, String id) {
  ref.read(watchPanelProvider.notifier).open(id);
  ref.read(watchPanelExpandProvider.notifier).expand();
  ref.read(playerUiProvider.notifier).setDismissed(false);
}

/// Remembers the corner of the mini player (false = right, true = left) for the session.
final miniCornerLeftProvider = NotifierProvider<MiniCornerController, bool>(
  MiniCornerController.new,
);

class MiniCornerController extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void setLeft(bool value) => state = value;
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
  Future<List<VideoItem>> build() async {
    final prefs = ref.watch(contentPrefsProvider);
    final items = (await (await ref.watch(
      ytApiProvider.future,
    )).next.related(id)).items;
    return rankHomeItems(
      items,
      preferred: prefs.contentLanguages,
      hidden: prefs.hiddenLanguages,
      seen: const {},
      random: Random(id.hashCode ^ prefs.prefsVersion),
    );
  }
}

// ─────────────────────────── public widgets ──────────────────────────────────

class MiniPlayerCloseButton extends StatelessWidget {
  const MiniPlayerCloseButton({super.key, required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Close player',
    onPressed: onDismiss,
    icon: const Icon(LucideIcons.x, color: Colors.white),
  );
}

// ─────────────────────────── main panel ──────────────────────────────────────

class WatchPanel extends ConsumerStatefulWidget {
  const WatchPanel({super.key, this.videoOverride});
  @visibleForTesting
  final Widget? videoOverride;
  @override
  ConsumerState<WatchPanel> createState() => _WatchPanelState();
}

class _WatchPanelState extends ConsumerState<WatchPanel>
    with SingleTickerProviderStateMixin {
  /// 0 = mini, 1 = expanded
  late final AnimationController animation;
  bool _skipHistory = false;
  bool _keepMini = false;
  bool _dragging = false;

  // Mini controls visibility & timer
  bool _miniControls = false;
  Timer? _miniTimer;

  // Vertical & horizontal slide/drag offset for mini card
  double _miniDismissY = 0;
  double _miniDismissOpacity = 1;
  double _miniDragX = 0;

  String? _started;
  PlaybackService? _active;
  Timer? _countdown;
  String? _countdownId;
  String? _cancelledAutoplayId;
  int _remaining = 5;

  final GlobalKey _sharedVideoKey = GlobalKey(debugLabel: 'shared-watch-video');

  @override
  void initState() {
    super.initState();
    // Start at 1 (expanded) when opened
    animation = AnimationController(vsync: this, value: 1)
      ..addListener(() {
        ref.read(playerUiProvider.notifier).setPanelProgress(animation.value);
      });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _miniTimer?.cancel();
    animation.dispose();
    super.dispose();
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

  void _openExpanded(String id, {bool record = true}) {
    _skipHistory = !record;
    ref.read(watchPanelProvider.notifier).open(id);
    ref.read(playerUiProvider.notifier).setDismissed(false);
    setState(() {
      _miniDismissY = 0;
      _miniDismissOpacity = 1;
    });
    _animate(1);
  }

  void _openMini(String id, {bool record = true}) {
    _keepMini = true;
    _skipHistory = !record;
    ref.read(watchPanelProvider.notifier).open(id);
    ref.read(playerUiProvider.notifier).setDismissed(false);
  }

  void _dismiss({bool stop = true}) {
    final ui = ref.read(playerUiProvider);
    if (ui.isFullscreen) unawaited(_exitFullscreen());
    ref.read(watchPanelProvider.notifier).close();
    ref.read(playerUiProvider.notifier).setDismissed(true);
    ref.read(playerUiProvider.notifier).setFullscreen(false);
    _started = null;
    if (stop) unawaited(_active?.stop());
    _miniTimer?.cancel();
    setState(() {
      _miniControls = false;
      _miniDismissY = 0;
      _miniDismissOpacity = 1;
    });
  }

  Future<void> _exitFullscreen() async {
    ref.read(playerUiProvider.notifier).setFullscreen(false);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []);
  }

  Future<void> _start(String id, PlaybackService? service) async {
    if (service == null) return;
    final isAlreadyLoaded = _started == id && identical(_active, service);
    if (isAlreadyLoaded) {
      if (service.state.status == PlayerStatus.paused) {
        await service.resume();
      } else if (service.state.status == PlayerStatus.ended) {
        await service.seek(Duration.zero);
        await service.resume();
      }
      return;
    }
    _started = id;
    _active = service;
    if (!ref.read(watchSessionProvider).watched.contains(id)) {
      ref.read(watchSessionProvider.notifier).opened(null, id, record: false);
    }
    ref.read(playerUiProvider.notifier).setDismissed(false);
    final history = await ref.read(historyRepoProvider).recent();
    if (!mounted || ref.read(watchPanelProvider) != id || _started != id) {
      return;
    }
    final saved = history.where((entry) => entry.videoId == id).firstOrNull;
    final start = resumePosition(saved);
    await service.setLoop(false);
    if (!mounted || ref.read(watchPanelProvider) != id || _started != id) {
      return;
    }
    await service.play(
      PlayRequest(videoId: id, mode: PlaybackMode.video, startAt: start),
    );
  }

  void _previous(PlaybackService? service) {
    if (service == null) return;
    if (service.state.position > const Duration(seconds: 3)) {
      unawaited(service.seek(Duration.zero));
      return;
    }
    final previous = ref.read(watchSessionProvider.notifier).popPrevious();
    if (previous != null) _openMini(previous, record: false);
  }

  void _showMiniControls(PlaybackService? service) {
    _miniTimer?.cancel();
    setState(() => _miniControls = true);
    if (service?.state.status == PlayerStatus.playing) {
      _miniTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _active?.state.status == PlayerStatus.playing) {
          setState(() => _miniControls = false);
        }
      });
    }
  }

  void _syncAutoplay(
    String id,
    PlaybackService? service,
    List<VideoItem> related,
    bool enabled,
  ) {
    if (service?.state.status != PlayerStatus.ended &&
        _cancelledAutoplayId == id) {
      _cancelledAutoplayId = null;
    }
    if (!enabled ||
        service?.state.status != PlayerStatus.ended ||
        related.isEmpty ||
        _cancelledAutoplayId == id) {
      if (_countdown != null) {
        _countdown?.cancel();
        _countdown = null;
        _countdownId = null;
      }
      return;
    }
    if (_countdownId == id) return;
    _countdown?.cancel();
    _countdownId = id;
    _remaining = 5;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          ref.read(watchPanelProvider) != id ||
          !ref.read(contentPrefsProvider).autoplay) {
        timer.cancel();
        _countdown = null;
        _countdownId = null;
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        _countdown = null;
        _countdownId = null;
        _openExpanded(related.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for external expand/minimize requests
    ref.listen<int>(watchPanelExpandProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        _animate(1);
      } else if (next < (prev ?? 0)) {
        _animate(0);
      }
    });

    // React to panel id changes
    ref.listen<String?>(watchPanelProvider, (previous, next) {
      if (next != null && next != previous) {
        ref
            .read(watchSessionProvider.notifier)
            .opened(previous, next, record: !_skipHistory);
        _skipHistory = false;
        ref.read(playerUiProvider.notifier).setDismissed(false);
        setState(() {
          _miniDismissY = 0;
          _miniDismissOpacity = 1;
        });
        if (!_keepMini) {
          _animate(1);
        }
        _keepMini = false;
      } else if (next == null && previous != null) {
        _started = null;
        _active?.stop();
        _miniTimer?.cancel();
        setState(() {
          _miniControls = false;
          _miniDismissY = 0;
          _miniDismissOpacity = 1;
        });
      }
    });

    final id = ref.watch(watchPanelProvider);
    if (id == null) return const SizedBox.shrink();

    final service = ref.watch(playbackProvider);
    final ui = ref.watch(playerUiProvider);
    final miniLeft = ref.watch(miniCornerLeftProvider);
    final metadataState = ref.watch(shortMetadataProvider(id));
    final metadata = metadataState.value;
    final title = metadata?.title?.trim().isNotEmpty == true
        ? metadata!.title!.trim()
        : metadataState.isLoading
        ? 'Loading…'
        : 'Video details unavailable';
    final channelName = metadata?.channelName?.trim() ?? '';
    final related =
        ref.watch(relatedVideosProvider(id)).value ?? const <VideoItem>[];
    ref.watch(watchSessionProvider);
    final nextId = ref
        .read(watchSessionProvider.notifier)
        .firstUnplayed(related.map((v) => v.id));
    final unplayed = related.where((v) => v.id == nextId).toList();
    final autoplay = ref.watch(contentPrefsProvider.select((s) => s.autoplay));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(watchPanelProvider) == id) {
        unawaited(_start(id, service));
        _syncAutoplay(id, service, unplayed, autoplay);
        final handler = ref.read(audioHandlerProvider);
        handler?.setMetadata(
          id,
          title,
          channelName,
        );
        handler?.onNext = () async {
          if (mounted && nextId != null) _openExpanded(nextId);
        };
        handler?.onPrevious = () async {
          if (mounted) _previous(service);
        };
      }
    });

    return PopScope(
      canPop: !ui.locked && !ui.isFullscreen && animation.value <= 0.01,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ui.locked) {
          ref.read(playerUiProvider.notifier).setOverlayVisible(true);
          return;
        }
        if (ui.isFullscreen) {
          unawaited(_exitFullscreen());
        } else if (animation.value > 0.01) {
          _animate(0); // Minimise
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: animation.value > 0.5
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.black,
                systemNavigationBarColor: Theme.of(context).colorScheme.surface,
              )
            : Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final sysPadding = MediaQuery.paddingOf(context);
            final navBottom =
                sysPadding.bottom + AppSpacing.navHeight + AppSpacing.sm;
            final wide = bounds.maxWidth >= 900;

            // Mini player dimensions: 55% of width on phone (16:9), capped at 360dp on wide
            final miniWidth = wide
                ? AppSpacing.videoMaxWidth
                : bounds.maxWidth * .55;
            final miniHeight = miniWidth / AppSpacing.thumbnailRatio;
            final miniY = bounds.maxHeight - navBottom - miniHeight;
            final miniRight = wide ? AppSpacing.lg : AppSpacing.lg;

            // Inset exposed to tabs
            final miniInset = miniHeight + AppSpacing.sm * 2;

            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final p = ui.isFullscreen ? 1.0 : animation.value;
                final isMini = p < 0.05;

                // Video geometry morph
                final expandedWidth = wide ? bounds.maxWidth * 0.64 : bounds.maxWidth;
                final expandedHeight = ui.isFullscreen
                    ? bounds.maxHeight
                    : expandedWidth / AppSpacing.thumbnailRatio;

                final videoWidth = lerpDouble(miniWidth, expandedWidth, p)!;
                final videoHeight = lerpDouble(miniHeight, expandedHeight, p)!;

                final videoTop = ui.isFullscreen
                    ? 0.0
                    : lerpDouble(miniY, sysPadding.top, p)! + _miniDismissY;

                // Horizontal position
                final miniLeftPos = miniLeft ? miniRight : bounds.maxWidth - miniWidth - miniRight;
                final videoLeft = lerpDouble(miniLeftPos, 0, p)!;

                // Panel content fades in as animation passes 0.5
                final contentOpacity = ((p - 0.5) / 0.5).clamp(0.0, 1.0);

                return MiniPlayerInset(
                  bottom: isMini ? miniInset : 0.0,
                  child: Stack(
                    children: [
                      // ── Expanded Content (fades in past 0.5) ─────────────
                      if (p > 0.05 && !ui.isFullscreen)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: contentOpacity < 0.5,
                            child: Opacity(
                              opacity: contentOpacity,
                              child: Material(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                child: WatchScreen(
                                  id: id,
                                  placeholderVideo: true,
                                  embedded: true,
                                  onMinimize: () => _animate(0),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ── Morphed Shared Video Widget ───────────────────────
                      Positioned(
                        left: videoLeft,
                        top: videoTop,
                        width: videoWidth,
                        height: videoHeight,
                        child: Opacity(
                          opacity: _miniDismissOpacity,
                          child: _VideoMorphCard(
                            panelKey: _sharedVideoKey,
                            isMini: isMini,
                            miniControls: _miniControls,
                            service: service,
                            videoOverride: widget.videoOverride,
                            title: title,
                            nextId: nextId,
                            dragging: _dragging,
                            onMinimize: () => _animate(0),
                            onExpand: () => _animate(1),
                            onDismiss: _dismiss,
                            onPrevious: () => _previous(service),
                            onNext: nextId == null ? null : () => _openMini(nextId),
                            onTapMini: () => _showMiniControls(service),
                            onMiniVerticalDragUpdate: (dy) {
                              _dragging = true;
                              if (dy > 0) {
                                // Drag down on mini: slide down and fade
                                setState(() {
                                  _miniDismissY = (_miniDismissY + dy).clamp(0.0, 200.0);
                                  _miniDismissOpacity = (1.0 - _miniDismissY / 150.0).clamp(0.0, 1.0);
                                });
                              } else {
                                // Drag up on mini: expand
                                animation.stop();
                                final delta = -dy / (miniY > 1 ? miniY : 1);
                                animation.value = (animation.value + delta).clamp(0.0, 1.0);
                              }
                            },
                            onMiniVerticalDragEnd: (vel) {
                              _dragging = false;
                              if (_miniDismissY > 48 || vel > 400) {
                                // Swipe down: slides down, fades, stops & closes
                                _dismiss();
                              } else {
                                setState(() {
                                  _miniDismissY = 0;
                                  _miniDismissOpacity = 1;
                                });
                                if (vel < -400 || animation.value > 0.5) {
                                  _animate(1, -vel / (miniY > 1 ? miniY : 1));
                                } else {
                                  _animate(0);
                                }
                              }
                            },
                            onMiniHorizontalDragUpdate: (dx) {
                              _miniDragX += dx;
                            },
                            onMiniHorizontalDragEnd: (vel) {
                              if (_miniDragX < -48 || vel < -150) {
                                ref.read(miniCornerLeftProvider.notifier).setLeft(true);
                              } else if (_miniDragX > 48 || vel > 150) {
                                ref.read(miniCornerLeftProvider.notifier).setLeft(false);
                              }
                              _miniDragX = 0;
                            },
                            onExpandedDragUpdate: (dy) {
                              _dragging = true;
                              animation.stop();
                              final delta = -dy / (miniY > 1 ? miniY : 1);
                              animation.value = (animation.value + delta).clamp(0.0, 1.0);
                            },
                            onExpandedDragEnd: (vel) {
                              _dragging = false;
                              if (vel > 400 || animation.value < 0.5) {
                                _animate(0, -vel / (miniY > 1 ? miniY : 1));
                              } else {
                                _animate(1);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── mini progress bar ───────────────────────────────

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({
    required this.service,
    required this.position,
    required this.buffered,
    required this.duration,
  });
  final PlaybackService service;
  final Duration position, buffered, duration;

  @override
  Widget build(BuildContext context) {
    if (duration <= Duration.zero) return const SizedBox.shrink();
    final played =
        (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final buf =
        (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final frac = (details.localPosition.dx / constraints.maxWidth)
              .clamp(0.0, 1.0);
          final target =
              Duration(milliseconds: (frac * duration.inMilliseconds).round());
          unawaited(service.seekTo(target));
        },
        onHorizontalDragUpdate: (details) {
          final frac = (details.localPosition.dx / constraints.maxWidth)
              .clamp(0.0, 1.0);
          final target =
              Duration(milliseconds: (frac * duration.inMilliseconds).round());
          unawaited(service.seekTo(target));
        },
        child: SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FractionallySizedBox(
                      widthFactor: buf,
                      alignment: Alignment.centerLeft,
                      child: const ColoredBox(color: Color(0x66FFFFFF)),
                    ),
                    FractionallySizedBox(
                      widthFactor: played,
                      alignment: Alignment.centerLeft,
                      child: const ColoredBox(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── video morph card ────────────────────────────────

class _VideoMorphCard extends StatelessWidget {
  const _VideoMorphCard({
    required this.panelKey,
    required this.isMini,
    required this.miniControls,
    required this.service,
    required this.videoOverride,
    required this.title,
    required this.nextId,
    required this.dragging,
    required this.onMinimize,
    required this.onExpand,
    required this.onDismiss,
    required this.onPrevious,
    required this.onNext,
    required this.onTapMini,
    required this.onMiniVerticalDragUpdate,
    required this.onMiniVerticalDragEnd,
    required this.onMiniHorizontalDragUpdate,
    required this.onMiniHorizontalDragEnd,
    required this.onExpandedDragUpdate,
    required this.onExpandedDragEnd,
  });

  final Key panelKey;
  final bool isMini, miniControls, dragging;
  final PlaybackService? service;
  final Widget? videoOverride;
  final String title;
  final String? nextId;
  final VoidCallback onMinimize, onExpand, onDismiss, onPrevious, onTapMini;
  final VoidCallback? onNext;
  final ValueChanged<double> onMiniVerticalDragUpdate, onMiniVerticalDragEnd;
  final ValueChanged<double> onMiniHorizontalDragUpdate, onMiniHorizontalDragEnd;
  final ValueChanged<double> onExpandedDragUpdate, onExpandedDragEnd;

  @override
  Widget build(BuildContext context) {
    final svc = service;

    Widget card = ClipRRect(
      borderRadius: isMini ? AppRadius.lgBorder : BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Single keyed video widget reused at every size
          GestureDetector(
            key: panelKey,
            behavior: HitTestBehavior.opaque,
            onTap: isMini ? onTapMini : null,
            child: svc == null
                ? const ColoredBox(
                    color: AppColors.shortsBackground,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SharedPlayer(
                    service: svc,
                    topInsetAlreadyApplied: true,
                    videoOverride: videoOverride,
                    compact: isMini && !dragging,
                    onMinimize: onMinimize,
                    onPrevious: onPrevious,
                    onNext: onNext,
                    onPanelDragUpdate: isMini ? null : onExpandedDragUpdate,
                    onPanelDragEnd: isMini ? null : onExpandedDragEnd,
                  ),
          ),

          // Mini controls overlay
          if (isMini && miniControls && svc != null)
            _MiniControlsOverlay(
              service: svc,
              nextId: nextId,
              onExpand: onExpand,
              onDismiss: onDismiss,
              onPrevious: onPrevious,
              onNext: onNext,
            ),

          // Red progress line along the bottom edge inside the rounded card
          if (isMini && (svc?.state.duration.inMilliseconds ?? 0) > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 12,
              child: _MiniProgressBar(
                service: svc!,
                position: svc.state.position,
                buffered: svc.state.buffered,
                duration: svc.state.duration,
              ),
            ),
        ],
      ),
    );

    // Mini card soft shadow
    if (isMini) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgBorder,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: card,
      );
    }

    // Wrap with gesture recognizer for mini player swipe/drag
    if (isMini) {
      card = Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) => onMiniVerticalDragUpdate(d.delta.dy),
          onVerticalDragEnd: (d) => onMiniVerticalDragEnd(d.primaryVelocity ?? 0),
          onHorizontalDragUpdate: (d) => onMiniHorizontalDragUpdate(d.delta.dx),
          onHorizontalDragEnd: (d) => onMiniHorizontalDragEnd(d.primaryVelocity ?? 0),
          child: card,
        ),
      );
    }

    return card;
  }
}

// ─────────────────────────── mini controls overlay ───────────────────────────

class _MiniControlsOverlay extends StatelessWidget {
  const _MiniControlsOverlay({
    required this.service,
    required this.nextId,
    required this.onExpand,
    required this.onDismiss,
    required this.onPrevious,
    required this.onNext,
  });

  final PlaybackService service;
  final String? nextId;
  final VoidCallback onExpand, onDismiss, onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final playing = service.state.status == PlayerStatus.playing;
    final buffering =
        service.state.status == PlayerStatus.loading ||
        service.state.status == PlayerStatus.buffering;
    final ended = service.state.status == PlayerStatus.ended;
    final error = service.state.status == PlayerStatus.error;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onExpand, // Tap on visible controls background opens the watch page
      child: ColoredBox(
        color: Colors.black54,
        child: Stack(
          children: [
            // Top-left: expand
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Expand',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(AppSpacing.xs),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                onPressed: onExpand,
                icon: const Icon(LucideIcons.maximize, color: Colors.white),
              ),
            ),
            // Top-right: close
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close player',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(AppSpacing.xs),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                onPressed: onDismiss,
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
            // Centre controls
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    iconSize: 20,
                    onPressed: onPrevious,
                    icon: const Icon(LucideIcons.skipBack, color: Colors.white),
                  ),
                  if (buffering)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (error)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      iconSize: 22,
                      onPressed: service.retry,
                      icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
                      tooltip: 'Retry',
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      iconSize: 26,
                      onPressed: () async {
                        if (ended) {
                          await service.seek(Duration.zero);
                          await service.resume();
                        } else if (playing) {
                          await service.pause();
                        } else {
                          await service.resume();
                        }
                      },
                      icon: Icon(
                        ended
                            ? LucideIcons.rotateCcw
                            : playing
                            ? LucideIcons.pause
                            : LucideIcons.play,
                        color: Colors.white,
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    iconSize: 20,
                    onPressed: nextId != null ? onNext : null,
                    icon: const Icon(LucideIcons.skipForward, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
