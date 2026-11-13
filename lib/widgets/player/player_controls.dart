import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

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
  bool liked = false, disliked = false, saved = false;
  double? oldRate, dragStartValue;
  String? hud;
  String subtitleText = '';
  StreamSubscription<List<String>>? _subtitleSubscription;
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
    _listenToSubtitles();
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
      _listenToSubtitles();
      lastStatus = null;
      _changed();
    }
  }

  void _listenToSubtitles() {
    _subtitleSubscription?.cancel();
    subtitleText = widget.service.player.state.subtitle
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
    _subtitleSubscription = widget.service.player.stream.subtitle.listen((lines) {
      if (!mounted) return;
      setState(() {
        subtitleText = lines.where((line) => line.trim().isNotEmpty).join('\n');
      });
    });
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
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('More videos'),
                subtitle: const Text('Continue to the next video'),
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: const Text('Play next'),
                enabled: widget.onNext != null,
                onTap: widget.onNext == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onNext?.call();
                      },
              ),
            ],
          ),
        ),
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

  Widget _roundControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = 23,
    double diameter = 48,
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
      color: dimmed ? Colors.white38 : Colors.white,
      disabledColor: Colors.white38,
    ),
  );

  Widget _actionControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool selected = false,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: selected ? AppColors.primary : Colors.white),
  );

  Future<void> _copyVideoLink() async {
    final id = widget.service.request?.videoId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: 'https://youtu.be/$id'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video link copied')),
    );
  }

  void _showActionMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
        : (service.request?.videoId ?? 'HiveTube');
    final channel = mediaItem?.artist ?? '';
    final durationMs = math.max(1, ui.duration.inMilliseconds).toDouble();
    final positionMs = ui.displayPosition.inMilliseconds
        .clamp(0, durationMs.toInt())
        .toDouble();
    final bufferMs = ui.buffered.inMilliseconds
        .clamp(positionMs.toInt(), durationMs.toInt())
        .toDouble();
    final thumbnailUrl = service.request == null
        ? null
        : 'https://i.ytimg.com/vi/${service.request!.videoId}/mqdefault.jpg';
    final caption = subtitleText.trim();

    return IgnorePointer(
      ignoring: !ui.overlayVisible,
      child: AnimatedOpacity(
        key: const ValueKey('fullscreenPlayerOverlay'),
        opacity: ui.overlayVisible ? 1 : 0,
        duration: AppMotion.base,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .24, .55, 1],
                    colors: [
                      Color(0xB8000000),
                      Color(0x00000000),
                      Color(0x12000000),
                      Color(0xC9000000),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 6,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        _roundControl(
                          icon: Icons.keyboard_arrow_down_rounded,
                          tooltip: 'Exit fullscreen',
                          onPressed: () => _fullscreen(false),
                          diameter: 42,
                          size: 29,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [Colors.white, Colors.white70, Colors.transparent],
                                      stops: [0, .8, 1],
                                    ).createShader(bounds),
                                blendMode: BlendMode.dstIn,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (channel.isNotEmpty)
                                Text(
                                  channel.startsWith('@') ? channel : '@$channel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                horizontal: 5,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white24,
                                    ),
                                    child: Icon(
                                      autoplay
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Text(
                                    'Autoplay',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _roundControl(
                          icon: Icons.cast_rounded,
                          tooltip: 'Cast',
                          onPressed: () => _showActionMessage('Cast is unavailable'),
                          diameter: 42,
                        ),
                        _roundControl(
                          icon: Icons.closed_caption_rounded,
                          tooltip: 'Captions',
                          onPressed: state.captions.isEmpty
                              ? null
                              : () => unawaited(
                                  service.setCaption(
                                    state.selectedCaption == null ? 0 : null,
                                  ),
                                ),
                          diameter: 42,
                        ),
                        _roundControl(
                          icon: Icons.settings_rounded,
                          tooltip: 'Settings',
                          onPressed: _settings,
                          diameter: 42,
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
                          diameter: 58,
                          size: 31,
                          dimmed: widget.onPrevious == null,
                        ),
                        const SizedBox(width: 30),
                        _roundControl(
                          icon: state.status == PlayerStatus.playing
                              ? Icons.pause_rounded
                              : state.status == PlayerStatus.ended
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: state.status == PlayerStatus.playing
                              ? 'Pause'
                              : 'Play',
                          onPressed: () => unawaited(service.togglePlayPause()),
                          diameter: 76,
                          size: 43,
                        ),
                        const SizedBox(width: 30),
                        _roundControl(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Next',
                          onPressed: widget.onNext,
                          diameter: 58,
                          size: 31,
                          dimmed: widget.onNext == null,
                        ),
                      ],
                    ),
                  ),
                  if (caption.isNotEmpty)
                    Positioned(
                      left: 40,
                      right: 40,
                      bottom: 150,
                      child: IgnorePointer(
                        child: Text(
                          caption,
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
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 98,
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.playerControlGlass,
                            borderRadius: AppRadius.pillBorder,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            child: Text(
                              '${_time(Duration(milliseconds: positionMs.round()))} / ${_time(ui.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _roundControl(
                          icon: Icons.fullscreen_exit_rounded,
                          tooltip: 'Exit fullscreen',
                          onPressed: () => _fullscreen(false),
                          diameter: 42,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 72,
                    height: 24,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: const Color(0xFFFF1744),
                        secondaryActiveTrackColor: Colors.white70,
                        inactiveTrackColor: Colors.white38,
                        thumbColor: const Color(0xFFFF1744),
                        overlayColor: const Color(0x22FF1744),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
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
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 8,
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: AppRadius.lgBorder,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _actionControl(
                                    icon: liked
                                        ? Icons.thumb_up_rounded
                                        : Icons.thumb_up_outlined,
                                    tooltip: 'Like',
                                    selected: liked,
                                    onPressed: () => setState(() {
                                      liked = !liked;
                                      if (liked) disliked = false;
                                    }),
                                  ),
                                  _actionControl(
                                    icon: disliked
                                        ? Icons.thumb_down_rounded
                                        : Icons.thumb_down_outlined,
                                    tooltip: 'Dislike',
                                    selected: disliked,
                                    onPressed: () => setState(() {
                                      disliked = !disliked;
                                      if (disliked) liked = false;
                                    }),
                                  ),
                                  _actionControl(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    tooltip: 'Comments',
                                    onPressed: () => _showActionMessage(
                                      'Open the watch page to view comments',
                                    ),
                                  ),
                                  _actionControl(
                                    icon: Icons.forum_outlined,
                                    tooltip: 'Live chat',
                                    onPressed: () => _showActionMessage(
                                      'Live chat is unavailable for this video',
                                    ),
                                  ),
                                  _actionControl(
                                    icon: saved
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    tooltip: 'Save',
                                    selected: saved,
                                    onPressed: () => setState(
                                      () => saved = !saved,
                                    ),
                                  ),
                                  _actionControl(
                                    icon: Icons.ios_share_rounded,
                                    tooltip: 'Share',
                                    onPressed: () => unawaited(_copyVideoLink()),
                                  ),
                                  _actionControl(
                                    icon: Icons.auto_awesome_rounded,
                                    tooltip: 'More options',
                                    onPressed: () => _showActionMessage(
                                      'More options are available on the watch page',
                                    ),
                                  ),
                                  _actionControl(
                                    icon: Icons.more_horiz_rounded,
                                    tooltip: 'More',
                                    onPressed: _moreVideos,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _moreVideos,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: const Text('More videos'),
                          ),
                          if (thumbnailUrl != null)
                            InkWell(
                              onTap: _moreVideos,
                              borderRadius: AppRadius.smBorder,
                              child: ClipRRect(
                                borderRadius: AppRadius.smBorder,
                                child: Image.network(
                                  thumbnailUrl,
                                  width: 68,
                                  height: 38,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 68,
                                    height: 38,
                                    child: Icon(Icons.play_arrow_rounded),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
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
    );
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    seekTimer?.cancel();
    _doubleTapCommitTimer?.cancel();
    hudTimer?.cancel();
    _subtitleSubscription?.cancel();
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
            if (ui.isFullscreen &&
                (ui.panelProgress == 0 || ui.panelProgress > .3))
              _fullscreenOverlay(
                context: context,
                ui: ui,
                state: state,
                autoplay: autoplay,
                notifier: notifier,
              ),
            if (!ui.isFullscreen &&
                (ui.panelProgress == 0 || ui.panelProgress > .3))
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
                                              await service.togglePlayPause();
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
                !ui.isFullscreen &&
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
