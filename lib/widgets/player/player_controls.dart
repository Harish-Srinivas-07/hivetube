import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/orientation/orientation_policy.dart';
import '../../core/playback/playback_service.dart';
import '../../core/playback/audio_handler.dart';
import '../../core/playback/picture_in_picture.dart';
import '../../core/playback/player_ui_state.dart';
import '../../core/playback/player_interactions.dart';
import '../../core/settings/app_settings.dart';
import '../../core/streams/stream_selector.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../core/yt/watch_info.dart';
import '../logger.dart';
import 'player_seek_bar.dart';
import 'player_settings_menu.dart';
import '../ui/app_controls.dart';

double? videoAspectRatioFromController(
  PlaybackService? service, {
  String? videoId,
}) {
  if (service == null) return null;
  try {
    if (videoId != null && service.state.frameReadyId != videoId) return null;
    final videoSize = service.controller.player.state;
    final width = videoSize.width;
    final height = videoSize.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  } catch (_) {
    return null;
  }
}

Future<void> setPlayerFullscreenOrientation(
  bool fullscreen, {
  double? aspectRatio,
}) {
  if (fullscreen) {
    return setVideoFullscreenOrientation(
      true,
      landscapeVideo: aspectRatio != null && aspectRatio >= 1,
    ).then(
      (_) => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }
  return _restoreOrientationAfterFullscreen();
}

Future<void> _restoreOrientationAfterFullscreen() async {
  await lockPortraitForFullscreenExit();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await reapplyCurrentOrientationPolicy();
}

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
    this.requestVideoId,
    this.thumbnailUrl,
    this.chapters = const [],
    this.onChapters,
    this.autoplayCountdown,
    this.onReplayFromStart,
  });
  final PlaybackService service;
  final List<WatchChapter> chapters;
  final VoidCallback? onChapters;
  final bool short;
  final bool compact;
  final bool topInsetAlreadyApplied;
  @visibleForTesting
  final Widget? videoOverride;
  final String? requestVideoId;
  final String? thumbnailUrl;
  final int? autoplayCountdown;
  final VoidCallback? onMinimize, onPrevious, onNext;
  final VoidCallback? onReplayFromStart;
  final ValueChanged<double>? onPanelDragUpdate, onPanelDragEnd;
  @override
  ConsumerState<SharedPlayer> createState() => _SharedPlayerState();
}

class _SharedPlayerState extends ConsumerState<SharedPlayer> {
  Timer? hideTimer, hudTimer;
  late final MultiTapSeekSession _multiTapSeek;
  late PlayerSettingsSession _settingsSession;
  int seekTotal = 0;
  String? _seekVideoId;
  bool sheetOpen = false, longPress = false;
  double? oldRate, dragStartValue;
  String? hud;
  IconData? hudIcon;
  double dragX = 0, verticalDelta = 0;
  bool dragCenter = false;
  bool panelDragStarted = false;
  PlayerStatus? lastStatus;
  bool _wasSeeking = false;
  final TransformationController _videoTransform = TransformationController();
  final GlobalKey _videoBoxKey = GlobalKey(debugLabel: 'shared-player-video-box');
  String? _zoomVideoId;
  bool _wasFullscreen = false, _videoZoomedState = false;
  bool? _fullscreenLandscapeVideo;
  String? _lastLoggedVideoSize;

  void _reportVideoRect() {
    if (!Platform.isAndroid || !mounted) return;
    final inPip = ref.read(pictureInPictureProvider);
    if (inPip) return;
    final renderBox = _videoBoxKey.currentContext?.findRenderObject();
    if (renderBox is RenderBox && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final rect = Rect.fromLTWH(
        position.dx * pixelRatio,
        position.dy * pixelRatio,
        size.width * pixelRatio,
        size.height * pixelRatio,
      );
      ref.read(pictureInPictureProvider.notifier).updateSourceRect(rect);
    }
  }

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

  void _logVideoRatio(PlaybackService service, bool fullscreen) {
    final videoId = service.state.videoId;
    if (videoId == null) {
      _lastLoggedVideoSize = null;
      return;
    }
    final videoSize = service.controller.player.state;
    final width = videoSize.width;
    final height = videoSize.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      _lastLoggedVideoSize = null;
      return;
    }
    final sizeKey = '$videoId:$width:$height';
    if (_lastLoggedVideoSize == sizeKey) return;
    _lastLoggedVideoSize = sizeKey;
    final ratio = width / height;
    Logger.log(
      'Player',
      'VideoRatio id=$videoId size=${width}x$height '
          'ratio=${ratio.toStringAsFixed(2)} '
          'mode=${ratio < 1 ? 'portrait' : 'landscape'} fullscreen=$fullscreen',
    );
  }

  void _changed() {
    final status = widget.service.state.status;
    final seeking = widget.service.state.seekState == SeekState.seeking;
    if (seeking) hideTimer?.cancel();
    if (_wasSeeking && !seeking && status == PlayerStatus.playing) {
      _scheduleHide();
    }
    _wasSeeking = seeking;
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
    _multiTapSeek = MultiTapSeekSession(
      gap: AppMotion.multiTapSeek,
      onSingleTap: () {
        if (mounted && !ref.read(playerUiProvider).locked) _toggleOverlay();
      },
      onFeedback: (step) {
        if (!mounted) return;
        if (step != null && _videoZoomed) {
          _multiTapSeek.cancel();
          _resetVideoZoom();
          return;
        }
        setState(() => seekTotal = step?.totalSeconds ?? 0);
      },
      onSeek: (target) {
        if (mounted &&
            !ref.read(playerUiProvider).locked &&
            _seekVideoId ==
                (widget.requestVideoId ?? widget.service.state.videoId)) {
          unawaited(widget.service.seekTo(target));
          _scheduleHide();
        }
      },
    );
    _videoTransform.addListener(_onVideoTransformChanged);
    widget.service.addListener(_changed);
    _settingsSession = PlayerSettingsSession(widget.service);
    _changed();
  }

  @override
  void didUpdateWidget(covariant SharedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _multiTapSeek.cancel();
      oldWidget.service.removeListener(_changed);
      _settingsSession.dispose();
      _settingsSession = PlayerSettingsSession(widget.service);
      widget.service.addListener(_changed);
      lastStatus = null;
      _lastLoggedVideoSize = null;
      _changed();
    }
    if (oldWidget.requestVideoId != widget.requestVideoId) {
      _multiTapSeek.cancel();
    }
  }

  void _scheduleHide() {
    hideTimer?.cancel();
    final ui = ref.read(playerUiProvider);
    if (sheetOpen ||
        ui.scrubbing ||
        !ui.overlayVisible ||
        widget.service.state.status != PlayerStatus.playing ||
        widget.service.state.seekState == SeekState.seeking ||
        widget.service.state.recovering) {
      return;
    }
    hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) ref.read(playerUiProvider.notifier).setOverlayVisible(false);
    });
  }

  Widget _replayAction() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppButton.tonal(
        label: 'Replay from start',
        icon: LucideIcons.rotateCcw,
        onPressed: () async {
          widget.onReplayFromStart?.call();
          await widget.service.togglePlay();
          if (mounted) _scheduleHide();
        },
      ),
      if (widget.autoplayCountdown case final seconds? when seconds > 0)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Up next in $seconds',
            style: AppTextStyles.meta.copyWith(color: AppColors.white),
          ),
        ),
    ],
  );

  void _toggleOverlay() {
    final notifier = ref.read(playerUiProvider.notifier);
    notifier.setOverlayVisible(!ref.read(playerUiProvider).overlayVisible);
    _scheduleHide();
  }

  Future<void> _fullscreen(bool value) async {
    if (!value) _resetVideoZoom();
    final aspectRatio = videoAspectRatioFromController(widget.service);
    _fullscreenLandscapeVideo = value && aspectRatio != null
        ? aspectRatio >= 1
        : null;
    ref.read(playerUiProvider.notifier).setLocked(false);
    ref.read(playerUiProvider.notifier).setFullscreen(value);
    await setPlayerFullscreenOrientation(value, aspectRatio: aspectRatio);
  }

  void _syncFullscreenVideoOrientation(PlayerUiState ui) {
    if (!ui.isFullscreen) return;
    final aspectRatio = videoAspectRatioFromController(widget.service);
    if (aspectRatio == null) return;
    final landscapeVideo = aspectRatio >= 1;
    if (_fullscreenLandscapeVideo == landscapeVideo) return;
    _fullscreenLandscapeVideo = landscapeVideo;
    unawaited(setPlayerFullscreenOrientation(true, aspectRatio: aspectRatio));
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
    bool showBackground = true,
  }) => SizedBox(
    width: diameter,
    height: diameter,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: showBackground
            ? AppColors.playerControlGlass
            : AppColors.transparent,
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

  Widget _fullscreenAutoplayControl(bool autoplay) => SizedBox(
    width: AppSizes.fullscreenAutoplayWidth,
    height: AppSizes.touchMin,
    child: Center(
      child: Material(
        color: AppColors.playerControlGlass,
        borderRadius: AppRadius.pillBorder,
        child: InkWell(
          borderRadius: AppRadius.pillBorder,
          onTap: () =>
              ref.read(contentPrefsProvider.notifier).setAutoplay(!autoplay),
          child: SizedBox(
            width: AppSizes.fullscreenAutoplayWidth,
            height: AppSizes.buttonLarge,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: AppMotion.base,
                    curve: AppMotion.standard,
                    alignment: autoplay
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      key: const ValueKey('fullscreenAutoplayThumb'),
                      width: AppSizes.iconLg,
                      height: AppSizes.iconLg,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.playerControlBorder,
                      ),
                      child: Icon(
                        autoplay
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: AppSizes.iconSm,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: AppMotion.base,
                    curve: AppMotion.standard,
                    alignment: autoplay
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        autoplay ? 'Autoplay' : 'Paused',
                        style: AppTextStyles.meta.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _captionControl(PlaybackSnapshot state) => SizedBox.square(
    dimension: AppSizes.touchMin,
    child: InkWell(
      onTap: () => unawaited(
        widget.service.setCaption(state.selectedCaption == null ? 0 : null),
      ),
      borderRadius: AppRadius.xsBorder,
      child: Center(
        child: Tooltip(
          message: 'Captions',
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.xsBorder,
              border: Border.all(
                color: AppColors.shortsForeground.withValues(
                  alpha: state.selectedCaption != null ? 1 : 0.5,
                ),
                width: AppSpacing.borderWidth,
              ),
              color: state.selectedCaption != null
                  ? AppColors.shortsForeground.withValues(alpha: 0.25)
                  : AppColors.transparent,
            ),
            child: Text(
              'CC',
              style: AppTextStyles.badge.copyWith(
                color: AppColors.shortsForeground.withValues(
                  alpha: state.selectedCaption != null ? 1 : 0.6,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

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
                        _roundControl(
                          icon: LucideIcons.chevronDown,
                          tooltip: 'Minimize player',
                          onPressed: () => _fullscreen(false),
                        ),
                        const SizedBox(width: AppSpacing.sm),
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
                          _fullscreenAutoplayControl(autoplay),
                        if (state.captions.isNotEmpty) _captionControl(state),
                        if (!widget.short &&
                            ref.watch(
                              appSettingsProvider.select(
                                (s) => s.backgroundPlay,
                              ),
                            ))
                          _roundControl(
                            icon: LucideIcons.headphones,
                            tooltip:
                                ref.watch(
                                  appSettingsProvider.select(
                                    (s) => s.audioOnly,
                                  ),
                                )
                                ? 'Disable audio only'
                                : 'Audio only',
                            showBackground: false,
                            onPressed: () => unawaited(
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setAudioOnlyPlayback(
                                    !ref.read(appSettingsProvider).audioOnly,
                                  ),
                            ),
                          ),
                        if (Platform.isAndroid &&
                            ref.watch(pictureInPictureProvider.notifier).eligible)
                          _roundControl(
                            icon: LucideIcons.pictureInPicture,
                            tooltip: 'Picture in Picture',
                            showBackground: false,
                            onPressed: () => unawaited(
                              ref.read(pictureInPictureProvider.notifier).enter(),
                            ),
                          ),
                        _roundControl(
                          icon: LucideIcons.settings,
                          tooltip: 'Settings',
                          showBackground: false,
                          onPressed: _settings,
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
                        if (state.seekState == SeekState.seeking ||
                            state.status == PlayerStatus.buffering ||
                            state.recovering)
                          const SizedBox.square(
                            key: ValueKey('fullscreenLoadingIndicator'),
                            dimension: AppSizes.icon,
                            child: CircularProgressIndicator(
                              strokeWidth: AppSizes.seekTrack,
                              color: AppColors.white,
                            ),
                          )
                        else if (state.status == PlayerStatus.ended)
                          _replayAction()
                        else
                          _roundControl(
                            icon: state.playing
                                ? Icons.pause_rounded
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
    _multiTapSeek.cancel(notify: false);
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
    final initialLoading =
        state.status == PlayerStatus.idle ||
        state.status == PlayerStatus.loading;
    final requestVideoId = widget.requestVideoId ?? state.videoId;
    final thumbnailUrl = widget.thumbnailUrl?.isNotEmpty == true
        ? widget.thumbnailUrl!
        : requestVideoId == null || requestVideoId.isEmpty
        ? ''
        : 'https://i.ytimg.com/vi/$requestVideoId/hqdefault.jpg';
    final audioOnly =
        state.mode == PlaybackMode.audio ||
        (!widget.short &&
            ref.watch(
              appSettingsProvider.select((settings) => settings.audioOnly),
            ));
    final frameReady =
        !audioOnly &&
        requestVideoId != null &&
        state.frameReadyId == requestVideoId;
    final videoAspectRatio = videoAspectRatioFromController(service);
    final fillVerticalFullscreen =
        ui.isFullscreen && videoAspectRatio != null && videoAspectRatio < 1;
    _logVideoRatio(service, ui.isFullscreen);
    _syncFullscreenVideoOrientation(ui);
    final compact =
        widget.compact ||
        (!widget.short &&
            !ui.isFullscreen &&
            ui.panelMode == PlayerPanelMode.mini);
    _syncVideoZoom(ui);
    final videoZoomed = _videoZoomed;
    final displayPosition = ui.scrubbing ? ui.scrubPosition : ui.position;
    final inPip = ref.watch(pictureInPictureProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportVideoRect();
    });
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: compact || ui.locked || inPip
                  ? null
                  : (details) {
                      if (widget.short) {
                        _toggleOverlay();
                        return;
                      }
                      _seekVideoId =
                          widget.requestVideoId ?? service.state.videoId;
                      hideTimer?.cancel();
                      _multiTapSeek.tap(
                        forward:
                            details.localPosition.dx >=
                            constraints.maxWidth / 2,
                        position: service.state.position,
                        duration: service.state.duration,
                      );
                    },
              onLongPressStart: compact || inPip
                  ? null
                  : (_) {
                      oldRate = service.state.rate;
                      longPress = true;
                      unawaited(service.setRate(2));
                      setState(() {});
                    },
              onLongPressEnd: compact || inPip
                  ? null
                  : (_) {
                      if (oldRate != null) {
                        unawaited(service.setRate(oldRate!));
                      }
                      longPress = false;
                      setState(() {});
                    },
              onLongPressCancel: compact || inPip
                  ? null
                  : () {
                      if (longPress && oldRate != null) {
                        unawaited(service.setRate(oldRate!));
                      }
                      longPress = false;
                      setState(() {});
                    },
              onVerticalDragStart: compact || videoZoomed || inPip
                  ? null
                  : (d) => unawaited(
                      _startVertical(d, constraints.maxWidth, ui.isFullscreen),
                    ),
              onVerticalDragUpdate: compact || videoZoomed || inPip
                  ? null
                  : (d) => _updateVertical(
                      d,
                      constraints.maxHeight,
                      ui.isFullscreen,
                    ),
              onVerticalDragEnd: compact || videoZoomed || inPip
                  ? null
                  : (d) => _endVertical(d, ui.isFullscreen),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.black),
                  if (thumbnailUrl.startsWith('file:'))
                    Image.file(
                      File.fromUri(Uri.parse(thumbnailUrl)),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.black),
                    )
                  else if (thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppColors.black),
                      placeholder: (_, _) =>
                          const ColoredBox(color: AppColors.black),
                    ),
                  if (!audioOnly)
                    IgnorePointer(
                      ignoring: !frameReady,
                      child: AnimatedOpacity(
                        opacity: frameReady ? 1 : 0,
                        duration: frameReady ? AppMotion.fast : Duration.zero,
                        child:
                            widget.videoOverride ??
                            InteractiveViewer(
                              key: _videoBoxKey,
                              transformationController: _videoTransform,
                              minScale: 1,
                              maxScale: 3,
                              panEnabled: !inPip && !widget.short && !compact,
                              scaleEnabled: !inPip && !widget.short && !compact,
                              child: Video(
                                controller: service.controller,
                                controls: NoVideoControls,
                                fit: inPip
                                    ? BoxFit.contain
                                    : widget.short || fillVerticalFullscreen
                                    ? BoxFit.cover
                                    : BoxFit.contain,
                                subtitleViewConfiguration:
                                    SubtitleViewConfiguration(
                                      visible:
                                          !inPip &&
                                          widget.short &&
                                          !ui.isFullscreen,
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
                ],
              ),
            ),
          ),
          if (!inPip && !audioOnly && state.frozenFrame != null)
            Image.memory(
              state.frozenFrame!,
              fit: fillVerticalFullscreen ? BoxFit.cover : BoxFit.contain,
              gaplessPlayback: true,
            ),
          if (!inPip && !compact && !initialLoading) ...[
            if (ui.isFullscreen)
              _fullscreenOverlay(
                context: context,
                ui: ui,
                state: state,
                autoplay: autoplay,
                notifier: notifier,
              ),
            if (!ui.isFullscreen &&
                (widget.short || ui.panelMode == PlayerPanelMode.expanded))
              Stack(
                fit: StackFit.expand,
                children: [
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
                            bottom: false,
                            child: Stack(
                              fit: StackFit.expand,
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
                                        SizedBox.square(
                                          dimension: AppSizes.touchMin,
                                          child: InkWell(
                                            onTap: () => ref
                                                .read(
                                                  contentPrefsProvider.notifier,
                                                )
                                                .setAutoplay(!autoplay),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Center(
                                              child: Tooltip(
                                                message: autoplay
                                                    ? 'Autoplay on'
                                                    : 'Autoplay off',
                                                child: Container(
                                                  width: 36,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: autoplay
                                                          ? AppColors
                                                                .shortsForeground
                                                          : AppColors
                                                                .shortsForeground
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  alignment: autoplay
                                                      ? Alignment.centerRight
                                                      : Alignment.centerLeft,
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: autoplay
                                                          ? AppColors
                                                                .shortsForeground
                                                          : AppColors
                                                                .shortsForeground
                                                                .withValues(
                                                                  alpha: 0.7,
                                                                ),
                                                    ),
                                                    child: Icon(
                                                      autoplay
                                                          ? Icons
                                                                .play_arrow_rounded
                                                          : Icons.pause_rounded,
                                                      size: 9,
                                                      color: autoplay
                                                          ? AppColors.black
                                                          : AppColors.black
                                                                .withValues(
                                                                  alpha: 0.87,
                                                                ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (state.captions.isNotEmpty)
                                          _captionControl(state),
                                        if (Platform.isAndroid &&
                                            ref.watch(
                                              pictureInPictureProvider.notifier,
                                            ).eligible)
                                          IconButton(
                                            icon: const Icon(
                                              LucideIcons.pictureInPicture,
                                              color: AppColors.shortsForeground,
                                            ),
                                            tooltip: 'Picture in Picture',
                                            onPressed: () => unawaited(
                                              ref
                                                  .read(
                                                    pictureInPictureProvider.notifier,
                                                  )
                                                  .enter(),
                                            ),
                                          ),
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
                                            color: AppColors.black.withValues(
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
                                      if (state.recovering ||
                                          state.status ==
                                              PlayerStatus.buffering)
                                        const SizedBox.square(
                                          dimension: AppSizes.icon,
                                          child: CircularProgressIndicator(
                                            strokeWidth: AppSizes.seekTrack,
                                            color: AppColors.white,
                                          ),
                                        )
                                      else if (state.status ==
                                          PlayerStatus.ended)
                                        _replayAction()
                                      else
                                        Container(
                                          width: AppSizes.playerCenterControl,
                                          height: AppSizes.playerCenterControl,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          child: IconButton(
                                            key: const ValueKey(
                                              'playerPlayPauseButton',
                                            ),
                                            color: AppColors.shortsForeground,
                                            iconSize:
                                                AppSizes.iconLg + AppSpacing.xs,
                                            onPressed: () async {
                                              await service.togglePlay();
                                              if (mounted) _scheduleHide();
                                            },
                                            icon: Icon(
                                              state.playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: AppSpacing.xl),
                                      Opacity(
                                        opacity: widget.onNext == null
                                            ? 0.35
                                            : 1.0,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.black.withValues(
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
                                  key: const ValueKey('inlinePlayerFooter'),
                                  left: 0,
                                  right: 0,
                                  bottom: widget.short
                                      ? AppSpacing.lg
                                      : AppSizes.iconSm + AppSpacing.sm,
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
                                            color: AppColors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.sm,
                                                    vertical: AppSpacing.xs,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.black
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                                    color: AppColors
                                                        .shortsForeground,
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
                                            color: AppColors.black.withValues(
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
                                                  ? Icons
                                                        .fullscreen_exit_rounded
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
                  if (!widget.short)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: AppSizes.iconSm,
                      child: PlayerSeekBar(
                        overlayVisible: ui.overlayVisible,
                        position: ui.displayPosition,
                        buffered: ui.buffered,
                        duration: ui.duration,
                        chapters: widget.chapters,
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
                ],
              ),
            if ((ui.isFullscreen ||
                    (!widget.short &&
                        ui.panelMode == PlayerPanelMode.expanded)) &&
                state.selectedCaption != null &&
                state.subtitleText.trim().isNotEmpty)
              Positioned(
                left: ui.isFullscreen
                    ? AppSizes.fullscreenCaptionInset
                    : AppSpacing.lg,
                right: ui.isFullscreen
                    ? AppSizes.fullscreenCaptionInset
                    : AppSpacing.lg,
                bottom: ui.isFullscreen
                    ? (ui.overlayVisible
                          ? AppSizes.fullscreenCaptionControlsBottom
                          : AppSizes.fullscreenCaptionBottom)
                    : (ui.overlayVisible ? AppSpacing.xxxl : AppSpacing.lg),
                child: IgnorePointer(
                  child: Text(
                    state.subtitleText.trim(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.playerCaption,
                  ),
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
                              '${seekTotal > 0 ? '+' : '-'}${seekTotal.abs()}s',
                              style: AppTextStyles.bodyStrong.copyWith(
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
          if (initialLoading)
            const AbsorbPointer(
              child: ColoredBox(
                color: AppColors.black,
                child: Center(
                  child: SizedBox.square(
                    dimension: AppSizes.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.seekTrack,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
