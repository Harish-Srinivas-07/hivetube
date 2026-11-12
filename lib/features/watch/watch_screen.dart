import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/playback/playback_service.dart';
import '../../core/playback/player_interactions.dart';
import '../../core/playback/player_ui_state.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/streams/stream_selector.dart';
import '../../core/yt/models.dart';
import '../../core/yt/watch_info.dart';
import '../../core/yt/yt_comments.dart';
import '../../core/yt/ryd.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common.dart';
import '../../widgets/player/player_controls.dart';
import '../../widgets/video_options_menu.dart';
import 'watch_panel.dart';
import 'watch_rules.dart';
import '../home/home_variety.dart';
import '../playlist/save_to_playlist_sheet.dart';
import '../../core/db/app_db.dart';

final watchInfoProvider = FutureProvider.family<WatchInfo, String>((
  ref,
  id,
) async {
  ref.watch(contentPrefsProvider.select((prefs) => prefs.prefsVersion));
  return (await ref.watch(ytApiProvider.future)).next.watch(id);
});
final watchCommentsProvider = FutureProvider.family<CommentPage, String>(
  (ref, token) async =>
      (await ref.watch(ytApiProvider.future)).comments.page(token),
);

final dislikeCountProvider = FutureProvider.family<int?, String>((
  ref,
  id,
) async {
  final api = await ref.watch(innertubeProvider.future);
  return RydService(api.dio, ref.watch(dbProvider)).dislikes(id);
});

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
    super.key,
    required this.id,
    this.videoOverride,
    this.placeholderVideo = false,
    this.embedded = false,
    this.onMinimize,
  });
  final String id;
  final Widget? videoOverride;
  final bool placeholderVideo;
  final bool embedded;
  final VoidCallback? onMinimize;
  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  late String id;
  String? started;
  PlaybackService? _activeService;
  String? panel;
  bool subscribed = false;
  int reaction = 0;
  final previous = <String>[];
  final finished = <String>{};
  final reactions = <String, int>{};
  final queue = <VideoItem>[];
  final extra = <VideoItem>[];
  String? continuation;
  bool paging = false;
  String relatedFilter = 'All';
  List<VideoItem>? filtered;
  String? filteredContinuation;
  final scroll = ScrollController();
  Timer? countdown;
  String? countdownFor;
  String? cancelledFor;
  int seconds = 5;

  @override
  void didUpdateWidget(WatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != id) {
      countdown?.cancel();
      countdownFor = null;
      setState(() {
        id = widget.id;
        started = null;
        panel = null;
        extra.clear();
        continuation = null;
        reaction = reactions[widget.id] ?? 0;
        filtered = null;
        filteredContinuation = null;
        relatedFilter = 'All';
      });
      if (scroll.hasClients) {
        scroll.jumpTo(0);
      }
      if (!widget.embedded) {
        unawaited(_start(ref.read(playbackProvider)));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    id = widget.id;
    scroll.addListener(() {
      if (scroll.position.extentAfter < 400) unawaited(_loadMore());
    });
    if (!widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(watchPanelProvider.notifier).close();
        ref.read(playerUiProvider.notifier).setPanelProgress(0);
        unawaited(_start(ref.read(playbackProvider)));
      });
    }
  }

  Future<void> _start(PlaybackService? service) async {
    if (service == null || started == id) return;
    final current = id;
    started = current;
    _activeService = service;
    final history = await ref.read(historyRepoProvider).recent();
    if (!mounted || current != id) return;
    finished.addAll(
      history
          .where(
            (h) =>
                h.duration.inMilliseconds > 0 &&
                h.position.inMilliseconds / h.duration.inMilliseconds >= .9,
          )
          .map((h) => h.videoId),
    );
    final saved = history.where((h) => h.videoId == current).firstOrNull;
    await service.setLoop(false);
    await service.play(
      PlayRequest(
        videoId: current,
        mode: PlaybackMode.video,
        startAt: resumePosition(saved),
      ),
    );
  }

  void _open(String next, {bool record = true}) {
    if (id == next) return;
    if (widget.embedded) {
      openWatchPanel(ref, next);
      return;
    }
    if (record) previous.add(id);
    countdown?.cancel();
    countdownFor = null;
    setState(() {
      id = next;
      started = null;
      panel = null;
      extra.clear();
      continuation = null;
      reaction = reactions[next] ?? 0;
      filtered = null;
      filteredContinuation = null;
      relatedFilter = 'All';
    });
    if (scroll.hasClients) {
      scroll.jumpTo(0);
    }
    unawaited(_start(ref.read(playbackProvider)));
  }

  Future<void> _loadMore() async {
    final token = relatedFilter == 'All' ? continuation : filteredContinuation;
    if (paging || token == null) return;
    paging = true;
    try {
      final api = await ref.read(ytApiProvider.future);
      final prefs = ref.read(contentPrefsProvider);
      final page = relatedFilter.startsWith('From ')
          ? await api.browse.channelVideos(
              ref.read(watchInfoProvider(id)).value?.channelId ?? '',
              continuation: token,
            )
          : await api.next.related(id, continuation: token);
      if (!mounted ||
          token !=
              (relatedFilter == 'All' ? continuation : filteredContinuation)) {
        return;
      }
      setState(() {
        final target = relatedFilter == 'All' ? extra : filtered!;
        final seen = target.map((v) => v.id).toSet();
        final ranked = rankHomeItems(
          page.items.where((item) => !item.isShort),
          preferred: prefs.contentLanguages,
          hidden: prefs.hiddenLanguages,
          seen: const {},
          random: Random(id.hashCode ^ prefs.prefsVersion ^ page.items.length),
        );
        target.addAll(ranked.where((item) => seen.add(item.id)));
        if (relatedFilter == 'All') {
          continuation = page.continuation == token ? null : page.continuation;
        } else {
          filteredContinuation = page.continuation == token
              ? null
              : page.continuation;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          if (relatedFilter == 'All') {
            continuation = null;
          } else {
            filteredContinuation = null;
          }
        });
      }
    } finally {
      paging = false;
    }
  }

  Future<void> _back() async {
    final ui = ref.read(playerUiProvider);
    final action = watchBackAction(
      locked: ui.locked,
      fullscreen: ui.isFullscreen,
      panelOpen: panel != null,
    );
    if (action == WatchBackAction.locked) {
      ref.read(playerUiProvider.notifier).setOverlayVisible(true);
      return;
    }
    if (action == WatchBackAction.fullscreen) {
      ref.read(playerUiProvider.notifier).setFullscreen(false);
      await SystemChrome.setPreferredOrientations(const []);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    if (action == WatchBackAction.panel) {
      setState(() => panel = null);
      return;
    }
    if (widget.embedded) {
      widget.onMinimize?.call();
      return;
    }
    if (mounted && context.canPop()) {
      context.pop();
    } else if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    countdown?.cancel();
    scroll.dispose();
    if (!widget.embedded) {
      unawaited(_activeService?.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(contentPrefsProvider);
    final service = ref.watch(playbackProvider);
    ref.listen<PlaybackService?>(playbackProvider, (_, current) {
      if (current != null) unawaited(_start(current));
    });
    final ui = ref.watch(playerUiProvider);
    final infoState = ref.watch(watchInfoProvider(id));
    final info = infoState.value;
    if (info != null && continuation == null && extra.isEmpty) {
      continuation = info.related.continuation;
    }
    if (info != null) {
      ref.read(subscriptionRepoProvider).channelIds().then((ids) {
        if (mounted &&
            id == info.id &&
            subscribed != ids.contains(info.channelId)) {
          setState(() => subscribed = ids.contains(info.channelId));
        }
      });
      ref.read(dbProvider).reactionsDao.getReaction(id).then((val) {
        if (mounted && id == info.id && val != null && reaction != val) {
          setState(() => reaction = val);
        }
      });
    }
    final relatedCandidates = relatedFilter == 'All'
        ? [
            if (info != null) ...info.related.items.where((v) => !v.isShort),
            ...extra,
          ]
        : filtered ?? <VideoItem>[];
    final related = rankHomeItems(
      relatedCandidates,
      preferred: prefs.contentLanguages,
      hidden: prefs.hiddenLanguages,
      seen: const {},
      random: Random(id.hashCode ^ prefs.prefsVersion),
    );
    final next = selectUpNext(
      queue: queue,
      related: related,
      finished: finished,
      currentId: id,
    );
    if (service?.state.status == PlayerStatus.ended &&
        ref.read(contentPrefsProvider).autoplay &&
        next != null &&
        cancelledFor != id &&
        countdownFor != id) {
      countdownFor = id;
      seconds = 5;
      countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => seconds--);
        if (seconds <= 0) {
          timer.cancel();
          if (queue.isNotEmpty && queue.first.id == next.id) queue.removeAt(0);
          _open(next.id);
        }
      });
    }
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width;
    final wide = !ui.isFullscreen && (width >= 900 || width > viewport.height);
    Widget player = widget.placeholderVideo
        ? const SizedBox.expand()
        : ColoredBox(
            color: AppColors.shortsBackground,
            child: service == null
                ? const Center(child: CircularProgressIndicator())
                : SharedPlayer(
                    service: service,
                    videoOverride: widget.videoOverride,
                    chapters: info?.chapters ?? const [],
                    onChapters: () => _showChapters(info?.chapters ?? const []),
                    onMinimize: () => unawaited(_back()),
                    onPrevious: previous.isEmpty
                        ? null
                        : () {
                            final old = previous.removeLast();
                            _open(old, record: false);
                          },
                    onNext: next == null
                        ? null
                        : () {
                            if (queue.isNotEmpty && queue.first.id == next.id) {
                              queue.removeAt(0);
                            }
                            _open(next.id);
                          },
                  ),
          );
    if (!ui.isFullscreen) {
      player = AspectRatio(
        aspectRatio: AppSpacing.thumbnailRatio,
        child: player,
      );
    }
    final details = info == null
        ? Center(
            child: infoState.hasError
                ? TextButton(
                    onPressed: () => ref.invalidate(watchInfoProvider(id)),
                    child: const Text('Unable to load video. Retry'),
                  )
                : const CircularProgressIndicator(),
          )
        : _details(info, related);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape) {
          unawaited(_back());
          return KeyEventResult.handled;
        }
        if (ui.locked || service == null) return KeyEventResult.ignored;
        if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
          unawaited(
            service.state.status == PlayerStatus.playing
                ? service.pause()
                : service.resume(),
          );
        } else if (key == LogicalKeyboardKey.keyJ ||
            key == LogicalKeyboardKey.arrowLeft) {
          final seek = service.state.position - const Duration(seconds: 10);
          unawaited(service.seek(seek < Duration.zero ? Duration.zero : seek));
        } else if (key == LogicalKeyboardKey.keyL ||
            key == LogicalKeyboardKey.arrowRight) {
          final seek = service.state.position + const Duration(seconds: 10);
          unawaited(
            service.seek(
              service.state.duration > Duration.zero &&
                      seek > service.state.duration
                  ? service.state.duration
                  : seek,
            ),
          );
        } else if (key == LogicalKeyboardKey.keyM) {
          unawaited(service.setMuted(!service.state.muted));
        } else if (key == LogicalKeyboardKey.keyC &&
            service.state.captions.isNotEmpty) {
          unawaited(
            service.setCaption(
              service.state.selectedCaption == null ? 0 : null,
            ),
          );
        } else if (key == LogicalKeyboardKey.keyF) {
          final fullscreen = !ui.isFullscreen;
          ref.read(playerUiProvider.notifier).setFullscreen(fullscreen);
          unawaited(
            SystemChrome.setPreferredOrientations(
              fullscreen
                  ? [
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]
                  : const [],
            ),
          );
          unawaited(
            SystemChrome.setEnabledSystemUIMode(
              fullscreen
                  ? SystemUiMode.immersiveSticky
                  : SystemUiMode.edgeToEdge,
            ),
          );
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_back());
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: ui.isFullscreen
                ? AppColors.shortsBackground
                : Theme.of(context).scaffoldBackgroundColor,
            body: ui.isFullscreen
                ? SizedBox.expand(child: player)
                : SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        ColoredBox(
                          color: AppColors.shortsBackground,
                          child: SizedBox(
                            height: MediaQuery.paddingOf(context).top,
                            width: double.infinity,
                          ),
                        ),
                        if (wide)
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: width * .64,
                                  child: Column(
                                    children: [
                                      player,
                                      Expanded(
                                        child: panel == null
                                            ? details
                                            : _details(info!, related),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: panel != null && info != null
                                      ? _panel(info, related)
                                      : _relatedList(related),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          player,
                          if (countdownFor == id && seconds > 0 && next != null)
                            ListTile(
                              title: Text('Up next in $seconds'),
                              subtitle: Text(next.title, maxLines: 1),
                              trailing: Wrap(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      countdown?.cancel();
                                      setState(() {
                                        cancelledFor = id;
                                        countdownFor = null;
                                      });
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => _open(next.id),
                                    child: const Text('Play now'),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: panel != null && info != null
                                ? _panel(info, related)
                                : details,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showChapters(List<WatchChapter> chapters) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'Chapters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final chapter in chapters)
              ListTile(
                title: Text(chapter.title),
                subtitle: Text(
                  '${chapter.start.inMinutes}:${(chapter.start.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                onTap: () {
                  unawaited(ref.read(playbackProvider)?.seek(chapter.start));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _details(WatchInfo info, List<VideoItem> related) => CustomScrollView(
    controller: scroll,
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: AppRadius.smBorder,
                onTap: () => setState(() => panel = 'Description'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: [
                              info.handle,
                              _compactMetric(info.views),
                              info.date,
                            ].where((value) => value.isNotEmpty).join(' · '),
                          ),
                          TextSpan(
                            text: '  more',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  InkWell(
                    borderRadius: AppRadius.pillBorder,
                    onTap: info.channelId.isNotEmpty
                        ? () => context.push('/channel/${info.channelId}')
                        : null,
                    child: Avatar(name: info.channelName, url: info.avatar),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: info.channelId.isNotEmpty
                          ? () => context.push('/channel/${info.channelId}')
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (info.subscribers.isNotEmpty)
                            Text(
                              info.subscribers,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: info.channelId.isEmpty
                        ? null
                        : () async {
                            final value = !subscribed;
                            await ref
                                .read(subscriptionRepoProvider)
                                .setSubscribed(info.channelId, value);
                            if (mounted) setState(() => subscribed = value);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: subscribed
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : Theme.of(context).colorScheme.onSurface,
                      foregroundColor: subscribed
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      minimumSize: const Size(0, AppSpacing.topButton),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(subscribed ? 'Subscribed' : 'Subscribe'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _reactionGroup(info),
                    _action(
                      LucideIcons.share,
                      'Share',
                      () => unawaited(
                        SharePlus.instance.share(
                          ShareParams(
                            uri: Uri.parse(
                              'https://www.youtube.com/watch?v=$id',
                            ),
                          ),
                        ),
                      ),
                    ),
                    _action(LucideIcons.download, 'Download', _soon),
                    _action(
                      LucideIcons.bookmark,
                      'Save',
                      () => showSaveToPlaylistSheet(
                        context,
                        videoId: id,
                        media: MediaCompanion.insert(
                          videoId: id,
                          title: info.title,
                          channelId: info.channelId,
                          channelName: info.channelName,
                          thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                          updatedAt: DateTime.now().millisecondsSinceEpoch,
                        ),
                      ),
                    ),
                    _action(
                      LucideIcons.clock,
                      'Watch later',
                      () async {
                        final db = ref.read(dbProvider);
                        final wl = await db.playlistsDao.getOrCreateWatchLater();
                        final inWl = await db.playlistsDao.isInPlaylist(wl.id, id);
                        if (inWl) {
                          await db.playlistsDao.removePlaylistItem(wl.id, id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Removed from Watch Later')),
                            );
                          }
                        } else {
                          await db.playlistsDao.addPlaylistItem(
                            wl.id,
                            id,
                            mediaItem: MediaCompanion.insert(
                              videoId: id,
                              title: info.title,
                              channelId: info.channelId,
                              channelName: info.channelName,
                              thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                              updatedAt: DateTime.now().millisecondsSinceEpoch,
                            ),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Saved to Watch Later')),
                            );
                          }
                        }
                      },
                    ),
                    _action(
                      LucideIcons.listVideo,
                      'Queue',
                      () => setState(() => panel = 'Queue'),
                    ),
                  ],
                ),
              ),
              if (info.commentsToken != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Consumer(
                  builder: (context, ref, _) {
                    final comments = ref
                        .watch(watchCommentsProvider(info.commentsToken!))
                        .value;
                    final preview = comments?.items.firstOrNull;
                    final count =
                        comments?.count.replaceAll(
                          RegExp(r'\s*[Cc]omments.*$'),
                          '',
                        ) ??
                        '';
                    return Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.lgBorder,
                      child: InkWell(
                        borderRadius: AppRadius.lgBorder,
                        onTap: () => setState(() => panel = 'Comments'),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Comments',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (count.isNotEmpty) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      _compactNumber(count),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    size: AppSizes.iconSm,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                              if (preview != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Avatar(
                                      name: preview.author,
                                      url: preview.avatar,
                                      size: AppSpacing.logoMark,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        preview.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(height: 1.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final label in [
                'All',
                if (info.channelName.isNotEmpty) 'From ${info.channelName}',
                ...info.chips.keys,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: ActionChip(
                    label: Text(label),
                    onPressed: () => _selectRelated(info, label),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: related.length,
        itemBuilder: (context, index) => _video(related[index]),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
        ),
      ),
    ],
  );
  Future<void> _selectRelated(WatchInfo info, String label) async {
    setState(() {
      relatedFilter = label;
      filtered = label == 'All' ? null : [];
      filteredContinuation = null;
    });
    if (label == 'All') return;
    try {
      final api = await ref.read(ytApiProvider.future);
      final prefs = ref.read(contentPrefsProvider);
      final page = label.startsWith('From ')
          ? await api.browse.channelVideos(info.channelId)
          : await api.next.related(info.id, continuation: info.chips[label]);
      if (!mounted || relatedFilter != label) return;
      setState(() {
        filtered = rankHomeItems(
          page.items.where((item) => !item.isShort),
          preferred: prefs.contentLanguages,
          hidden: prefs.hiddenLanguages,
          seen: const {},
          random: Random(id.hashCode ^ prefs.prefsVersion ^ page.items.length),
        );
        filteredContinuation = page.continuation;
      });
    } catch (_) {
      if (mounted) _soon();
    }
  }

  String _compactNumber(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d[\d,]*$').hasMatch(trimmed)) return trimmed;
    final number = int.tryParse(trimmed.replaceAll(',', ''));
    if (number == null || number < 1000) return trimmed;
    final divisor = number >= 1000000 ? 1000000 : 1000;
    final suffix = divisor == 1000000 ? 'M' : 'K';
    final scaled = number / divisor;
    return '${scaled >= 10 || scaled == scaled.roundToDouble() ? scaled.toStringAsFixed(0) : scaled.toStringAsFixed(1)}$suffix';
  }

  String _compactMetric(String value) {
    final match = RegExp(
      r'^(\d[\d,]*)\s+(views|likes)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match == null
        ? value
        : '${_compactNumber(match.group(1)!)} ${match.group(2)}';
  }

  Widget _reactionGroup(WatchInfo info) {
    final colors = Theme.of(context).colorScheme;
    final dislikes = ref.watch(dislikeCountProvider(id)).value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.xxxl)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppSpacing.xxxl),
              ),
              onTap: () async {
                final next = reaction == 1 ? null : 1;
                setState(() {
                  reaction = next ?? 0;
                  reactions[id] = reaction;
                });
                final db = ref.read(dbProvider);
                await db.reactionsDao.setReaction(id, next);
                if (next != null) {
                  await db.into(db.media).insertOnConflictUpdate(
                    MediaCompanion.insert(
                      videoId: id,
                      title: info.title,
                      channelId: info.channelId,
                      channelName: info.channelName,
                      thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.thumbsUp,
                      size: AppSizes.iconMd,
                      color: reaction == 1 ? colors.primary : colors.onSurface,
                    ),
                    if (info.likes.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        info.likes,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: colors.outline.withValues(alpha: 0.35),
            ),
            InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(AppSpacing.xxxl),
              ),
              onTap: () async {
                final next = reaction == -1 ? null : -1;
                setState(() {
                  reaction = next ?? 0;
                  reactions[id] = reaction;
                });
                final db = ref.read(dbProvider);
                await db.reactionsDao.setReaction(id, next);
              },
              child: Tooltip(
                message: 'Dislikes provided by returnyoutubedislike.com',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.thumbsDown,
                        size: AppSizes.iconMd,
                        color: reaction == -1 ? colors.primary : colors.onSurface,
                      ),
                      if (dislikes != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _compactNumber('$dislikes'),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback action) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.pillBorder,
        child: InkWell(
          borderRadius: AppRadius.pillBorder,
          onTap: action,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppSizes.iconSm, color: scheme.onSurface),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _soon() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  Widget _relatedList(List<VideoItem> related) => ListView.builder(
    itemCount: related.length,
    itemBuilder: (context, i) => _video(related[i], compact: true),
  );
  Widget _video(VideoItem item, {bool compact = false}) => InkWell(
    onTap: () => _open(item.id),
    child: compact
        ? ListTile(
            leading: ClipRRect(
              borderRadius: AppRadius.smBorder,
              child: SizedBox(
                width: 130,
                child: AspectRatio(
                  aspectRatio: AppSpacing.thumbnailRatio,
                  child: CachedNetworkImage(
                    imageUrl: item.thumbUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(color: AppColors.shortsBackground),
                  ),
                ),
              ),
            ),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              [item.channelName, item.viewsText].where((s) => s.isNotEmpty).join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: _menu(item),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ClipRRect(
                  borderRadius: AppRadius.mdBorder,
                  child: AspectRatio(
                    aspectRatio: AppSpacing.thumbnailRatio,
                    child: CachedNetworkImage(
                      imageUrl: item.thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const ColoredBox(color: AppColors.shortsBackground),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Avatar(
                  name: item.channelName,
                  url: item.channelAvatarUrl,
                ),
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  [
                    item.channelName,
                    item.viewsText,
                    item.publishedText,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: _menu(item),
              ),
            ],
          ),
  );
  Widget _menu(VideoItem item) => IconButton(
    tooltip: 'More options',
    icon: const Icon(LucideIcons.ellipsisVertical),
    onPressed: () => showVideoOptionsMenu(
      context,
      videoId: item.id,
      onPlayNext: () => setState(() => queue.insert(0, item)),
      onAddToQueue: () => setState(() => queue.add(item)),
    ),
  );
  Widget _panel(WatchInfo info, List<VideoItem> related) => Column(
    children: [
      GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 200) setState(() => panel = null);
        },
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: AppSpacing.contentSheetHandleWidth,
              height: AppSpacing.contentSheetHandleHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            ListTile(
              title: Text(
                panel!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (panel == 'Comments')
                    IconButton(
                      tooltip: 'Comment guidelines',
                      icon: const Icon(LucideIcons.info),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Comments'),
                          content: const Text(
                            'Remember to keep comments respectful by following the YouTube Community Guidelines.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => setState(() => panel = null),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: switch (panel) {
          'Description' => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(info.title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                [
                  info.views,
                  info.likes,
                  info.date,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              const SizedBox(height: AppSpacing.lg),
              _LinkedDescription(
                text: info.description,
                onSeek: (position) =>
                    ref.read(playbackProvider)?.seek(position),
              ),
              for (final c in info.chapters)
                ListTile(
                  title: Text(c.title),
                  subtitle: Text(
                    '${c.start.inMinutes}:${(c.start.inSeconds % 60).toString().padLeft(2, '0')}',
                  ),
                  onTap: () => ref.read(playbackProvider)?.seek(c.start),
                ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.returnyoutubedislike.com/'),
                ),
                child: const Text('Dislike data: Return YouTube Dislike'),
              ),
            ],
          ),
          'Queue' => ListView(
            children: [
              ListTile(
                title: const Text('Now playing'),
                subtitle: Text(info.title),
              ),
              for (final item in queue)
                ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.channelName),
                  onTap: () {
                    queue.remove(item);
                    _open(item.id);
                  },
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => setState(() => queue.remove(item)),
                  ),
                ),
            ],
          ),
          'Comments' =>
            info.commentsToken == null
                ? const Center(child: Text('Comments unavailable'))
                : _Comments(token: info.commentsToken!),
          _ => const SizedBox.shrink(),
        },
      ),
    ],
  );
}

class _LinkedDescription extends StatefulWidget {
  const _LinkedDescription({required this.text, required this.onSeek});
  final String text;
  final ValueChanged<Duration> onSeek;
  @override
  State<_LinkedDescription> createState() => _LinkedDescriptionState();
}

class _LinkedDescriptionState extends State<_LinkedDescription> {
  final recognizers = <TapGestureRecognizer>[];
  @override
  void dispose() {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    recognizers.clear();
    final children = <InlineSpan>[];
    final pattern = RegExp(r'https?://[^\s]+|\b(?:\d{1,2}:)?\d{1,2}:\d{2}\b');
    var cursor = 0;
    for (final match in pattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        children.add(
          TextSpan(text: widget.text.substring(cursor, match.start)),
        );
      }
      final value = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (value.startsWith('http')) {
            unawaited(launchUrl(Uri.parse(value)));
          } else {
            final parts = value.split(':').map(int.parse).toList();
            final seconds = parts.reversed.indexed.fold<int>(
              0,
              (sum, entry) =>
                  sum +
                  entry.$2 *
                      (entry.$1 == 0
                          ? 1
                          : entry.$1 == 1
                          ? 60
                          : 3600),
            );
            widget.onSeek(Duration(seconds: seconds));
          }
        };
      recognizers.add(recognizer);
      children.add(
        TextSpan(
          text: value,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      children.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(TextSpan(children: children));
  }
}

class _Comments extends ConsumerStatefulWidget {
  const _Comments({required this.token});
  final String token;
  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  CommentPage? page;
  final items = <WatchComment>[];
  final replies = <String, List<WatchComment>>{};
  final replyCursors = <String, String?>{};
  final expanded = <String>{};
  final controller = ScrollController();
  bool loading = false;
  String selected = 'Top';
  Object? error;
  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.position.extentAfter < 300) unawaited(_more());
    });
    unawaited(_fetch(widget.token, replace: true));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _fetch(String token, {bool replace = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await (await ref.read(
        ytApiProvider.future,
      )).comments.page(token);
      if (!mounted) return;
      setState(() {
        if (replace) items.clear();
        final seen = items.map((c) => c.id).toSet();
        items.addAll(result.items.where((c) => seen.add(c.id)));
        page = CommentPage(
          items,
          result.count.isEmpty ? page?.count ?? '' : result.count,
          result.continuation,
          result.sorts.isEmpty ? page?.sorts ?? {} : result.sorts,
        );
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _more() async {
    final next = page?.continuation;
    if (next != null && !loading) await _fetch(next);
  }

  Future<void> _reply(WatchComment comment) async {
    if (expanded.contains(comment.id)) {
      setState(() => expanded.remove(comment.id));
      return;
    }
    final token = comment.replyToken;
    if (token == null) return;
    if (!replies.containsKey(comment.id)) {
      try {
        final result = await (await ref.read(
          ytApiProvider.future,
        )).comments.page(token);
        if (!mounted) return;
        replies[comment.id] = result.items;
        replyCursors[comment.id] = result.continuation;
      } catch (_) {
        return;
      }
    }
    if (mounted) setState(() => expanded.add(comment.id));
  }

  Future<void> _moreReplies(WatchComment comment) async {
    final token = replyCursors[comment.id];
    if (token == null) return;
    try {
      final result = await (await ref.read(
        ytApiProvider.future,
      )).comments.page(token);
      if (!mounted) return;
      setState(() {
        final target = replies[comment.id]!;
        final ids = target.map((r) => r.id).toSet();
        target.addAll(result.items.where((r) => ids.add(r.id)));
        replyCursors[comment.id] = result.continuation == token
            ? null
            : result.continuation;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final current = page;
    if (current == null) {
      return Center(
        child: error != null
            ? TextButton(
                onPressed: () => _fetch(widget.token, replace: true),
                child: const Text('Comments unavailable. Retry'),
              )
            : const CircularProgressIndicator(),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            for (final value in ['Top', 'Newest'])
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) {
                    final token = current.sorts.entries
                        .where(
                          (entry) => value == 'Top'
                              ? entry.key.toLowerCase().contains('top')
                              : entry.key.toLowerCase().contains('new'),
                        )
                        .firstOrNull
                        ?.value;
                    if (token != null) {
                      setState(() => selected = value);
                      unawaited(_fetch(token, replace: true));
                    }
                  },
                ),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Remember to keep comments respectful by following the YouTube Community Guidelines.',
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: controller,
            itemCount: items.length + (loading ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final c = items[i];
              return Column(
                children: [
                  ListTile(
                    leading: Avatar(name: c.author, url: c.avatar),
                    title: Text(
                      '${c.pinned.isNotEmpty ? '${c.pinned}\n' : ''}${c.author} ${c.verified ? '✓' : ''} · ${c.age}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.content,
                          maxLines: expanded.contains('text:${c.id}')
                              ? null
                              : 4,
                          overflow: expanded.contains('text:${c.id}')
                              ? null
                              : TextOverflow.ellipsis,
                        ),
                        if (c.content.length > 160)
                          TextButton(
                            onPressed: () => setState(() {
                              final key = 'text:${c.id}';
                              if (!expanded.add(key)) expanded.remove(key);
                            }),
                            child: const Text('Read more'),
                          ),
                        Text('♡ ${c.likes}'),
                        if (c.replyToken != null)
                          TextButton(
                            onPressed: () => _reply(c),
                            child: Text('${c.replies} replies'),
                          ),
                      ],
                    ),
                  ),
                  if (expanded.contains(c.id))
                    for (final r in replies[c.id] ?? <WatchComment>[])
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xxxl),
                        child: ListTile(
                          leading: Avatar(name: r.author, url: r.avatar),
                          title: Text('${r.author} · ${r.age}'),
                          subtitle: Text(r.content),
                        ),
                      ),
                  if (expanded.contains(c.id) && replyCursors[c.id] != null)
                    TextButton(
                      onPressed: () => _moreReplies(c),
                      child: const Text('More replies'),
                    ),
                ],
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            enabled: false,
            decoration: InputDecoration(hintText: "Sign-in isn't supported"),
          ),
        ),
      ],
    );
  }
}
