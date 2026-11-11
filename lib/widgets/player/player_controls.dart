import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/playback/playback_service.dart';
import '../../theme/app_spacing.dart';

class SharedPlayer extends StatefulWidget {
  const SharedPlayer({super.key, required this.service, this.short = false});
  final PlaybackService service;
  final bool short;
  @override
  State<SharedPlayer> createState() => _SharedPlayerState();
}

class _SharedPlayerState extends State<SharedPlayer> {
  bool visible = true, fullscreen = false;
  Timer? timer;
  String? seekLabel;
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    _hideLater();
  }

  @override
  void didUpdateWidget(covariant SharedPlayer old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      old.service.removeListener(_changed);
      widget.service.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _hideLater() {
    timer?.cancel();
    timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => visible = false);
    });
  }

  void _toggleControls() {
    setState(() => visible = !visible);
    if (visible) _hideLater();
  }

  void _seekBy(int seconds) {
    final s = widget.service;
    unawaited(s.seek(s.state.position + Duration(seconds: seconds)));
    setState(() {
      seekLabel = '${seconds > 0 ? '+' : ''}$seconds s';
      visible = true;
    });
    _hideLater();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => seekLabel = null);
    });
  }

  Future<void> _fullscreen() async {
    fullscreen = !fullscreen;
    if (fullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final s = widget.service;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      s.state.status == PlayerStatus.playing ? s.pause() : s.resume();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ) {
      _seekBy(-10);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _seekBy(10);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      s.setVolume(s.state.volume + 5);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      s.setVolume(s.state.volume - 5);
    } else if (key == LogicalKeyboardKey.keyM) {
      s.setMuted(!s.state.muted);
    } else if (key == LogicalKeyboardKey.keyF ||
        (key == LogicalKeyboardKey.escape && fullscreen)) {
      _fullscreen();
    } else {
      return KeyEventResult.ignored;
    }
    _hideLater();
    return KeyEventResult.handled;
  }

  String _time(Duration v) {
    final h = v.inHours;
    final m = v.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = v.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.service.removeListener(_changed);
    if (fullscreen) {
      SystemChrome.setPreferredOrientations([]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final state = service.state;
    final colors = Theme.of(context).colorScheme;
    final duration = state.duration.inMilliseconds.toDouble();
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: service.controller,
            controls: NoVideoControls,
            fit: widget.short ? BoxFit.cover : BoxFit.contain,
          ),
          Row(
            children: [
              for (final seconds in [-10, 10])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (widget.short) {
                        state.status == PlayerStatus.playing
                            ? service.pause()
                            : service.resume();
                        setState(() => visible = true);
                        _hideLater();
                      } else {
                        _toggleControls();
                      }
                    },
                    onDoubleTap: () => _seekBy(seconds),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
          if (seekLabel != null) Center(child: Chip(label: Text(seekLabel!))),
          if (state.status == PlayerStatus.loading ||
              state.status == PlayerStatus.buffering)
            const Center(child: CircularProgressIndicator()),
          if (state.status == PlayerStatus.error)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Unable to play: ${state.error?.name ?? 'unknown'}'),
                      TextButton(
                        onPressed: service.retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (visible && state.status != PlayerStatus.error) ...[
            Center(
              child: IconButton.filledTonal(
                onPressed: () {
                  state.status == PlayerStatus.playing
                      ? service.pause()
                      : service.resume();
                  _hideLater();
                },
                icon: Icon(
                  state.status == PlayerStatus.playing
                      ? LucideIcons.pause
                      : LucideIcons.play,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: colors.surface.withValues(alpha: 0.88),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.short)
                      SliderTheme(
                        data: SliderTheme.of(
                          context,
                        ).copyWith(trackHeight: AppSpacing.xs),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Slider(
                              value: duration > 0
                                  ? (state.buffered.inMilliseconds / duration)
                                        .clamp(0, 1)
                                  : 0,
                              onChanged: null,
                            ),
                            Slider(
                              value: duration > 0
                                  ? (state.position.inMilliseconds / duration)
                                        .clamp(0, 1)
                                  : 0,
                              onChanged: duration <= 0
                                  ? null
                                  : (v) => service.seek(
                                      Duration(
                                        milliseconds: (duration * v).round(),
                                      ),
                                    ),
                              onChangeEnd: (_) => _hideLater(),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (!widget.short)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Text(
                              '${_time(state.position)} / ${_time(state.duration)}',
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Mute',
                          onPressed: () => service.setMuted(!state.muted),
                          icon: Icon(
                            state.muted
                                ? LucideIcons.volumeX
                                : LucideIcons.volume2,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Loop',
                          onPressed: () => service.setLoop(!state.loop),
                          color: state.loop ? colors.primary : null,
                          icon: const Icon(LucideIcons.repeat1),
                        ),
                        if (!widget.short)
                          PopupMenuButton<double>(
                            tooltip: 'Speed',
                            onSelected: service.setRate,
                            itemBuilder: (_) => [
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
                                PopupMenuItem(
                                  value: rate,
                                  child: Text('${rate}x'),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Text('${state.rate}x'),
                            ),
                          ),
                        if (!widget.short)
                          PopupMenuButton<int>(
                            tooltip: 'Quality',
                            onSelected: (v) =>
                                service.setQuality(v == 0 ? null : v),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 0,
                                child: Text('Auto'),
                              ),
                              for (final h in state.heights)
                                PopupMenuItem(value: h, child: Text('${h}p')),
                            ],
                            icon: const Icon(LucideIcons.settings2),
                          ),
                        IconButton(
                          tooltip: 'Fullscreen',
                          onPressed: _fullscreen,
                          icon: Icon(
                            fullscreen
                                ? LucideIcons.minimize
                                : LucideIcons.maximize,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
