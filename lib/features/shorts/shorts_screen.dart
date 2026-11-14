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
import '../../features/watch/watch_screen.dart'
    show watchCommentsProvider, watchInfoProvider;
import '../home/home_shorts.dart';
import '../home/home_variety.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/player/player_settings_menu.dart';
import '../../widgets/video_options_menu.dart';
import 'package:share_plus/share_plus.dart';

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
  int generation = 0, currentIndex = 0;
  int playbackGeneration = 0;
  Brightness shellBrightness = Brightness.light;
  PageController controller = PageController();
  late final ProviderSubscription<ShortsSelection> selectionSubscription;
  PlaybackService? active;
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
    playbackGeneration++;
    active?.cancelShortPreloads(disposePlayer: true);
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
    playbackGeneration++;
    active?.cancelShortPreloads(disposePlayer: true);
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
      final api = await ref.read(ytApiProvider.future);
      final prefs = ref.read(contentPrefsProvider);
      final page = await api.reel.fetch(continuation: cursor, count: 24);
      final regional = <ShortItem>[];
      if (cursor == null) {
        final history = await ref.read(historyRepoProvider).recent();
        final queries = shortsQueries(
          chip: 'All',
          channels: const [],
          random: Random(DateTime.now().microsecondsSinceEpoch ^ current),
          localRatio: prefs.localRatio,
          shownLanguages: prefs.contentLanguages,
          hasHistory: history.isNotEmpty,
        );
        final pages = await Future.wait(
          queries.map((query) async {
            try {
              return await api.search.shortsPage(query);
            } catch (_) {
              return const ShortPage([], null);
            }
          }),
        );
        regional.addAll(pages.expand((result) => result.items).take(36));
      }
      final candidates = <String, ShortItem>{};
      for (final item in [...regional, ...page.items]) {
        candidates.putIfAbsent(item.id, () => item);
      }
      final enriched = await Future.wait(
        candidates.values.take(60).map((item) async {
          try {
            final metadata = await api.reel.metadata(item.id);
            if (metadata == null) return item;
            return ShortItem(
              id: item.id,
              thumbUrl: item.thumbUrl,
              title: item.title ?? metadata.title,
              channelName: metadata.channelName,
              channelId: metadata.channelId,
              channelAvatarUrl: metadata.channelAvatarUrl,
              viewsText: item.viewsText ?? metadata.viewsText,
            );
          } catch (_) {
            return item;
          }
        }),
      );
      final seen = SeenVideos.decode(
        await ref.read(dbProvider).getValue('home_seen_videos_v1'),
        DateTime.now(),
      );
      final rankedIds = rankHomeItems(
        [
          for (final item in enriched)
            VideoItem(
              id: item.id,
              title: item.title ?? '',
              channelId: item.channelId ?? '',
              channelName: item.channelName ?? '',
              channelAvatarUrl: item.channelAvatarUrl ?? '',
              thumbUrl: item.thumbUrl,
              isShort: true,
            ),
        ],
        preferred: prefs.contentLanguages,
        hidden: prefs.hiddenLanguages,
        seen: seen.ids,
        random: Random(prefs.prefsVersion ^ current),
      ).map((item) => item.id).toList();
      final byId = {for (final item in enriched) item.id: item};
      final filteredItems = rankedIds.map((id) => byId[id]!).toList();
      if (!mounted || current != generation) return;
      final existingIds = items.map((e) => e.id).toSet();
      setState(() {
        items.addAll(filteredItems.where((e) => existingIds.add(e.id)));
        cursor = page.continuation;
        failed = page.failed;
      });
      if (visible) {
        _playCurrent(ref.read(playbackProvider));
      }
    } catch (_) {
      if (mounted && current == generation) setState(() => failed = true);
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

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
    playbackGeneration++;
    active?.cancelShortPreloads(disposePlayer: true);
    unawaited(active?.setVisible(false));
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabRefreshProvider, (_, request) {
      if (request?.index == 1) unawaited(_refresh());
    });
    ref.listen(contentPrefsProvider, (previous, next) {
      if (previous != null && previous.prefsVersion != next.prefsVersion) {
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
                              if (index >= items.length - 3 && cursor != null) {
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
                                service: index == currentIndex ? service : null,
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

  Future<void> _onSubscribePressed({
    required String channelId,
    required String channelName,
    required String avatarUrl,
    required bool isSubscribed,
  }) async {
    if (!isSubscribed) {
      await _toggleSubscription(
        channelId: channelId,
        channelName: channelName,
        avatarUrl: avatarUrl,
        isSubscribed: false,
      );
      return;
    }
    final key = 'subscription_notifications_$channelId';
    final current = await ref.read(dbProvider).getValue(key) ?? 'Personalized';
    if (!mounted) return;
    final selected = await showAppSheet<String>(
      context,
      fit: true,
      title: 'Notifications',
      builder: (sheetContext, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in const ['All', 'Personalized', 'None'])
            AppSheetRow(
              icon: option == 'None' ? LucideIcons.bellOff : LucideIcons.bell,
              label: option,
              selected: current == option,
              onTap: () => Navigator.pop(sheetContext, option),
            ),
        ],
      ),
    );
    if (selected != null) await ref.read(dbProvider).setValue(key, selected);
  }

  Future<void> _openComments() async {
    try {
      final info = await ref.read(watchInfoProvider(widget.item.id).future);
      if (!mounted) return;
      await showAppSheet<void>(
        context,
        title: 'Comments',
        showClose: false,
        builder: (sheetContext, scrollController) {
          final token = info.commentsToken;
          if (token == null) {
            return const Center(child: Text('Comments unavailable'));
          }
          return Consumer(
            builder: (context, ref, _) => ref
                .watch(watchCommentsProvider(token))
                .when(
                  data: (page) => ListView.builder(
                    controller: scrollController,
                    itemCount: page.items.length,
                    itemBuilder: (context, index) {
                      final comment = page.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChannelAvatar(
                              name: comment.author,
                              url: comment.avatar,
                              size: AppSizes.avatarSm,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${comment.author} · ${comment.age}',
                                    style: AppTextStyles.meta.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(comment.content),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Center(child: Text('Could not load comments')),
                ),
          );
        },
      );
    } catch (_) {
      if (mounted) AppSnackbar.show(context, 'Could not load comments');
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
    final frameReady =
        firstFrame &&
        state != null &&
        service?.isFrameReadyFor(widget.item.id) == true &&
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
                  child: Opacity(
                    opacity: frameReady ? 1 : 0,
                    child: Video(
                      controller: service.controller,
                      controls: NoVideoControls,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
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
          ),
        Positioned(
          top: safe.top,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: Row(
              children: [
                IconButton(
                  tooltip: context.canPop() ? 'Close' : 'Back',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
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
                  onPressed: () => unawaited(
                    showVideoOptionsMenu(
                      context,
                      videoId: widget.item.id,
                      onVideo: true,
                    ),
                  ),
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
        Positioned(
          right: AppSpacing.sm,
          bottom: bottom + AppSpacing.xxxl,
          child: Opacity(
            opacity: _scrubbing ? 0.35 : 1,
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
                  _ShortAction(
                    icon: widget.reaction.value == -1
                        ? Icons.thumb_down
                        : LucideIcons.thumbsDown,
                    label: 'Dislike',
                    onTap: () => _toggleReaction(-1),
                  ),
                  _ShortAction(
                    icon: LucideIcons.messageCircle,
                    label: 'Comments',
                    onTap: () => unawaited(_openComments()),
                  ),
                  _ShortAction(
                    icon: LucideIcons.share2,
                    label: 'Share',
                    onTap: () => unawaited(
                      SharePlus.instance.share(
                        ShareParams(
                          uri: Uri.https(
                            'www.youtube.com',
                            '/shorts/${widget.item.id}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  _ShortAction(
                    icon: LucideIcons.ellipsis,
                    label: 'More',
                    onTap: () {
                      final session = _settingsSession;
                      if (session != null) {
                        unawaited(
                          showPlayerSettingsMenu(context, session: session),
                        );
                      } else {
                        unawaited(
                          showVideoOptionsMenu(
                            context,
                            videoId: widget.item.id,
                            onVideo: true,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.shortsRailWidth + AppSpacing.lg,
          bottom: bottom + AppSpacing.xxl,
          child: Opacity(
            opacity: _scrubbing ? 0.35 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null && name.isNotEmpty)
                  Row(
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
                            icon: isSubscribed ? LucideIcons.bell : null,
                            trailingIcon: isSubscribed
                                ? LucideIcons.chevronDown
                                : null,
                            isLoading: _subscriptionLoading,
                            onPressed: () => unawaited(
                              _onSubscribePressed(
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
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: currentPlayed,
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
          const Center(
            child: CircularProgressIndicator(color: AppColors.shortsForeground),
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

class _ShortAction extends StatefulWidget {
  const _ShortAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
            _controller.forward(from: 0);
            widget.onTap();
          },
          iconSize: AppSpacing.shortsRailIcon,
          color: AppColors.shortsForeground,
          icon: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale:
                  1 +
                  AppSpacing.shortsFeedbackScale *
                      (1 - (_controller.value * 2 - 1).abs()),
              child: child,
            ),
            child: Icon(widget.icon),
          ),
        ),
        Text(
          widget.label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.shortsForeground),
        ),
        const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
      ],
    ),
  );
}
