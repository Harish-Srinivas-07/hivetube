import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/playback/audio_handler.dart';
import '../../core/playback/playback_service.dart';
import '../../core/streams/stream_selector.dart';
import '../../core/yt/models.dart';
import '../../core/yt/watch_info.dart';
import '../../features/watch/watch_screen.dart'
    show WatchComments, watchInfoProvider;
import 'shorts_feed_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/player/player_settings_menu.dart';
import '../../widgets/video_options_menu.dart';
import '../../widgets/logger.dart';
import 'package:share_plus/share_plus.dart';

const _shortsSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: AppColors.transparent,
  systemNavigationBarColor: AppColors.transparent,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

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

final _shortReactionProvider =
    Provider.family<_ShortReactionController, String>((ref, id) {
      final controller = _ShortReactionController();
      ref.onDispose(controller.dispose);
      return controller;
    });

final _channelSubscriptionProvider = FutureProvider.family<bool, String>(
  (ref, channelId) async =>
      (await ref.watch(subscriptionRepoProvider).channelIds()).contains(
        channelId,
      ),
);

class _ShortReactionController extends ValueNotifier<int> {
  _ShortReactionController() : super(0);

  void toggle(int value) => this.value = this.value == value ? 0 : value;
}

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
  int currentIndex = 0;
  int playbackGeneration = 0;
  Brightness shellBrightness = Brightness.light;
  PageController controller = PageController();
  late final ProviderSubscription<ShortsSelection> selectionSubscription;
  late final ProviderSubscription<ShortsFeedState> feedSubscription;
  late final ShortsFeedController _feedController;
  PlaybackService? active;
  Stopwatch? _tabOpenTimer;
  bool? _tabOpenCacheHit;
  bool _tabOpenLogged = false, _tabOpenLogScheduled = false;
  int _selectionRequestId = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedController = ref.read(shortsFeedProvider.notifier);
    final feed = ref.read(shortsFeedProvider);
    items = List.of(feed.items);
    cursor = feed.cursor;
    loading = feed.isLoading && feed.items.isEmpty;
    feedSubscription = ref.listenManual(shortsFeedProvider, (_, next) {
      _applyFeedState(next);
    });
    final selection = ref.read(shortsSelectionProvider);
    selectionSubscription = ref.listenManual(shortsSelectionProvider, (
      _,
      next,
    ) {
      if (next.items.isNotEmpty) _queueSelection(next);
    });
    if (selection.items.isNotEmpty) {
      _queueSelection(selection);
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
      final feed = ref.read(shortsFeedProvider);
      _tabOpenTimer = Stopwatch()..start();
      _tabOpenCacheHit = feed.items.isNotEmpty;
      _tabOpenLogged = false;
      _tabOpenLogScheduled = false;
      _applyFeedState(ref.read(shortsFeedProvider));
      if (feed.items.isEmpty) {
        setState(() {
          loading = true;
          failed = false;
        });
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(_shortsSystemUiOverlayStyle);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !visible) return;
        final service = ref.read(playbackProvider);
        await service?.setVisible(true);
        if (!mounted || !visible) return;
        final feedController = ref.read(shortsFeedProvider.notifier);
        final currentFeed = ref.read(shortsFeedProvider);
        if (currentFeed.items.isNotEmpty) {
          feedController.prepareCachedWindow(startIndex: currentIndex);
          unawaited(feedController.refresh());
        } else {
          unawaited(feedController.loadInitial());
        }
        _playCurrent(ref.read(playbackProvider));
      });
    } else {
      _restoreSystemUi();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visible) return;
        unawaited(active?.setVisible(false));
        ref.read(shortsFeedProvider.notifier).releaseWarmWindow();
      });
    }
  }

  void _applyFeedState(ShortsFeedState feed) {
    if (!mounted) return;
    final shouldStartPlayback = items.isEmpty && feed.items.isNotEmpty;
    final activeItemId = currentIndex < items.length
        ? items[currentIndex].id
        : activeId;
    final nextItems = List<ShortItem>.of(feed.items);
    final activeIndex = activeItemId == null
        ? -1
        : nextItems.indexWhere((item) => item.id == activeItemId);
    setState(() {
      items = nextItems;
      cursor = feed.cursor;
      loading = feed.isLoading && feed.items.isEmpty;
      failed = false;
      if (activeIndex >= 0) {
        currentIndex = activeIndex;
      } else if (items.isEmpty) {
        currentIndex = 0;
      } else {
        currentIndex = currentIndex.clamp(0, items.length - 1);
      }
    });
    _logTabOpenIfReady(feed);
    if (visible && shouldStartPlayback && activeId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && visible) _playCurrent(ref.read(playbackProvider));
      });
    }
  }

  void _logTabOpenIfReady(ShortsFeedState feed) {
    final timer = _tabOpenTimer;
    if (timer == null || _tabOpenLogged) return;
    if (_tabOpenCacheHit != true && feed.items.isEmpty && !feed.hasLoaded) {
      return;
    }
    if (_tabOpenLogScheduled) return;
    _tabOpenLogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentTimer = _tabOpenTimer;
      if (!mounted || !visible || currentTimer == null || _tabOpenLogged) {
        return;
      }
      final latest = ref.read(shortsFeedProvider);
      if (_tabOpenCacheHit != true &&
          latest.items.isEmpty &&
          !latest.hasLoaded) {
        _tabOpenLogScheduled = false;
        return;
      }
      _tabOpenLogged = true;
      Logger.log(
        'ShortsTab',
        'open cache=${_tabOpenCacheHit == true ? 'hit' : 'miss'} '
            'ms=${currentTimer.elapsedMilliseconds}',
      );
      currentTimer.stop();
      _tabOpenTimer = null;
    });
  }

  void _restoreSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: AppColors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
        statusBarIconBrightness: shellBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: shellBrightness,
        systemNavigationBarIconBrightness: shellBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _selected(ShortsSelection selection) {
    playbackGeneration++;
    final selectedIndex = selection.index.clamp(
      0,
      selection.items.isEmpty ? 0 : selection.items.length - 1,
    );
    final selectedId = selection.items.isEmpty
        ? null
        : selection.items[selectedIndex].id;
    final feed = ref.read(shortsFeedProvider);
    final canKeepPrepared =
        selectedId != null &&
        feed.items.isNotEmpty &&
        feed.items.first.id == selectedId;
    if (!canKeepPrepared) {
      active?.cancelShortPreloads(disposePlayer: true);
      ref.read(shortsFeedProvider.notifier).releaseWarmWindow();
    }
    unawaited(active?.pause());
    ref
        .read(shortsFeedProvider.notifier)
        .adoptSelection(selection.items, startIndex: selectedIndex);
    setState(() {
      items = List.of(selection.items);
      cursor = ref.read(shortsFeedProvider).cursor;
      failed = false;
      loading = false;
      currentIndex = selectedIndex;
      activeId = null;
      prefetchedId = null;
    });
    final old = controller;
    controller = PageController(initialPage: currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    if (!canKeepPrepared) {
      unawaited(ref.read(shortsFeedProvider.notifier).refresh());
    }
  }

  void _queueSelection(ShortsSelection selection) {
    final requestId = ++_selectionRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && requestId == _selectionRequestId) _selected(selection);
    });
  }

  Future<void> _refresh() async {
    playbackGeneration++;
    ref.read(shortsFeedProvider.notifier).releaseWarmWindow();
    unawaited(active?.pause());
    setState(() {
      failed = false;
      loading = items.isEmpty;
    });
    await ref.read(shortsFeedProvider.notifier).refresh();
  }

  Future<void> _load() => ref.read(shortsFeedProvider.notifier).loadMore();

  void _prefetchNext(PlaybackService service, int pageGeneration) {
    if (!mounted ||
        !visible ||
        pageGeneration != playbackGeneration ||
        currentIndex + 1 >= items.length) {
      return;
    }
    final preloadGeneration = service.beginShortPreloadCycle();
    final nextId = items[currentIndex + 1].id;
    prefetchedId = nextId;
    for (var offset = 1; offset <= 2; offset++) {
      final index = currentIndex + offset;
      if (index < items.length) {
        unawaited(
          service.preResolve(
            items[index].id,
            PlaybackMode.short,
            generation: preloadGeneration,
          ),
        );
      }
    }
    unawaited(service.preloadShort(nextId, generation: preloadGeneration));
  }

  void _cancelShortPreloads() {
    playbackGeneration++;
    active?.cancelShortPreloads(disposePlayer: true);
    ref.read(shortsFeedProvider.notifier).releaseWarmWindow();
  }

  void _updateActiveShortMetadata(ShortItem item) {
    final handler = ref.read(audioHandlerProvider);
    if (handler == null) return;
    final meta = ref.read(shortMetadataProvider(item.id)).value;
    final title = (item.title?.trim().isNotEmpty ?? false)
        ? item.title!.trim()
        : ((meta?.title?.trim().isNotEmpty ?? false)
              ? meta!.title!.trim()
              : 'Short');
    final channel = (item.channelName?.trim().isNotEmpty ?? false)
        ? item.channelName!.trim()
        : ((meta?.channelName?.trim().isNotEmpty ?? false)
              ? meta!.channelName!.trim()
              : 'YouTube Short');
    final thumb = item.thumbUrl.isNotEmpty
        ? item.thumbUrl
        : (meta?.thumbUrl ?? '');
    final artUri = thumb.isNotEmpty ? Uri.tryParse(thumb) : null;
    handler.setShortMetadata(
      id: item.id,
      title: title,
      channel: channel,
      artUri: artUri,
    );
  }

  void _playCurrent(PlaybackService? service) {
    if (!visible ||
        service == null ||
        items.isEmpty ||
        currentIndex >= items.length) {
      return;
    }
    final item = items[currentIndex];
    final id = item.id;
    active = service;
    _updateActiveShortMetadata(item);
    final pageGeneration = ++playbackGeneration;
    if (activeId == id && service.request?.videoId == id) {
      unawaited(_resumeShort(service, id, pageGeneration));
      return;
    }
    activeId = id;
    prefetchedId = null;
    muted = service.state.muted;
    unawaited(_startShort(service, id, pageGeneration));
  }

  Future<void> _resumeShort(
    PlaybackService service,
    String id,
    int pageGeneration,
  ) async {
    await service.setVisible(true);
    if (_isCurrentPlayback(id, pageGeneration)) {
      _prefetchNext(service, pageGeneration);
    }
  }

  Future<void> _startShort(
    PlaybackService service,
    String id,
    int pageGeneration,
  ) async {
    await service.setVisible(true);
    if (!_isCurrentPlayback(id, pageGeneration)) return;
    await service.setLoop(true);
    await service.playShort(id);
    if (_isCurrentPlayback(id, pageGeneration)) {
      _updateActiveShortMetadata(items[currentIndex]);
      _prefetchNext(service, pageGeneration);
    }
  }

  bool _isCurrentPlayback(String id, int pageGeneration) =>
      mounted &&
      visible &&
      pageGeneration == playbackGeneration &&
      currentIndex < items.length &&
      items[currentIndex].id == id;

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
    feedSubscription.close();
    playbackGeneration++;
    final service = active;
    scheduleMicrotask(() {
      service?.cancelShortPreloads(disposePlayer: true);
      _feedController.releaseWarmWindow();
      unawaited(service?.setVisible(false));
    });
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabRefreshProvider, (_, request) {
      if (request?.index == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refresh());
        });
      }
    });
    ref.listen(contentPrefsProvider, (previous, next) {
      if (previous != null && previous.prefsVersion != next.prefsVersion) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(shortsSelectionProvider.notifier).clear();
          ref.read(shortsFeedProvider.notifier).clear();
          unawaited(_refresh());
        });
      }
    });
    final service = ref.watch(playbackProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && visible) _playCurrent(service);
    });
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _shortsSystemUiOverlayStyle,
      child: ColoredBox(
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
                                ? const SizedBox.square(
                                    dimension: AppSizes.iconLg,
                                    child: CircularProgressIndicator(),
                                  )
                                : failed
                                ? AppErrorState(
                                    message: "Couldn't load Shorts",
                                    onRetry: _refresh,
                                  )
                                : const AppEmptyState(
                                    icon: LucideIcons.play,
                                    title: 'No Shorts',
                                  ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: PageView.builder(
                              key: const ValueKey('shortsPageView'),
                              controller: controller,
                              scrollDirection: Axis.vertical,
                              pageSnapping: true,
                              physics: const ClampingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              itemCount:
                                  items.length + (failed || loading ? 1 : 0),
                              onPageChanged: (index) {
                                setState(() => currentIndex = index);
                                if (index < items.length) {
                                  _updateActiveShortMetadata(items[index]);
                                  _playCurrent(service);
                                } else {
                                  _cancelShortPreloads();
                                  unawaited(service?.setVisible(false));
                                }
                                if (index >= items.length - 3 &&
                                    cursor != null) {
                                  _load();
                                }
                              },
                              itemBuilder: (context, index) {
                                if (index == items.length) {
                                  return Center(
                                    child: failed
                                        ? AppErrorState(
                                            message: 'Unable to load Shorts',
                                            onRetry: _load,
                                          )
                                        : const SizedBox.square(
                                            dimension: AppSizes.iconLg,
                                            child: CircularProgressIndicator(),
                                          ),
                                  );
                                }
                                final item = items[index];
                                final metadata = ref
                                    .watch(shortMetadataProvider(item.id))
                                    .value;
                                return _ShortPage(
                                  key: ValueKey(item.id),
                                  item: item,
                                  metadata: metadata,
                                  service: index == currentIndex
                                      ? service
                                      : null,
                                  muted: muted,
                                  reaction: ref.read(
                                    _shortReactionProvider(item.id),
                                  ),
                                  onMute: () {
                                    setState(() => muted = !muted);
                                    unawaited(service?.setMuted(muted));
                                  },
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
      ),
    );
  }
}

class _ShortPage extends ConsumerStatefulWidget {
  const _ShortPage({
    super.key,
    required this.item,
    required this.metadata,
    required this.service,
    required this.muted,
    required this.reaction,
    required this.onMute,
  });
  final ShortItem item;
  final ShortItem? metadata;
  final PlaybackService? service;
  final bool muted;
  final _ShortReactionController reaction;
  final VoidCallback onMute;
  @override
  ConsumerState<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends ConsumerState<_ShortPage> {
  bool firstFrame = false;
  bool _scrubbing = false;
  bool _wasPlayingBeforeScrub = false;
  bool _sharing = false;
  double _scrubFraction = 0.0;
  PlaybackService? _watchedService;
  VideoController? _waitingController;
  IconData? feedback;
  PlayerSettingsSession? _settingsSession;
  bool? _subscriptionOverride;
  bool _subscriptionLoading = false;
  @override
  void initState() {
    super.initState();
    if (widget.service != null) {
      _settingsSession = PlayerSettingsSession(widget.service!);
    }
    _attachService(widget.service);
  }

  @override
  void didUpdateWidget(covariant _ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _settingsSession?.dispose();
      _settingsSession = widget.service == null
          ? null
          : PlayerSettingsSession(widget.service!);
      firstFrame = false;
      _attachService(widget.service);
    }
  }

  void _attachService(PlaybackService? service) {
    if (_watchedService != service) {
      _watchedService?.removeListener(_serviceChanged);
      _watchedService = service;
      service?.addListener(_serviceChanged);
    }
    final controller = service?.controller;
    if (identical(controller, _waitingController)) return;
    _waitingController = controller;
    _waitForFrame(service, controller);
  }

  void _serviceChanged() {
    final service = widget.service;
    if (service == null || identical(service.controller, _waitingController)) {
      return;
    }
    setState(() => firstFrame = false);
    _attachService(service);
  }

  void _toggleReaction(int value) {
    widget.reaction.toggle(value);
    setState(() {});
  }

  void _togglePlayback(PlaybackService service) {
    final current = service.state;
    final willPause =
        current.playing ||
        current.status == PlayerStatus.ready ||
        current.status == PlayerStatus.loading ||
        current.status == PlayerStatus.buffering;
    unawaited(service.togglePlay());
    _feedback(willPause ? LucideIcons.pause : LucideIcons.play);
  }

  Future<void> _shareShort() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.https('www.youtube.com', '/shorts/${widget.item.id}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _waitForFrame(PlaybackService? service, VideoController? controller) {
    if (service == null || controller == null) return;
    controller.waitUntilFirstFrameRendered
        .then((_) {
          if (mounted &&
              widget.service == service &&
              identical(service.controller, controller)) {
            setState(() => firstFrame = true);
          }
        })
        .catchError((Object _) {});
  }

  Future<void> _finishScrub(PlaybackService service, Duration target) async {
    try {
      await service.seekTo(target);
      if (_wasPlayingBeforeScrub) await service.resume();
    } finally {
      if (mounted) {
        setState(() {
          _scrubbing = false;
          _wasPlayingBeforeScrub = false;
        });
      }
    }
  }

  String _formatTime(Duration value) => AppFormatters.formatDuration(value);

  Timer? feedbackTimer;
  Duration _feedbackDuration = AppMotion.base;

  void _feedback(IconData icon, {Duration duration = AppMotion.base}) {
    feedbackTimer?.cancel();
    _feedbackDuration = duration;
    setState(() => feedback = icon);
    feedbackTimer = Timer(duration, () {
      if (mounted) setState(() => feedback = null);
    });
  }

  Future<void> _toggleSubscription({
    required String channelId,
    required String channelName,
    required String avatarUrl,
    required bool isSubscribed,
  }) async {
    if (_subscriptionLoading) return;
    setState(() {
      _subscriptionOverride = !isSubscribed;
      _subscriptionLoading = true;
    });
    try {
      await ref
          .read(subscriptionRepoProvider)
          .setSubscribed(
            channelId,
            !isSubscribed,
            name: channelName,
            avatarUrl: avatarUrl,
          );
      ref.invalidate(_channelSubscriptionProvider(channelId));
    } catch (_) {
      if (mounted) {
        setState(() => _subscriptionOverride = isSubscribed);
        AppSnackbar.show(
          context,
          'Could not update subscription',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _subscriptionLoading = false);
    }
  }

  Future<void> _openComments() async {
    final videoId = widget.item.id;
    await showAppSheet<void>(
      context,
      title: 'Comments',
      showClose: false,
      compactHeader: true,
      builder: (sheetContext, scrollController) {
        return Consumer(
          builder: (context, ref, _) => ref
              .watch(watchInfoProvider(videoId))
              .when(
                data: (info) => info.commentsToken == null
                    ? const Center(child: Text('Comments unavailable'))
                    : WatchComments(
                        token: info.commentsToken!,
                        scrollController: scrollController!,
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Could not load comments')),
              ),
        );
      },
    );
  }

  Future<void> _openShortDetails() async {
    final infoFuture = ref.read(watchInfoProvider(widget.item.id).future);
    await showAppSheet<void>(
      context,
      title: 'Details',
      showClose: false,
      fit: true,
      builder: (sheetContext, _) => FutureBuilder<WatchInfo>(
        future: infoFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Could not load video details'),
            );
          }
          final info = snapshot.data;
          if (info == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title.isNotEmpty
                      ? info.title
                      : (widget.metadata?.title ?? widget.item.title ?? ''),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  [
                    info.views,
                    info.date,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (info.channelName.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(info.channelName, style: AppTextStyles.bodyStrong),
                ],
                if (info.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    info.description,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openMoreOptions() {
    final session = _settingsSession;
    if (session != null) {
      unawaited(showPlayerSettingsMenu(context, session: session));
    } else {
      unawaited(
        showVideoOptionsMenu(context, videoId: widget.item.id, onVideo: true),
      );
    }
  }

  @override
  void dispose() {
    feedbackTimer?.cancel();
    _watchedService?.removeListener(_serviceChanged);
    _settingsSession?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final state = service?.state;
    final metadata = widget.metadata;
    final name = metadata?.channelName ?? widget.item.channelName;
    final title = metadata?.title ?? widget.item.title;
    final avatar = metadata?.channelAvatarUrl ?? widget.item.channelAvatarUrl;
    final channelId = widget.item.channelId;
    final subscription = channelId == null || channelId.isEmpty
        ? false
        : ref.watch(_channelSubscriptionProvider(channelId)).value ?? false;
    final isSubscribed = _subscriptionOverride ?? subscription;
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    final safe = MediaQuery.paddingOf(context);
    final bottom =
        safe.bottom +
        (wide ? AppSpacing.lg : AppSpacing.navHeight + AppSpacing.lg);
    final duration = state?.duration.inMilliseconds ?? 0;
    final played = duration > 0
        ? (state!.position.inMilliseconds / duration).clamp(0.0, 1.0)
        : 0.0;
    final buffered = duration > 0
        ? (state!.buffered.inMilliseconds / duration).clamp(0.0, 1.0)
        : 0.0;
    final frameReady =
        firstFrame &&
        state != null &&
        service?.isFrameReadyFor(widget.item.id) == true &&
        state.status != PlayerStatus.loading;
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.shortsBackground),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = min(
                constraints.maxWidth,
                constraints.maxHeight * AppSpacing.shortRatio,
              );
              return SizedBox(
                width: width,
                height: width / AppSpacing.shortRatio,
                child: Stack(
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
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: service == null ? null : () => _togglePlayback(service),
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
            if (widget.reaction.value != 1) _toggleReaction(1);
            _feedback(LucideIcons.heart, duration: AppMotion.base * 2);
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: Container(
              height: AppSpacing.shortsScrimHeight + bottom,
              decoration: const BoxDecoration(
                // allowed: shorts scrim
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.transparent, AppColors.scrim50],
                ),
              ),
            ),
          ),
        ),
        if (feedback == null && state?.status == PlayerStatus.paused)
          Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: const Center(
              child: _ShortPlaybackIndicator(icon: LucideIcons.pause),
            ),
          ),
        if (feedback != null)
          Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(feedbackTimer),
                tween: Tween(begin: 0, end: 1),
                duration: _feedbackDuration,
                builder: (context, value, child) => Opacity(
                  opacity: (1 - value).clamp(0, 1),
                  child: Transform.scale(
                    scale: 1 + value * AppSpacing.shortsFeedbackScale,
                    child: child,
                  ),
                ),
                child: feedback == LucideIcons.heart
                    ? Icon(
                        feedback,
                        size: AppSpacing.shortsHeartIcon,
                        color: AppColors.shortsSelected,
                      )
                    : _ShortPlaybackIndicator(icon: feedback!),
              ),
            ),
          ),
        Positioned(
          top: safe.top,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.shortsTopControlsTint,
                    AppColors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.canPop() ? 'Close' : 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    color: AppColors.shortsForeground,
                    icon: Icon(
                      context.canPop() ? LucideIcons.x : LucideIcons.arrowLeft,
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.touchMin,
                      height: AppSizes.touchMin,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('shortsMute'),
                    tooltip: widget.muted ? 'Unmute' : 'Mute',
                    onPressed: widget.onMute,
                    color: AppColors.shortsForeground,
                    icon: Icon(
                      widget.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.touchMin,
                      height: AppSizes.touchMin,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => context.push('/search'),
                    color: AppColors.shortsForeground,
                    icon: const Icon(LucideIcons.search),
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.touchMin,
                      height: AppSizes.touchMin,
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: _openMoreOptions,
                    color: AppColors.shortsForeground,
                    icon: const Icon(LucideIcons.ellipsis),
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.touchMin,
                      height: AppSizes.touchMin,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.none,
          bottom: bottom + AppSpacing.xxl,
          child: Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: Container(
              width: AppSpacing.shortsRailWidth + AppSpacing.lg,
              decoration: const BoxDecoration(
                // allowed: shorts scrim
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColors.shortsTopControlsTint,
                    AppColors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: SingleChildScrollView(
                  child: Column(
                    key: const ValueKey('shortsActionRail'),
                    children: [
                      _ShortAction(
                        icon: widget.reaction.value == 1
                            ? Icons.thumb_up
                            : LucideIcons.thumbsUp,
                        label: 'Like',
                        onTap: () => _toggleReaction(1),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ShortAction(
                        icon: widget.reaction.value == -1
                            ? Icons.thumb_down
                            : LucideIcons.thumbsDown,
                        label: 'Dislike',
                        onTap: () => _toggleReaction(-1),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ShortAction(
                        icon: LucideIcons.messageCircle,
                        label: 'Comments',
                        onTap: () => unawaited(_openComments()),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ShortAction(
                        icon: LucideIcons.share2,
                        label: 'Share',
                        isLoading: _sharing,
                        onTap: () => unawaited(_shareShort()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.none,
          right: AppSpacing.none,
          bottom: AppSpacing.none,
          height: AppSpacing.shortsScrimHeight + bottom + AppSpacing.md,
          child: IgnorePointer(
            child: Opacity(
              opacity: _scrubbing ? 0.35 : 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.shortsTopControlsTint,
                      AppColors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.shortsRailWidth + AppSpacing.lg,
          bottom: bottom + AppSpacing.md,
          child: Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null && name.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: channelId == null || channelId.isEmpty
                              ? null
                              : () => context.push('/channel/$channelId'),
                          child: Row(
                            children: [
                              ChannelAvatar(
                                name: name,
                                url: avatar ?? '',
                                size: AppSizes.avatarSm + AppSpacing.sm,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  '@${name.replaceFirst(RegExp(r'^@'), '')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyStrong.copyWith(
                                    color: AppColors.shortsForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (channelId != null && channelId.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              onSurface: isSubscribed
                                  ? AppColors.white
                                  : AppColors.black,
                              surfaceContainerHighest: isSubscribed
                                  ? AppColors.shortsNavGlassFill
                                  : AppColors.white,
                            ),
                          ),
                          child: AppButton(
                            label: isSubscribed ? 'Subscribed' : 'Subscribe',
                            variant: isSubscribed
                                ? AppButtonVariant.tonal
                                : AppButtonVariant.filled,
                            size: AppButtonSize.compact,
                            isLoading: _subscriptionLoading,
                            onPressed: () => unawaited(
                              _toggleSubscription(
                                channelId: channelId,
                                channelName: name,
                                avatarUrl: avatar ?? '',
                                isSubscribed: isSubscribed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (title != null && title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: GestureDetector(
                      key: const ValueKey('shortsDetailsTitle'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(_openShortDetails()),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: title),
                            TextSpan(
                              text: ' …more',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.shortsForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.shortsForeground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_scrubbing && state != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '${_formatTime(Duration(milliseconds: (_scrubFraction * duration).round()))} / ${_formatTime(state.duration)}',
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final currentPlayed = _scrubbing ? _scrubFraction : played;
              const barHeight = AppSpacing.shortsProgressIdleHeight;
              double fraction(Offset offset) =>
                  (offset.dx / constraints.maxWidth).clamp(0.0, 1.0);
              Duration targetAt(double value) =>
                  Duration(milliseconds: (value * duration).round());
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: service == null || duration <= 0
                    ? null
                    : (details) {
                        unawaited(
                          service.seekTo(
                            targetAt(fraction(details.localPosition)),
                          ),
                        );
                      },
                onHorizontalDragStart: service == null || duration <= 0
                    ? null
                    : (details) {
                        _wasPlayingBeforeScrub =
                            service.state.status == PlayerStatus.playing;
                        setState(() {
                          _scrubbing = true;
                          _scrubFraction = fraction(details.localPosition);
                        });
                        if (_wasPlayingBeforeScrub) unawaited(service.pause());
                      },
                onHorizontalDragUpdate: service == null || duration <= 0
                    ? null
                    : (details) {
                        setState(() {
                          _scrubFraction = fraction(details.localPosition);
                        });
                      },
                onHorizontalDragEnd: service == null || duration <= 0
                    ? null
                    : (_) => unawaited(
                        _finishScrub(service, targetAt(_scrubFraction)),
                      ),
                onHorizontalDragCancel: () {
                  if (!_scrubbing) return;
                  final shouldResume = _wasPlayingBeforeScrub;
                  setState(() {
                    _scrubbing = false;
                    _wasPlayingBeforeScrub = false;
                  });
                  if (shouldResume) unawaited(service?.resume());
                },
                child: SizedBox(
                  height: AppSpacing.shortsProgressTouchHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: barHeight,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          LinearProgressIndicator(
                            value: buffered,
                            minHeight: barHeight,
                            color: AppColors.shortsProgressBuffer,
                            backgroundColor: AppColors.shortsProgressTrack,
                          ),
                          Positioned(
                            left: AppSpacing.none,
                            top: AppSpacing.none,
                            bottom: AppSpacing.none,
                            width: constraints.maxWidth * currentPlayed,
                            child: Container(
                              height: barHeight,
                              color: AppColors.shortsProgressPlayed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (state?.status == PlayerStatus.loading ||
            state?.status == PlayerStatus.buffering)
          const IgnorePointer(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.shortsForeground,
              ),
            ),
          ),
        if (state?.status == PlayerStatus.error)
          Center(
            child: AppErrorState(
              message: 'Unable to play this Short',
              onRetry: service?.retry,
            ),
          ),
      ],
    );
  }
}

class _ShortPlaybackIndicator extends StatelessWidget {
  const _ShortPlaybackIndicator({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpacing.shortsFeedbackIcon,
    height: AppSpacing.shortsFeedbackIcon,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.playerControlGlass,
    ),
    child: Icon(icon, size: AppSizes.iconLg, color: AppColors.shortsForeground),
  );
}

class _ShortAction extends StatefulWidget {
  const _ShortAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  State<_ShortAction> createState() => _ShortActionState();
}

class _ShortActionState extends State<_ShortAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.imageFade,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppSpacing.shortsRailWidth,
    child: Column(
      children: [
        IconButton(
          tooltip: widget.label,
          onPressed: () {
            if (widget.isLoading) return;
            _controller.forward(from: 0);
            widget.onTap();
          },
          iconSize: AppSpacing.shortsRailIcon,
          color: AppColors.shortsForeground,
          icon: widget.isLoading
              ? SizedBox.square(
                  dimension: AppSpacing.shortsRailIcon,
                  child: CircularProgressIndicator(
                    color: AppColors.shortsForeground,
                    strokeWidth: AppSpacing.borderWidth,
                  ),
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.scale(
                    scale:
                        1 +
                        AppSpacing.shortsFeedbackScale *
                            (1 - (_controller.value * 2 - 1).abs()),
                    child: child,
                  ),
                  child: Icon(
                    widget.icon,
                    shadows: const [
                      Shadow(
                        color: AppColors.shortsActionShadow,
                        blurRadius: AppSpacing.xs,
                        offset: Offset(AppSpacing.none, AppSpacing.xxs),
                      ),
                    ],
                  ),
                ),
        ),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.shortsForeground,
            shadows: const [
              Shadow(
                color: AppColors.shortsActionShadow,
                blurRadius: AppSpacing.xs,
                offset: Offset(AppSpacing.none, AppSpacing.xxs),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
