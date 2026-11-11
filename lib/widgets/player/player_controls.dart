import 'dart:async';

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
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_text_styles.dart';
import 'player_seek_bar.dart';

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
    this.videoOverride,
  });
  final PlaybackService service;
  final bool short;
  final bool compact;
  @visibleForTesting
  final Widget? videoOverride;
  final VoidCallback? onMinimize, onPrevious, onNext;
  final ValueChanged<double>? onPanelDragUpdate, onPanelDragEnd;
  @override
  ConsumerState<SharedPlayer> createState() => _SharedPlayerState();
}

class _SharedPlayerState extends ConsumerState<SharedPlayer> {
  Timer? hideTimer, seekTimer, hudTimer;
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
    _changed();
  }

  @override
  void didUpdateWidget(covariant SharedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_changed);
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
    unawaited(s.seek(seekTarget!));
    seekTimer?.cancel();
    setState(() => seekTotal = step.totalSeconds);
    seekTimer = Timer(const Duration(milliseconds: 700), () {
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
    ref.read(playerUiProvider.notifier).setFullscreen(value);
    await SystemChrome.setPreferredOrientations(
      value
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
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
    final service = widget.service;
    var selectedQuality = service.state.quality;
    var selectedSpeed = service.state.rate;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.dark.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Theme(
        data: AppTheme.dark,
        child: StatefulBuilder(
          builder: (context, update) {
            Future<void> changeCaption(int? index) async {
              await service.setCaption(index);
              if (context.mounted) update(() {});
            }

            Widget choice(String label, bool selected, VoidCallback action) =>
                ListTile(
                  title: Text(
                    label,
                    style: TextStyle(color: AppColors.dark.textPrimary),
                  ),
                  trailing: selected
                      ? const Icon(
                          LucideIcons.check,
                          color: AppColors.shortsForeground,
                        )
                      : null,
                  onTap: () {
                    action();
                    update(() {});
                  },
                );
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ExpansionTile(
                    title: const Text('Quality'),
                    children: [
                      choice('Auto (1080p)', selectedQuality == null, () {
                        selectedQuality = null;
                        service.setQuality(null);
                      }),
                      for (final h in service.state.heights.where(
                        (h) => h <= 1080,
                      ))
                        choice('${h}p', selectedQuality == h, () {
                          selectedQuality = h;
                          service.setQuality(h);
                        }),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('Playback speed'),
                    children: [
                      for (final rate in [
                        0.25,
                        0.5,
                        0.75,
                        1.0,
                        1.25,
                        1.5,
                        1.75,
                        2.0,
                      ])
                        choice('${rate}x', selectedSpeed == rate, () {
                          selectedSpeed = rate;
                          unawaited(service.setRate(rate));
                        }),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('Captions'),
                    subtitle: service.state.captionError
                        ? const Text('Captions unavailable')
                        : null,
                    children: [
                      choice(
                        'Off',
                        service.state.selectedCaption == null,
                        () => unawaited(changeCaption(null)),
                      ),
                      for (var i = 0; i < service.state.captions.length; i++)
                        choice(
                          '${service.state.captions[i]['languageCode'] ?? 'Captions'}',
                          service.state.selectedCaption == i,
                          () => unawaited(changeCaption(i)),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Loop'),
                    value: service.state.loop,
                    onChanged: (v) {
                      unawaited(service.setLoop(v));
                      update(() {});
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    sheetOpen = false;
    if (mounted) _scheduleHide();
  }

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
    hudTimer?.cancel();
    widget.service.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(playerUiProvider);
    final autoplay = ref.watch(appSettingsProvider.select((s) => s.autoplay));
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
            if (ui.panelProgress < .7)
              IgnorePointer(
                ignoring: !ui.overlayVisible,
                child: AnimatedOpacity(
                  key: const ValueKey('playerOverlay'),
                  opacity: ui.overlayVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
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
                                Colors.black.withValues(alpha: .55),
                                AppColors.transparent,
                                Colors.black.withValues(alpha: .55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: widget.onMinimize,
                                    color: AppColors.shortsForeground,
                                    tooltip: 'Minimize',
                                    icon: const Icon(LucideIcons.chevronDown),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: state.captions.isEmpty
                                        ? null
                                        : () => unawaited(
                                            service.setCaption(
                                              state.selectedCaption == null
                                                  ? 0
                                                  : null,
                                            ),
                                          ),
                                    tooltip: 'Captions',
                                    color: state.selectedCaption == null
                                        ? AppColors.shortsForeground
                                        : const Color(0xFFFF0000),
                                    icon: const Icon(LucideIcons.captions),
                                  ),
                                  IconButton(
                                    onPressed: () => ref
                                        .read(appSettingsProvider.notifier)
                                        .setAutoplay(!autoplay),
                                    tooltip: autoplay
                                        ? 'Autoplay on'
                                        : 'Autoplay off',
                                    color: autoplay
                                        ? const Color(0xFFFF0000)
                                        : AppColors.shortsForeground,
                                    icon: const Icon(LucideIcons.circlePlay),
                                  ),
                                  IconButton(
                                    onPressed: _settings,
                                    color: AppColors.shortsForeground,
                                    tooltip: 'Settings',
                                    icon: const Icon(LucideIcons.settings),
                                  ),
                                ],
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: widget.onPrevious,
                                    color: AppColors.shortsForeground,
                                    tooltip: 'Previous',
                                    icon: const Icon(LucideIcons.skipBack),
                                  ),
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
                                            iconSize: 40,
                                            icon: Icon(
                                              state.status == PlayerStatus.ended
                                                  ? LucideIcons.rotateCcw
                                                  : state.status ==
                                                        PlayerStatus.playing
                                                  ? LucideIcons.pause
                                                  : LucideIcons.play,
                                            ),
                                          ),
                                  ),
                                  IconButton(
                                    onPressed: widget.onNext,
                                    color: AppColors.shortsForeground,
                                    tooltip: 'Next',
                                    icon: const Icon(LucideIcons.skipForward),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: ui.isFullscreen ? 32 : 12,
                              child: Row(
                                children: [
                                  const SizedBox(width: AppSpacing.md),
                                  Text(
                                    '${_time(displayPosition)} / ${_time(ui.duration)}',
                                    style: const TextStyle(
                                      color: AppColors.shortsForeground,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () =>
                                        _fullscreen(!ui.isFullscreen),
                                    color: AppColors.shortsForeground,
                                    tooltip: 'Fullscreen',
                                    icon: Icon(
                                      ui.isFullscreen
                                          ? LucideIcons.minimize
                                          : LucideIcons.maximize,
                                    ),
                                  ),
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
            if (!widget.short && ui.panelProgress < .7)
              Positioned(
                left: 0,
                right: 0,
                bottom: ui.isFullscreen ? 70 : -15,
                child: PlayerSeekBar(
                  overlayVisible: ui.overlayVisible,
                  position: ui.position,
                  buffered: ui.buffered,
                  duration: ui.duration,
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
                    unawaited(service.seek(p));
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
                      color: Colors.black.withValues(alpha: .55),
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
