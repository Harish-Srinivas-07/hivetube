import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/playback/playback_service.dart';
import '../../core/streams/stream_selector.dart';
import '../../core/yt/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class ShortsSelection {
  const ShortsSelection({this.items = const [], this.index = 0});
  final List<ShortItem> items;
  final int index;
}

final shortsSelectionProvider =
    NotifierProvider<ShortsSelectionController, ShortsSelection>(
      ShortsSelectionController.new,
    );

class ShortsSelectionController extends Notifier<ShortsSelection> {
  @override
  ShortsSelection build() => const ShortsSelection();
  void clear() => state = const ShortsSelection();
  void open(List<ShortItem> value, int selected) =>
      state = ShortsSelection(items: List.unmodifiable(value), index: selected);
}

final shortMetadataProvider = FutureProvider.family<ShortItem?, String>(
  (ref, id) async => (await ref.watch(ytApiProvider.future)).reel.metadata(id),
);

class ShortsScreen extends ConsumerStatefulWidget {
  const ShortsScreen({super.key});
  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen>
    with WidgetsBindingObserver {
  List<ShortItem> items = [];
  String? cursor, activeId, prefetchedId;
  bool loading = false,
      failed = false,
      visible = false,
      appActive = true,
      muted = false;
  int generation = 0, currentIndex = 0;
  Brightness shellBrightness = Brightness.light;
  PageController controller = PageController();
  late final ProviderSubscription<ShortsSelection> selectionSubscription;
  PlaybackService? active;
  final Map<String, int> reactions = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final selection = ref.read(shortsSelectionProvider);
    selectionSubscription = ref.listenManual(shortsSelectionProvider, (
      _,
      next,
    ) {
      if (next.items.isNotEmpty) _selected(next);
    });
    if (selection.items.isNotEmpty) {
      _selected(selection);
    } else {
      _refresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    shellBrightness = Theme.of(context).brightness;
    _syncVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appActive = state == AppLifecycleState.resumed;
    _syncVisibility();
  }

  void _syncVisibility() {
    final next = mounted && appActive && TickerMode.valuesOf(context).enabled;
    if (next == visible) return;
    visible = next;
    if (visible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
          systemNavigationBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
      unawaited(active?.setVisible(true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && visible) _playCurrent(ref.read(playbackProvider));
      });
    } else {
      unawaited(active?.setVisible(false));
      _restoreSystemUi();
    }
  }

  void _restoreSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      shellBrightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _selected(ShortsSelection selection) {
    generation++;
    unawaited(active?.pause());
    setState(() {
      items = List.of(selection.items);
      cursor = null;
      failed = false;
      loading = false;
      currentIndex = selection.index.clamp(
        0,
        items.isEmpty ? 0 : items.length - 1,
      );
      activeId = null;
      prefetchedId = null;
    });
    final old = controller;
    controller = PageController(initialPage: currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _load();
  }

  Future<void> _refresh() async {
    generation++;
    unawaited(active?.pause());
    setState(() {
      items = [];
      currentIndex = 0;
      activeId = null;
      prefetchedId = null;
      cursor = null;
      failed = false;
      loading = false;
    });
    await _load();
  }

  Future<void> _load() async {
    if (loading) return;
    setState(() {
      loading = true;
      failed = false;
    });
    final current = generation;
    try {
      final page = await (await ref.read(
        ytApiProvider.future,
      )).reel.fetch(continuation: cursor);
      if (!mounted || current != generation) return;
      final seen = items.map((e) => e.id).toSet();
      setState(() {
        items.addAll(page.items.where((e) => seen.add(e.id)));
        cursor = page.continuation;
        failed = page.failed || items.isEmpty;
      });
      if (visible) {
        _playCurrent(ref.read(playbackProvider));
        _prefetchNext();
      }
    } catch (_) {
      if (mounted && current == generation) setState(() => failed = true);
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  void _prefetchNext() {
    if (active == null || currentIndex + 1 >= items.length) return;
    final id = items[currentIndex + 1].id;
    if (id == prefetchedId) return;
    prefetchedId = id;
    unawaited(active!.preResolve(id, PlaybackMode.short));
  }

  void _playCurrent(PlaybackService? service) {
    if (!visible ||
        service == null ||
        items.isEmpty ||
        currentIndex >= items.length) {
      return;
    }
    final id = items[currentIndex].id;
    active = service;
    if (activeId == id && service.request?.videoId == id) {
      unawaited(service.setVisible(true));
      _prefetchNext();
      return;
    }
    activeId = id;
    prefetchedId = null;
    muted = service.state.muted;
    unawaited(service.setVisible(true));
    unawaited(service.setLoop(true));
    unawaited(service.play(PlayRequest(videoId: id, mode: PlaybackMode.short)));
    _prefetchNext();
  }

  void _movePage(int direction) {
    if (!controller.hasClients || items.isEmpty) return;
    final target = (currentIndex + direction).clamp(0, items.length - 1);
    if (target != currentIndex) {
      controller.animateToPage(
        target,
        duration: AppSpacing.shortsPageDuration,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (visible) _restoreSystemUi();
    selectionSubscription.close();
    unawaited(active?.setVisible(false));
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (previous, next) {
      if (previous != null &&
          (previous.hl != next.hl ||
              previous.gl != next.gl ||
              previous.localContent != next.localContent)) {
        ref.read(shortsSelectionProvider.notifier).clear();
        _refresh();
      }
    });
    final service = ref.watch(playbackProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && visible) _playCurrent(service);
    });
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    return ColoredBox(
      color: AppColors.shortsBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = wide
              ? (constraints.maxHeight * AppSpacing.shortRatio).clamp(
                  0.0,
                  constraints.maxWidth,
                )
              : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _movePage(-1);
                    return KeyEventResult.handled;
                  }
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _movePage(1);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Listener(
                  onPointerSignal: (event) {
                    if (wide &&
                        event is PointerScrollEvent &&
                        event.scrollDelta.dy.abs() >=
                            AppSpacing.shortsWheelThreshold) {
                      _movePage(event.scrollDelta.dy > 0 ? 1 : -1);
                    }
                  },
                  child: items.isEmpty
                      ? Center(
                          child: loading
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: _refresh,
                                  child: const Text(
                                    'Unable to load Shorts — Retry',
                                  ),
                                ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: PageView.builder(
                            key: const ValueKey('shortsPageView'),
                            controller: controller,
                            scrollDirection: Axis.vertical,
                            pageSnapping: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount:
                                items.length + (failed || loading ? 1 : 0),
                            onPageChanged: (index) {
                              setState(() => currentIndex = index);
                              if (index < items.length) {
                                _playCurrent(service);
                              } else {
                                unawaited(service?.setVisible(false));
                              }
                              if (index >= items.length - 3 && cursor != null) {
                                _load();
                              }
                            },
                            itemBuilder: (context, index) {
                              if (index == items.length) {
                                return Center(
                                  child: failed
                                      ? TextButton(
                                          onPressed: _load,
                                          child: const Text('Retry'),
                                        )
                                      : const CircularProgressIndicator(),
                                );
                              }
                              final item = items[index];
                              final meta = ref
                                  .watch(shortMetadataProvider(item.id))
                                  .value;
                              return _ShortPage(
                                key: ValueKey(item.id),
                                item: item,
                                metadata: meta,
                                service: index == currentIndex ? service : null,
                                muted: muted,
                                reaction: reactions[item.id] ?? 0,
                                onMute: () {
                                  setState(() => muted = !muted);
                                  unawaited(service?.setMuted(muted));
                                },
                                onReaction: (value) => setState(
                                  () => reactions[item.id] =
                                      reactions[item.id] == value ? 0 : value,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  const _ShortPage({
    super.key,
    required this.item,
    required this.metadata,
    required this.service,
    required this.muted,
    required this.reaction,
    required this.onMute,
    required this.onReaction,
  });
  final ShortItem item;
  final ShortItem? metadata;
  final PlaybackService? service;
  final bool muted;
  final int reaction;
  final VoidCallback onMute;
  final ValueChanged<int> onReaction;
  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> {
  bool firstFrame = false;
  IconData? feedback;
  @override
  void initState() {
    super.initState();
    _waitForFrame(widget.service);
  }

  @override
  void didUpdateWidget(covariant _ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      firstFrame = false;
      _waitForFrame(widget.service);
    }
  }

  void _waitForFrame(PlaybackService? service) {
    if (service == null) return;
    service.controller.waitUntilFirstFrameRendered
        .then((_) {
          if (mounted && widget.service == service) {
            setState(() => firstFrame = true);
          }
        })
        .catchError((Object _) {});
  }

  Timer? feedbackTimer;
  void _feedback(IconData icon) {
    feedbackTimer?.cancel();
    setState(() => feedback = icon);
    feedbackTimer = Timer(AppSpacing.shortsFeedbackDuration, () {
      if (mounted) setState(() => feedback = null);
    });
  }

  @override
  void dispose() {
    feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final state = service?.state;
    final name = widget.metadata?.channelName ?? widget.item.channelName;
    final title = widget.metadata?.title ?? widget.item.title;
    final avatar =
        widget.metadata?.channelAvatarUrl ?? widget.item.channelAvatarUrl;
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    final safe = MediaQuery.paddingOf(context);
    final bottom =
        safe.bottom +
        (wide
            ? AppSpacing.lg
            : AppSpacing.navHeight + AppSpacing.lg + AppSpacing.lg);
    final duration = state?.duration.inMilliseconds ?? 0;
    final played = duration > 0
        ? (state!.position.inMilliseconds / duration).clamp(0.0, 1.0)
        : 0.0;
    final buffered = duration > 0
        ? (state!.buffered.inMilliseconds / duration).clamp(0.0, 1.0)
        : 0.0;
    final w = state?.videoWidth ?? 0, h = state?.videoHeight ?? 0;
    final portrait =
        h > 0 &&
        ((w / h) - AppSpacing.shortRatio).abs() <=
            AppSpacing.shortsAspectTolerance;
    final frameReady =
        firstFrame &&
        state != null &&
        state.position > Duration.zero &&
        state.status != PlayerStatus.loading;
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: widget.item.thumbUrl,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const Center(
            child: Icon(
              LucideIcons.imageOff,
              color: AppColors.shortsForeground,
            ),
          ),
        ),
        if (service != null)
          Opacity(
            opacity: frameReady ? 1 : 0,
            child: Video(
              controller: service.controller,
              controls: NoVideoControls,
              fit: portrait ? BoxFit.cover : BoxFit.contain,
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: service == null
              ? null
              : () {
                  final playing = service.state.status == PlayerStatus.playing;
                  unawaited(playing ? service.pause() : service.resume());
                  _feedback(playing ? LucideIcons.pause : LucideIcons.play);
                },
          onLongPressStart: service == null
              ? null
              : (_) {
                  unawaited(service.pause());
                  _feedback(LucideIcons.pause);
                },
          onLongPressEnd: service == null
              ? null
              : (_) {
                  unawaited(service.resume());
                  _feedback(LucideIcons.play);
                },
          onDoubleTap: () {
            if (widget.reaction != 1) widget.onReaction(1);
            _feedback(LucideIcons.heart);
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: Container(
              height: AppSpacing.shortsScrimHeight + bottom,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.transparent, AppColors.shortsScrim],
                ),
              ),
            ),
          ),
        ),
        if (feedback != null)
          Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(feedbackTimer),
              tween: Tween(begin: 0, end: 1),
              duration: AppSpacing.shortsFeedbackDuration,
              builder: (context, value, child) => Opacity(
                opacity: (1 - value).clamp(0, 1),
                child: Transform.scale(
                  scale: 1 + value * AppSpacing.shortsFeedbackScale,
                  child: child,
                ),
              ),
              child: Icon(
                feedback,
                size: feedback == LucideIcons.heart
                    ? AppSpacing.shortsHeartIcon
                    : AppSpacing.shortsFeedbackIcon,
                color: feedback == LucideIcons.heart
                    ? AppColors.shortsSelected
                    : AppColors.shortsForeground,
              ),
            ),
          ),
        Positioned(
          top: safe.top + AppSpacing.sm,
          right: AppSpacing.sm,
          child: IconButton(
            key: const ValueKey('shortsMute'),
            tooltip: widget.muted ? 'Unmute' : 'Mute',
            onPressed: widget.onMute,
            color: AppColors.shortsForeground,
            icon: Icon(
              widget.muted ? LucideIcons.volumeX : LucideIcons.volume2,
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.sm,
          bottom: bottom + AppSpacing.xxxl,
          child: Column(
            key: const ValueKey('shortsActionRail'),
            children: [
              _ShortAction(
                icon: LucideIcons.thumbsUp,
                label: 'Like',
                selected: widget.reaction == 1,
                onTap: () => widget.onReaction(1),
              ),
              _ShortAction(
                icon: LucideIcons.thumbsDown,
                label: 'Dislike',
                selected: widget.reaction == -1,
                onTap: () => widget.onReaction(-1),
              ),
              _ShortAction(
                icon: LucideIcons.messageCircle,
                label: 'Comments',
                onTap: () {},
              ),
              _ShortAction(
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: () {},
              ),
              _ShortAction(
                icon: LucideIcons.ellipsis,
                label: 'More',
                onTap: () {},
              ),
            ],
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.shortsRailWidth + AppSpacing.lg,
          bottom: bottom + AppSpacing.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (name != null && name.isNotEmpty)
                Row(
                  children: [
                    CircleAvatar(
                      radius: AppSpacing.avatar / 2,
                      backgroundColor: AppColors.shortsScrim,
                      foregroundImage: avatar == null
                          ? null
                          : CachedNetworkImageProvider(avatar),
                      onForegroundImageError: avatar == null ? null : (_, _) {},
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.shortsForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.shortsForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              if (title != null && title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.shortsForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: SizedBox(
            height: AppSpacing.shortsProgressTouchHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                LinearProgressIndicator(
                  value: buffered,
                  minHeight: AppSpacing.progressHeight,
                  color: AppColors.shortsProgressBuffer,
                  backgroundColor: AppColors.shortsProgressTrack,
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: AppSpacing.progressHeight,
                    activeTrackColor: AppColors.shortsProgressPlayed,
                    inactiveTrackColor: AppColors.transparent,
                    thumbColor: AppColors.shortsProgressPlayed,
                    overlayColor: AppColors.transparent,
                  ),
                  child: Slider(
                    value: played,
                    onChanged: service == null || duration <= 0
                        ? null
                        : (value) => service.seek(
                            Duration(milliseconds: (value * duration).round()),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state?.status == PlayerStatus.loading ||
            state?.status == PlayerStatus.buffering)
          const Center(
            child: CircularProgressIndicator(color: AppColors.shortsForeground),
          ),
        if (state?.status == PlayerStatus.error)
          Center(
            child: Material(
              color: AppColors.shortsScrim,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to play this Short',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.shortsForeground,
                      ),
                    ),
                    TextButton(
                      onPressed: service?.retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShortAction extends StatelessWidget {
  const _ShortAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppSpacing.shortsRailWidth,
    child: Column(
      children: [
        IconButton(
          tooltip: label,
          onPressed: onTap,
          iconSize: AppSpacing.shortsRailIcon,
          color: selected
              ? AppColors.shortsSelected
              : AppColors.shortsForeground,
          icon: Icon(icon),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.shortsForeground),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );
}
