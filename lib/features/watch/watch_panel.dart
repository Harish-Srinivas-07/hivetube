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
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
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

final watchPanelProgressProvider = Provider<ValueNotifier<double>>((ref) {
  final progress = ValueNotifier<double>(0);
  ref.onDispose(progress.dispose);
  return progress;
});

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

enum MiniCorner { tl, tr, bl, br }

/// Remembers the mini player's corner for the session.
final miniCornerProvider = NotifierProvider<MiniCornerController, MiniCorner>(
  MiniCornerController.new,
);

class MiniCornerController extends Notifier<MiniCorner> {
  @override
  MiniCorner build() => MiniCorner.br;
  void setCorner(MiniCorner value) => state = value;
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
      strictHome: false,
      source: 'watch_related',
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
    icon: const Icon(LucideIcons.x, color: AppColors.shortsForeground),
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
    with TickerProviderStateMixin {
  /// 0 = mini, 1 = expanded
  late final AnimationController animation;
  late final AnimationController _snapCtrl;
  late final ValueNotifier<double> _progress;
  final ValueNotifier<Offset> _miniPos = ValueNotifier(Offset.zero);
  Offset _snapFrom = Offset.zero;
  Offset _snapTarget = Offset.zero;
  Size? _lastBounds;
  bool _hasInitialMiniPosition = false;
  bool _panelActive = false;
  bool _skipHistory = false;
  bool _keepMini = false;

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
    _progress = ref.read(watchPanelProgressProvider);
    // Start at 1 (expanded) when opened
    animation = AnimationController(vsync: this, value: 1)
      ..addListener(() => _publish(animation.value));
    _snapCtrl = AnimationController(vsync: this)
      ..addListener(() {
        _miniPos.value = Offset.lerp(_snapFrom, _snapTarget, _snapCtrl.value)!;
      });
    _panelActive = ref.read(watchPanelProvider) != null;
    if (_panelActive) _publish(animation.value);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    animation.dispose();
    _snapCtrl.dispose();
    _miniPos.dispose();
    super.dispose();
  }

  void _publish(double p) {
    if (!_panelActive) return;
    _progress.value = p;
    final mode = p <= 0
        ? PlayerPanelMode.mini
        : p >= 1
        ? PlayerPanelMode.expanded
        : PlayerPanelMode.moving;
    ref.read(playerUiProvider.notifier).setPanelMode(mode);
  }

  void _animate(double target, [double velocity = 0]) {
    animation
        .animateWith(
          SpringSimulation(
            const SpringDescription(mass: 1, stiffness: 450, damping: 38),
            animation.value,
            target,
            velocity,
          ),
        )
        .whenComplete(() {
          if (mounted) {
            animation.value = target;
            _publish(target);
          }
        });
  }

  void _openExpanded(String id, {bool record = true}) {
    _skipHistory = !record;
    ref.read(watchPanelProvider.notifier).open(id);
    ref.read(playerUiProvider.notifier).setDismissed(false);
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
    animation.value = 0;
    _progress.value = 0;
    ref.read(playerUiProvider.notifier).setPanelMode(PlayerPanelMode.mini);
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
    if (service == null) {
      debugPrint('[PAUSEDBG] _start id=$id service=null');
      return;
    }
    final isAlreadyLoaded = _started == id && identical(_active, service);
    debugPrint(
      '[PAUSEDBG] _start id=$id loaded=$isAlreadyLoaded '
      'status=${service.state.status}',
    );
    if (isAlreadyLoaded) {
      // This callback is scheduled after every WatchPanel build. Re-entering
      // resume here undoes a user pause when playback state rebuilds the panel.
      return;
    }
    _started = id;
    _active = service;
    if (service.state.videoId == id &&
        service.state.mode == PlaybackMode.video) {
      return;
    }
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
        _panelActive = true;
        _publish(animation.value);
        ref
            .read(watchSessionProvider.notifier)
            .opened(previous, next, record: !_skipHistory);
        _skipHistory = false;
        ref.read(playerUiProvider.notifier).setDismissed(false);
        if (!_keepMini) {
          _animate(1);
        }
        _keepMini = false;
      } else if (next == null && previous != null) {
        _panelActive = false;
        _started = null;
        _active?.stop();
        animation.value = 0;
        _progress.value = 0;
        ref.read(playerUiProvider.notifier).setPanelMode(PlayerPanelMode.mini);
      }
    });

    final id = ref.watch(watchPanelProvider);
    if (id == null) return const SizedBox.shrink();

    final service = ref.watch(playbackProvider);
    final ui = ref.watch(playerUiProvider);
    final miniCorner = ref.watch(miniCornerProvider);
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
        handler?.setMetadata(id, title, channelName);
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
                statusBarColor: AppColors.shortsBackground,
                systemNavigationBarColor: Theme.of(context).colorScheme.surface,
              )
            : Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final padding = MediaQuery.paddingOf(context);
            final wide = bounds.maxWidth >= 900;
            final fullWidth = wide ? bounds.maxWidth * .64 : bounds.maxWidth;
            final fullHeight = ui.isFullscreen
                ? bounds.maxHeight
                : fullWidth / AppSpacing.thumbnailRatio;
            final miniWidth = wide
                ? AppSpacing.videoMaxWidth
                : bounds.maxWidth * .55;
            final miniHeight = miniWidth / AppSpacing.thumbnailRatio;
            final safeTop = padding.top + AppSpacing.md;
            final safeBottom =
                padding.bottom +
                AppSpacing.navHeight +
                AppSpacing.sm +
                AppSpacing.md;
            final left = AppSpacing.md;
            final right = bounds.maxWidth - miniWidth - AppSpacing.md;
            final top = safeTop;
            final bottom = bounds.maxHeight - safeBottom - miniHeight;
            final anchors = <MiniCorner, Offset>{
              MiniCorner.tl: Offset(left, top),
              MiniCorner.tr: Offset(right, top),
              MiniCorner.bl: Offset(left, bottom),
              MiniCorner.br: Offset(right, bottom),
            };
            final miniInset = miniHeight + AppSpacing.sm * 2;
            if (_lastBounds != bounds.biggest) {
              _lastBounds = bounds.biggest;
              final corner = _hasInitialMiniPosition
                  ? miniCorner
                  : MiniCorner.br;
              _miniPos.value = anchors[corner]!;
              _hasInitialMiniPosition = true;
            }

            final expandedTopLeft = Offset(
              0,
              ui.isFullscreen ? 0 : padding.top,
            );
            final sharedPlayer = service == null
                ? const ColoredBox(
                    color: AppColors.shortsBackground,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SharedPlayer(
                    key: _sharedVideoKey,
                    service: service,
                    topInsetAlreadyApplied: true,
                    videoOverride: widget.videoOverride,
                    onMinimize: () => _animate(0),
                    onPrevious: () => _previous(service),
                    onNext: nextId == null ? null : () => _openExpanded(nextId),
                    onPanelDragUpdate: (dy) {
                      animation.stop();
                      animation.value =
                          (animation.value - dy / bounds.maxHeight).clamp(0, 1);
                    },
                    onPanelDragEnd: (velocity) {
                      if (velocity > 400 || animation.value < .5) {
                        _animate(0, -velocity / bounds.maxHeight);
                      } else {
                        _animate(1);
                      }
                    },
                  );
            final videoChild = RepaintBoundary(
              child: SizedBox(
                width: fullWidth,
                height: fullHeight,
                child: sharedPlayer,
              ),
            );
            final watchScreen = RepaintBoundary(
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: WatchScreen(
                  id: id,
                  placeholderVideo: true,
                  embedded: true,
                  deferHeavyContent: true,
                  onMinimize: () => _animate(0),
                ),
              ),
            );

            return MiniPlayerInset(
              bottom: ui.panelMode == PlayerPanelMode.mini ? miniInset : 0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _progress,
                    child: watchScreen,
                    builder: (context, child) {
                      final p = ui.isFullscreen ? 1.0 : _progress.value;
                      if (p <= .02 || ui.isFullscreen) {
                        return const SizedBox.shrink();
                      }
                      final opacity = ((p - .2) / .6).clamp(0.0, 1.0);
                      return Positioned.fill(
                        child: RepaintBoundary(
                          child: IgnorePointer(
                            ignoring: p < .85,
                            child: Opacity(opacity: opacity, child: child),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: Listenable.merge([_progress, _miniPos]),
                    child: videoChild,
                    builder: (context, child) {
                      final p = ui.isFullscreen ? 1.0 : _progress.value;
                      final scale = ui.isFullscreen
                          ? 1.0
                          : lerpDouble(miniWidth / fullWidth, 1, p)!;
                      final pos = Offset.lerp(
                        _miniPos.value,
                        expandedTopLeft,
                        p,
                      )!;
                      final radius = lerpDouble(12, 0, p)!;
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Transform(
                          alignment: Alignment.topLeft,
                          transform: Matrix4.identity()
                            ..translateByDouble(pos.dx, pos.dy, 0, 1)
                            ..scaleByDouble(scale, scale, 1, 1),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                  if (service != null)
                    AnimatedBuilder(
                      animation: Listenable.merge([_progress, _miniPos]),
                      builder: (context, _) {
                        final p = _progress.value;
                        final rect = Rect.fromLTWH(
                          _miniPos.value.dx,
                          _miniPos.value.dy,
                          miniWidth,
                          miniHeight,
                        );
                        return Positioned.fromRect(
                          rect: rect,
                          child: Opacity(
                            opacity: (1 - p * 4).clamp(0.0, 1.0),
                            child: IgnorePointer(
                              ignoring: p > .05,
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    key: const ValueKey(
                                      'miniPlayerDragSurface',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _animate(1),
                                    onPanStart: (_) => _snapCtrl.stop(),
                                    onPanUpdate: (details) {
                                      final next =
                                          _miniPos.value + details.delta;
                                      _miniPos.value = Offset(
                                        next.dx.clamp(left, right),
                                        next.dy.clamp(
                                          padding.top + AppSpacing.md,
                                          bounds.maxHeight -
                                              padding.bottom -
                                              miniHeight -
                                              AppSpacing.md,
                                        ),
                                      );
                                    },
                                    onPanEnd: (details) {
                                      final velocity =
                                          details.velocity.pixelsPerSecond;
                                      if (velocity.dy < -1200 &&
                                          velocity.dy.abs() >
                                              velocity.dx.abs()) {
                                        _animate(
                                          1,
                                          -velocity.dy / bounds.maxHeight,
                                        );
                                      } else {
                                        final targetEntry = anchors.entries
                                            .reduce((a, b) {
                                              final da =
                                                  (_miniPos.value - a.value)
                                                      .distanceSquared;
                                              final db =
                                                  (_miniPos.value - b.value)
                                                      .distanceSquared;
                                              return da <= db ? a : b;
                                            });
                                        ref
                                            .read(miniCornerProvider.notifier)
                                            .setCorner(targetEntry.key);
                                        _snapFrom = _miniPos.value;
                                        _snapTarget = targetEntry.value;
                                        final delta = _snapTarget - _snapFrom;
                                        final distanceSquared =
                                            delta.distanceSquared;
                                        final velocityFraction =
                                            distanceSquared == 0
                                            ? 0.0
                                            : ((velocity.dx * delta.dx +
                                                          velocity.dy *
                                                              delta.dy) /
                                                      distanceSquared)
                                                  .clamp(-8.0, 8.0);
                                        _snapCtrl.value = 0;
                                        _snapCtrl.animateWith(
                                          SpringSimulation(
                                            const SpringDescription(
                                              mass: 1,
                                              stiffness: 450,
                                              damping: 38,
                                            ),
                                            0,
                                            1,
                                            velocityFraction,
                                          ),
                                        );
                                      }
                                    },
                                    child: const SizedBox.expand(),
                                  ),
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: _MiniControlButton(
                                      tooltip: service.state.playing
                                          ? 'Pause'
                                          : 'Play',
                                      icon: service.state.playing
                                          ? LucideIcons.pause
                                          : LucideIcons.play,
                                      onPressed: service.togglePlay,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: _MiniControlButton(
                                      tooltip: 'Close player',
                                      icon: LucideIcons.x,
                                      onPressed: _dismiss,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x99000000),
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 32, height: 32),
        ),
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          iconSize: 16,
          color: Colors.white,
          icon: Icon(icon),
        ),
      ],
    ),
  );
}
