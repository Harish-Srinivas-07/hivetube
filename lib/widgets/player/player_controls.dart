import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/playback/playback_service.dart';
import '../../core/playback/player_ui_state.dart';
import '../../core/playback/player_interactions.dart';
import '../../core/settings/app_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../core/yt/watch_info.dart';
import 'player_seek_bar.dart';
import 'player_settings_menu.dart';

class SharedPlayer extends ConsumerStatefulWidget {
  const SharedPlayer({
    super.key,
    required this.service,
    this.short = false,
    this.onMinimize,
    this.onPrevious,
    this.onNext,
    this.onPanelDragUpdate,
    this.onPanelDragEnd,
    this.compact = false,
    this.topInsetAlreadyApplied = false,
    this.videoOverride,
    this.chapters = const [],
    this.onChapters,
  });
  final PlaybackService service;
  final List<WatchChapter> chapters;
  final VoidCallback? onChapters;
  final bool short;
  final bool compact;
  final bool topInsetAlreadyApplied;
  @visibleForTesting
  final Widget? videoOverride;
  final VoidCallback? onMinimize, onPrevious, onNext;
  final ValueChanged<double>? onPanelDragUpdate, onPanelDragEnd;
  @override
  ConsumerState<SharedPlayer> createState() => _SharedPlayerState();
}

class _SharedPlayerState extends ConsumerState<SharedPlayer> {
  Timer? hideTimer, seekTimer, hudTimer, _doubleTapCommitTimer;
  late PlayerSettingsSession _settingsSession;
  int seekTotal = 0;
  Duration? seekTarget;
  bool sheetOpen = false, longPress = false;
  double? oldRate, dragStartValue;
  String? hud;
  IconData? hudIcon;
  double dragX = 0, verticalDelta = 0;
  bool dragCenter = false;
  bool panelDragStarted = false;
  PlayerStatus? lastStatus;

  void _changed() {
    final status = widget.service.state.status;
    if (lastStatus != status) {
      lastStatus = status;
      if (status == PlayerStatus.playing) {
        _scheduleHide();
      } else {
        hideTimer?.cancel();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    _settingsSession = PlayerSettingsSession(widget.service);
    _changed();
  }

  @override
  void didUpdateWidget(covariant SharedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_changed);
      _settingsSession.dispose();
      _settingsSession = PlayerSettingsSession(widget.service);
      widget.service.addListener(_changed);
      lastStatus = null;
      _changed();
    }
  }

  void _scheduleHide() {
    hideTimer?.cancel();
    final ui = ref.read(playerUiProvider);
    if (sheetOpen ||
        ui.scrubbing ||
        !ui.overlayVisible ||
        widget.service.state.status != PlayerStatus.playing) {
      return;
    }
    hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) ref.read(playerUiProvider.notifier).setOverlayVisible(false);
    });
  }

  void _toggleOverlay() {
    final notifier = ref.read(playerUiProvider.notifier);
    notifier.setOverlayVisible(!ref.read(playerUiProvider).overlayVisible);
    _scheduleHide();
  }

  void _seekBy(int seconds) {
    final s = widget.service;
    final step = accumulateSeek(
      position: s.state.position,
      duration: s.state.duration,
      seconds: seconds,
      previousSeconds: seekTotal,
      previousTarget: seekTarget,
    );
    seekTarget = step.target;
    setState(() => seekTotal = step.totalSeconds);

    _doubleTapCommitTimer?.cancel();
    _doubleTapCommitTimer = Timer(const Duration(milliseconds: 400), () {
      if (seekTarget != null) {
        unawaited(s.seekTo(seekTarget!));
      }
    });

    seekTimer?.cancel();
    seekTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          seekTotal = 0;
          seekTarget = null;
        });
      }
    });
    _scheduleHide();
  }

  Future<void> _fullscreen(bool value) async {
    ref.read(playerUiProvider.notifier).setLocked(false);
    ref.read(playerUiProvider.notifier).setFullscreen(value);
    await SystemChrome.setPreferredOrientations(
      value
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [],
    );
    await SystemChrome.setEnabledSystemUIMode(
      value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _startVertical(
    DragStartDetails details,
    double width,
    bool fullscreen,
  ) async {
    dragX = details.localPosition.dx / width;
    verticalDelta = 0;
    panelDragStarted = false;
    dragCenter = dragX >= 1 / 3 && dragX <= 2 / 3;
    if (fullscreen && !dragCenter) {
      try {
        dragStartValue = dragX < 0.5
            ? await ScreenBrightness.instance.application
            : await VolumeController.instance.getVolume();
      } catch (_) {
        dragStartValue = null;
      }
    }
  }

  void _updateVertical(
    DragUpdateDetails details,
    double height,
    bool fullscreen,
  ) {
    verticalDelta += details.delta.dy;
    if (fullscreen && !dragCenter && dragStartValue != null) {
      final value = (dragStartValue! - verticalDelta / height).clamp(0.0, 1.0);
      if (dragX < 0.5) {
        unawaited(
          ScreenBrightness.instance
              .setApplicationScreenBrightness(value)
              .catchError((Object _) {}),
        );
      } else {
        VolumeController.instance.showSystemUI = false;
        unawaited(
          VolumeController.instance.setVolume(value).catchError((Object _) {}),
        );
      }
      setState(() {
        hudIcon = dragX < 0.5 ? LucideIcons.sun : LucideIcons.volume2;
        hud = '${(value * 100).round()}%';
      });
      hudTimer?.cancel();
    } else if (!fullscreen && verticalDelta > 0) {
      panelDragStarted = true;
      widget.onPanelDragUpdate?.call(details.delta.dy);
    }
  }

  void _endVertical(DragEndDetails details, bool fullscreen) {
    if (panelDragStarted) {
      widget.onPanelDragEnd?.call(details.primaryVelocity ?? 0);
      panelDragStarted = false;
    } else if (fullscreen && dragCenter && verticalDelta > 40) {
      unawaited(_fullscreen(false));
    } else if (!fullscreen && verticalDelta < -40) {
      unawaited(_fullscreen(true));
    }
    hudTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => hud = null);
    });
    dragStartValue = null;
  }

  Future<void> _settings() async {
    hideTimer?.cancel();
    sheetOpen = true;
    try {
      await showPlayerSettingsMenu(
        context,
        session: _settingsSession,
        onLock: ref.read(playerUiProvider).isFullscreen
            ? () => ref.read(playerUiProvider.notifier).setLocked(true)
            : null,
      );
    } finally {
      sheetOpen = false;
      if (mounted) _scheduleHide();
    }
  }

  Widget _glassIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = 22,
  }) => ClipOval(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: AppSpacing.sm, sigmaY: AppSpacing.sm),
      child: Material(
        color: AppColors.playerControlGlass,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.playerControlBorder),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: size),
          color: AppColors.shortsForeground,
          disabledColor: AppColors.shortsProgressBuffer,
          visualDensity: VisualDensity.compact,
        ),
      ),
    ),
  );

  String _time(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    seekTimer?.cancel();
    _doubleTapCommitTimer?.cancel();
    hudTimer?.cancel();
    _settingsSession.dispose();
    widget.service.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(playerUiProvider);
    final autoplay = ref.watch(contentPrefsProvider.select((s) => s.autoplay));
    final notifier = ref.read(playerUiProvider.notifier);
    final service = widget.service;
    final state = service.state;
    final busy =
        state.status == PlayerStatus.loading ||
        state.status == PlayerStatus.buffering;
    final displayPosition = ui.scrubbing ? ui.scrubPosition : ui.position;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child:
                widget.videoOverride ??
                Video(
                  controller: service.controller,
                  controls: NoVideoControls,
                  fit: widget.short ? BoxFit.cover : BoxFit.contain,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.shortsForeground,
                      backgroundColor: AppColors.shortsScrim,
                    ),
                    textAlign: TextAlign.center,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                  ),
                ),
          ),
          if (state.frozenFrame != null)
            Image.memory(
              state.frozenFrame!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          if (!widget.compact) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleOverlay,
              onDoubleTapDown: (d) =>
                  dragX = d.localPosition.dx / constraints.maxWidth,
              onDoubleTap: () {
                if (dragX < 1 / 3) _seekBy(-10);
                if (dragX > 2 / 3) _seekBy(10);
              },
              onLongPressStart: (_) {
                oldRate = service.state.rate;
                longPress = true;
                unawaited(service.setRate(2));
                setState(() {});
              },
              onLongPressEnd: (_) {
                if (oldRate != null) unawaited(service.setRate(oldRate!));
                longPress = false;
                setState(() {});
              },
              onLongPressCancel: () {
                if (longPress && oldRate != null) {
                  unawaited(service.setRate(oldRate!));
                }
                longPress = false;
                setState(() {});
              },
              onVerticalDragStart: (d) => unawaited(
                _startVertical(d, constraints.maxWidth, ui.isFullscreen),
              ),
              onVerticalDragUpdate: (d) =>
                  _updateVertical(d, constraints.maxHeight, ui.isFullscreen),
              onVerticalDragEnd: (d) => _endVertical(d, ui.isFullscreen),
            ),
            if (ui.panelProgress == 0 || ui.panelProgress > .3)
              IgnorePointer(
                ignoring: !ui.overlayVisible,
                child: AnimatedOpacity(
                  key: const ValueKey('playerOverlay'),
                  opacity: ui.overlayVisible ? 1 : 0,
                  duration: AppMotion.base,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.playerControlGlass,
                                AppColors.transparent,
                                AppColors.playerControlGlass,
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: !widget.topInsetAlreadyApplied,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: ui.isFullscreen
                                      ? AppSpacing.md
                                      : AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: AppSpacing.sm),
                                    _glassIcon(
                                      icon: LucideIcons.chevronDown,
                                      tooltip: 'Minimize',
                                      onPressed: widget.onMinimize,
                                    ),
                                    const Spacer(),
                                    if (state.captions.isNotEmpty)
                                      IconButton(
                                        onPressed: () => unawaited(
                                          service.setCaption(
                                            state.selectedCaption == null
                                                ? 0
                                                : null,
                                          ),
                                        ),
                                        tooltip: 'Captions',
                                        color: state.selectedCaption == null
                                            ? AppColors.shortsForeground
                                            : AppColors.primary,
                                        icon: const Icon(LucideIcons.captions),
                                      ),
                                    IconButton(
                                      onPressed: () => ref
                                          .read(contentPrefsProvider.notifier)
                                          .setAutoplay(!autoplay),
                                      tooltip: autoplay
                                          ? 'Autoplay on'
                                          : 'Autoplay off',
                                      color: autoplay
                                          ? AppColors.primary
                                          : AppColors.shortsForeground,
                                      icon: const Icon(LucideIcons.circlePlay),
                                    ),
                                    _glassIcon(
                                      icon: LucideIcons.settings,
                                      tooltip: 'Settings',
                                      onPressed: _settings,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _glassIcon(
                                    icon: LucideIcons.skipBack,
                                    tooltip: 'Previous',
                                    onPressed: widget.onPrevious,
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: state.recovering
                                        ? Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                                Text(
                                                  'Retrying...',
                                                  maxLines: 1,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .shortsForeground,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : busy
                                        ? const Padding(
                                            padding: EdgeInsets.all(
                                              AppSpacing.md,
                                            ),
                                            child: CircularProgressIndicator(),
                                          )
                                        : IconButton(
                                            color: AppColors.shortsForeground,
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.playerControlGlass,
                                              shape: const CircleBorder(
                                                side: BorderSide(
                                                  color: AppColors
                                                      .playerControlBorder,
                                                ),
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (state.status ==
                                                  PlayerStatus.ended) {
                                                await service.seek(
                                                  Duration.zero,
                                                );
                                                await service.resume();
                                              } else if (state.status ==
                                                  PlayerStatus.playing) {
                                                await service.pause();
                                              } else {
                                                await service.resume();
                                              }
                                              if (mounted) _scheduleHide();
                                            },
                                            iconSize: AppSizes.avatar,
                                            icon: Icon(
                                              state.status == PlayerStatus.ended
                                                  ? LucideIcons.rotateCcw
                                                  : state.status ==
                                                        PlayerStatus.playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  _glassIcon(
                                    icon: LucideIcons.skipForward,
                                    tooltip: 'Next',
                                    onPressed: widget.onNext,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: ui.isFullscreen ? 28 : 16,
                              child: Row(
                                children: [
                                  const SizedBox(width: AppSpacing.md),
                                  DecoratedBox(
                                    decoration: const BoxDecoration(
                                      color: AppColors.playerControlGlass,
                                      borderRadius: AppRadius.pillBorder,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      child: Text(
                                        '${_time(displayPosition)} / ${_time(ui.duration)}',
                                        style: const TextStyle(
                                          color: AppColors.shortsForeground,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.chapters.isNotEmpty)
                                    Expanded(
                                      child: TextButton(
                                        onPressed: widget.onChapters,
                                        child: Text(
                                          widget.chapters
                                                  .where(
                                                    (c) =>
                                                        c.start <=
                                                        displayPosition,
                                                  )
                                                  .lastOrNull
                                                  ?.title ??
                                              widget.chapters.first.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.shortsForeground,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  _glassIcon(
                                    onPressed: () =>
                                        _fullscreen(!ui.isFullscreen),
                                    tooltip: 'Fullscreen',
                                    icon: ui.isFullscreen
                                        ? LucideIcons.minimize
                                        : LucideIcons.maximize,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!widget.short &&
                (ui.panelProgress == 0 || ui.panelProgress > .3))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PlayerSeekBar(
                  overlayVisible: ui.overlayVisible,
                  position: ui.displayPosition,
                  buffered: ui.buffered,
                  duration: ui.duration,
                  chapters: widget.chapters,
                  seeking: service.state.seekState == SeekState.seeking,
                  buffering: service.state.status == PlayerStatus.buffering,
                  onScrubStart: (p) {
                    hideTimer?.cancel();
                    notifier.setOverlayVisible(true);
                    notifier.setScrubPosition(p);
                    notifier.setScrubbing(true);
                  },
                  onScrubUpdate: notifier.setScrubPosition,
                  onScrubCancel: () {
                    notifier.setScrubbing(false);
                    _scheduleHide();
                  },
                  onScrubEnd: (p) {
                    notifier.setScrubbing(false);
                    unawaited(service.seekTo(p));
                    _scheduleHide();
                  },
                ),
              ),
            if (seekTotal != 0)
              IgnorePointer(
                child: Align(
                  alignment: seekTotal < 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: ClipOval(
                    child: ColoredBox(
                      color: AppColors.playerControlGlass,
                      child: SizedBox(
                        width: constraints.maxWidth / 2,
                        height: constraints.maxHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              seekTotal < 0
                                  ? LucideIcons.rewind
                                  : LucideIcons.fastForward,
                              color: AppColors.shortsForeground,
                            ),
                            Text(
                              '${seekTotal.abs()} seconds',
                              style: const TextStyle(
                                color: AppColors.shortsForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (hud != null)
              Center(
                child: Chip(avatar: Icon(hudIcon), label: Text(hud!)),
              ),
            if (longPress)
              const Align(
                alignment: Alignment.topCenter,
                child: Chip(label: Text('2x >>')),
              ),
            if (ui.locked)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.transparent,
                  child: Center(
                    child: IconButton(
                      tooltip: 'Unlock screen',
                      onPressed: () => notifier.setLocked(false),
                      color: AppColors.shortsForeground,
                      icon: const Icon(LucideIcons.lock),
                    ),
                  ),
                ),
              ),
            if (state.status == PlayerStatus.error)
              Center(
                child: TextButton(
                  onPressed: service.retry,
                  child: const Text('Retry'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
