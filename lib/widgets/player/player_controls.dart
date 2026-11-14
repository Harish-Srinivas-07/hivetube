import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/playback/playback_service.dart';
import '../../core/playback/audio_handler.dart';
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
import '../sheets/app_sheet.dart';
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
  final TransformationController _videoTransform = TransformationController();
  String? _zoomVideoId;
  bool _wasFullscreen = false, _videoZoomedState = false;

  bool get _videoZoomed => _videoTransform.value.getMaxScaleOnAxis() > 1.01;

  void _resetVideoZoom() {
    _videoZoomedState = false;
    _videoTransform.value = Matrix4.identity();
  }

  void _onVideoTransformChanged() {
    final zoomed = _videoZoomed;
    if (zoomed == _videoZoomedState) return;
    _videoZoomedState = zoomed;
    if (mounted) setState(() {});
  }

  void _syncVideoZoom(PlayerUiState ui) {
    final videoId = widget.service.state.videoId;
    if (_zoomVideoId != videoId || (_wasFullscreen && !ui.isFullscreen)) {
      _resetVideoZoom();
    }
    _zoomVideoId = videoId;
    _wasFullscreen = ui.isFullscreen;
  }

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
    _videoTransform.addListener(_onVideoTransformChanged);
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
    if (!value) _resetVideoZoom();
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
    } else if (fullscreen && dragCenter && verticalDelta < -40) {
      unawaited(_moreVideos());
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

  Future<void> _moreVideos() async {
    hideTimer?.cancel();
    sheetOpen = true;
    try {
      await showAppSheet<void>(
        context,
        fit: true,
        title: 'More videos',
        onVideo: true,
        builder: (ctx, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetRow(
              icon: LucideIcons.skipForward,
              label: 'Play next',
              subtitle: 'Continue to the next video',
              enabled: widget.onNext != null,
              onTap: widget.onNext == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      widget.onNext?.call();
                    },
            ),
          ],
        ),
      );
    } finally {
      sheetOpen = false;
      if (mounted) _scheduleHide();
    }
  }

  String _time(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }

  Widget _roundControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = AppSizes.iconMd,
    double diameter = AppSizes.buttonIconTouch,
    bool dimmed = false,
  }) => SizedBox(
    width: diameter,
    height: diameter,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.playerControlGlass,
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: size),
      color: dimmed
          ? AppColors.white.withValues(alpha: AppColors.disabledOpacity)
          : AppColors.white,
      disabledColor: AppColors.white.withValues(
        alpha: AppColors.disabledOpacity,
      ),
    ),
  );

  Future<void> _copyVideoLink() async {
    final id = widget.service.state.videoId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: 'https://youtu.be/$id'));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Video link copied')));
  }

  Widget _fullscreenOverlay({
    required BuildContext context,
    required PlayerUiState ui,
    required PlaybackSnapshot state,
    required bool autoplay,
    required PlayerUiController notifier,
  }) {
    final service = widget.service;
    final mediaItem = ref.watch(audioHandlerProvider)?.mediaItem.valueOrNull;
    final title = mediaItem?.title.isNotEmpty == true
        ? mediaItem!.title
        : (state.videoId ?? 'HiveTube');
    final channel = mediaItem?.artist ?? '';
    final compactFullscreen =
        MediaQuery.sizeOf(context).width < AppSpacing.navigationBreakpoint;
    final durationMs = math.max(1, ui.duration.inMilliseconds).toDouble();
    final positionMs = ui.displayPosition.inMilliseconds
        .clamp(0, durationMs.toInt())
        .toDouble();
    final bufferMs = ui.buffered.inMilliseconds
        .clamp(positionMs.toInt(), durationMs.toInt())
        .toDouble();
    return IgnorePointer(
      ignoring: !ui.overlayVisible,
      child: AnimatedOpacity(
        key: const ValueKey('fullscreenPlayerOverlay'),
        opacity: ui.overlayVisible ? 1 : 0,
        duration: AppMotion.base,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(child: ColoredBox(color: AppColors.scrim)),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: AppSpacing.lg,
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.watchTitle.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (channel.isNotEmpty)
                                Text(
                                  channel.startsWith('@')
                                      ? channel
                                      : '@$channel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.meta.copyWith(
                                    color: AppColors.white.withValues(
                                      alpha: AppColors.disabledOpacity,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!compactFullscreen)
                          Material(
                            color: AppColors.playerControlGlass,
                            borderRadius: AppRadius.pillBorder,
                            child: InkWell(
                              borderRadius: AppRadius.pillBorder,
                              onTap: () => ref
                                  .read(contentPrefsProvider.notifier)
                                  .setAutoplay(!autoplay),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: AppSpacing.xs,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: AppSizes.iconLg,
                                      height: AppSizes.iconLg,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.playerControlBorder,
                                      ),
                                      child: Icon(
                                        autoplay
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: AppSizes.iconSm,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.iconGap),
                                    Text(
                                      'Autoplay',
                                      style: AppTextStyles.meta.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (state.captions.isNotEmpty)
                          _roundControl(
                            icon: Icons.closed_caption_rounded,
                            tooltip: 'Captions',
                            onPressed: () => unawaited(
                              service.setCaption(
                                state.selectedCaption == null ? 0 : null,
                              ),
                            ),
                          ),
                        _roundControl(
                          icon: Icons.settings_rounded,
                          tooltip: 'Settings',
                          onPressed: _settings,
                        ),
                        if (state.videoId != null)
                          _roundControl(
                            icon: Icons.ios_share_rounded,
                            tooltip: 'Share',
                            onPressed: () => unawaited(_copyVideoLink()),
                          ),
                      ],
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundControl(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Previous',
                          onPressed: widget.onPrevious,
                          diameter: AppSizes.touchMin + AppSpacing.sm,
                          size: AppSizes.iconLg,
                          dimmed: widget.onPrevious == null,
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        _roundControl(
                          icon: state.playing
                              ? Icons.pause_rounded
                              : state.status == PlayerStatus.ended
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: state.playing ? 'Pause' : 'Play',
                          onPressed: () => unawaited(service.togglePlay()),
                          diameter: AppSizes.touchMin + AppSpacing.xxl,
                          size: AppSizes.iconLg + AppSpacing.md,
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        _roundControl(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Next',
                          onPressed: widget.onNext,
                          diameter: AppSizes.touchMin + AppSpacing.sm,
                          size: AppSizes.iconLg,
                          dimmed: widget.onNext == null,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.none,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: AppSizes.seekTrack,
                            activeTrackColor: AppColors.primary,
                            secondaryActiveTrackColor: AppColors.white
                                .withValues(alpha: 0.7),
                            inactiveTrackColor: AppColors.white.withValues(
                              alpha: AppColors.disabledOpacity,
                            ),
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withValues(
                              alpha: 0.13,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: AppSizes.seekThumb / 2,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: AppSizes.seekThumb,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: durationMs,
                            value: ui.scrubbing
                                ? ui.scrubPosition.inMilliseconds
                                      .clamp(0, durationMs.toInt())
                                      .toDouble()
                                : positionMs,
                            secondaryTrackValue: bufferMs,
                            onChangeStart: (value) {
                              hideTimer?.cancel();
                              notifier.setOverlayVisible(true);
                              notifier.setScrubbing(true);
                              notifier.setScrubPosition(
                                Duration(milliseconds: value.round()),
                              );
                            },
                            onChanged: (value) => notifier.setScrubPosition(
                              Duration(milliseconds: value.round()),
                            ),
                            onChangeEnd: (value) {
                              notifier.setScrubbing(false);
                              unawaited(
                                service.seekTo(
                                  Duration(milliseconds: value.round()),
                                ),
                              );
                              _scheduleHide();
                            },
                          ),
                        ),
                        Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.playerControlGlass,
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                child: Text(
                                  '${_time(Duration(milliseconds: positionMs.round()))} / ${_time(ui.duration)}',
                                  style: AppTextStyles.meta.copyWith(
                                    color: AppColors.white,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (widget.onNext != null) ...[
                              const Spacer(),
                              TextButton(
                                onPressed: _moreVideos,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                ),
                                child: const Text('More videos / Play next'),
                              ),
                            ],
                            const Spacer(),
                            _roundControl(
                              icon: Icons.fullscreen_exit_rounded,
                              tooltip: 'Exit fullscreen',
                              onPressed: () => _fullscreen(false),
                            ),
                          ],
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
    );
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    seekTimer?.cancel();
    _doubleTapCommitTimer?.cancel();
    hudTimer?.cancel();
    _videoTransform.removeListener(_onVideoTransformChanged);
    _videoTransform.dispose();
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
    final compact =
        widget.compact ||
        (!widget.short &&
            !ui.isFullscreen &&
            ui.panelMode == PlayerPanelMode.mini);
    _syncVideoZoom(ui);
    final videoZoomed = _videoZoomed;
    final displayPosition = ui.scrubbing ? ui.scrubPosition : ui.position;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: compact ? null : _toggleOverlay,
              onDoubleTapDown: compact
                  ? null
                  : (d) => dragX = d.localPosition.dx / constraints.maxWidth,
              onDoubleTap: compact
                  ? null
                  : () {
                      if (_videoZoomed) {
                        _resetVideoZoom();
                      } else {
                        if (dragX < 1 / 3) _seekBy(-10);
                        if (dragX > 2 / 3) _seekBy(10);
                      }
                    },
              onLongPressStart: compact
                  ? null
                  : (_) {
                      oldRate = service.state.rate;
                      longPress = true;
                      unawaited(service.setRate(2));
                      setState(() {});
                    },
              onLongPressEnd: compact
                  ? null
                  : (_) {
                      if (oldRate != null) {
                        unawaited(service.setRate(oldRate!));
                      }
                      longPress = false;
                      setState(() {});
                    },
              onLongPressCancel: compact
                  ? null
                  : () {
                      if (longPress && oldRate != null) {
                        unawaited(service.setRate(oldRate!));
                      }
                      longPress = false;
                      setState(() {});
                    },
              onVerticalDragStart: compact || videoZoomed
                  ? null
                  : (d) => unawaited(
                      _startVertical(d, constraints.maxWidth, ui.isFullscreen),
                    ),
              onVerticalDragUpdate: compact || videoZoomed
                  ? null
                  : (d) => _updateVertical(
                      d,
                      constraints.maxHeight,
                      ui.isFullscreen,
                    ),
              onVerticalDragEnd: compact || videoZoomed
                  ? null
                  : (d) => _endVertical(d, ui.isFullscreen),
              child:
                  widget.videoOverride ??
                  InteractiveViewer(
                    transformationController: _videoTransform,
                    minScale: 1,
                    maxScale: 3,
                    panEnabled: !widget.short && !compact,
                    scaleEnabled: !widget.short && !compact,
                    child: Video(
                      controller: service.controller,
                      controls: NoVideoControls,
                      fit: widget.short ? BoxFit.cover : BoxFit.contain,
                      subtitleViewConfiguration: SubtitleViewConfiguration(
                        visible: !ui.isFullscreen,
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
            ),
          ),
          if (state.frozenFrame != null)
            Image.memory(
              state.frozenFrame!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          if (!compact) ...[
            if (ui.isFullscreen)
              _fullscreenOverlay(
                context: context,
                ui: ui,
                state: state,
                autoplay: autoplay,
                notifier: notifier,
              ),
            if (ui.isFullscreen &&
                state.selectedCaption != null &&
                state.subtitleText.trim().isNotEmpty)
              Positioned(
                left: 40,
                right: 40,
                bottom: 150,
                child: IgnorePointer(
                  child: Text(
                    state.subtitleText.trim(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!ui.isFullscreen &&
                (widget.short || ui.panelMode == PlayerPanelMode.expanded))
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
                                    const SizedBox(width: AppSpacing.xs),
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        color: AppColors.shortsForeground,
                                      ),
                                      tooltip: 'Minimize',
                                      onPressed: widget.onMinimize,
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => ref
                                          .read(contentPrefsProvider.notifier)
                                          .setAutoplay(!autoplay),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Tooltip(
                                        message: autoplay
                                            ? 'Autoplay on'
                                            : 'Autoplay off',
                                        child: Container(
                                          width: 36,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: autoplay
                                                  ? AppColors.shortsForeground
                                                  : AppColors.shortsForeground
                                                        .withValues(alpha: 0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          alignment: autoplay
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: autoplay
                                                  ? AppColors.shortsForeground
                                                  : AppColors.shortsForeground
                                                        .withValues(alpha: 0.7),
                                            ),
                                            child: Icon(
                                              autoplay
                                                  ? Icons.play_arrow_rounded
                                                  : Icons.pause_rounded,
                                              size: 9,
                                              color: autoplay
                                                  ? Colors.black
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (state.captions.isNotEmpty) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      InkWell(
                                        onTap: () => unawaited(
                                          service.setCaption(
                                            state.selectedCaption == null
                                                ? 0
                                                : null,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Tooltip(
                                          message: 'Captions',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color:
                                                    state.selectedCaption !=
                                                        null
                                                    ? AppColors.shortsForeground
                                                    : AppColors.shortsForeground
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                width: 1.5,
                                              ),
                                              color:
                                                  state.selectedCaption != null
                                                  ? AppColors.shortsForeground
                                                        .withValues(alpha: 0.25)
                                                  : Colors.transparent,
                                            ),
                                            child: Text(
                                              'CC',
                                              style: TextStyle(
                                                color:
                                                    state.selectedCaption !=
                                                        null
                                                    ? AppColors.shortsForeground
                                                    : AppColors.shortsForeground
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.settings,
                                        color: AppColors.shortsForeground,
                                      ),
                                      tooltip: 'Settings',
                                      onPressed: _settings,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: widget.onPrevious == null
                                        ? 0.35
                                        : 1.0,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          LucideIcons.skipBack,
                                          color: AppColors.shortsForeground,
                                          size: 22,
                                        ),
                                        tooltip: 'Previous',
                                        onPressed: widget.onPrevious,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xl),
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    child: state.recovering
                                        ? const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : IconButton(
                                            key: const ValueKey(
                                              'playerPlayPauseButton',
                                            ),
                                            color: AppColors.shortsForeground,
                                            iconSize: 36,
                                            onPressed: () async {
                                              await service.togglePlay();
                                              if (mounted) _scheduleHide();
                                            },
                                            icon: Icon(
                                              state.status == PlayerStatus.ended
                                                  ? LucideIcons.rotateCcw
                                                  : state.playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: AppSpacing.xl),
                                  Opacity(
                                    opacity: widget.onNext == null ? 0.35 : 1.0,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          LucideIcons.skipForward,
                                          color: AppColors.shortsForeground,
                                          size: 22,
                                        ),
                                        tooltip: 'Next',
                                        onPressed: widget.onNext,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: ui.isFullscreen ? 28 : 16,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_time(displayPosition)} / ${_time(ui.duration > Duration.zero ? ui.duration : service.state.duration)}',
                                        style: const TextStyle(
                                          color: AppColors.shortsForeground,
                                          fontSize: 12,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (widget.chapters.isNotEmpty) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      InkWell(
                                        onTap: widget.onChapters,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 140,
                                                    ),
                                                child: Text(
                                                  widget.chapters
                                                          .where(
                                                            (c) =>
                                                                c.start <=
                                                                displayPosition,
                                                          )
                                                          .lastOrNull
                                                          ?.title ??
                                                      widget
                                                          .chapters
                                                          .first
                                                          .title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .shortsForeground,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              const Icon(
                                                LucideIcons.chevronRight,
                                                size: 14,
                                                color:
                                                    AppColors.shortsForeground,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () =>
                                            _fullscreen(!ui.isFullscreen),
                                        tooltip: 'Fullscreen',
                                        icon: Icon(
                                          ui.isFullscreen
                                              ? Icons.fullscreen_exit_rounded
                                              : Icons.fullscreen_rounded,
                                          color: AppColors.shortsForeground,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!widget.short && !ui.isFullscreen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 20,
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
