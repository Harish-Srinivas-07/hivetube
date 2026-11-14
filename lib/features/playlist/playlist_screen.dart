import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../features/watch/mini_player_inset.dart';
import '../../features/watch/watch_panel.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/common.dart';
import '../../widgets/sheets/app_sheet.dart';
import '../../widgets/ui/app_controls.dart';
import 'save_to_playlist_sheet.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  final ScrollController _scrollController = ScrollController();
  PlaylistPageData? _data;
  bool _loading = true;
  String? _error;
  bool _loadingMore = false;
  final List<VideoItem> _videos = [];
  final Set<String> _unavailableIds = {};
  String? _continuation;
  bool _isLocal = false;
  int? _localPlaylistId;
  int? _updatedAt;

  bool get _isLiked => widget.playlistId == 'liked';
  bool get _isWatchLater => widget.playlistId == 'watch_later';
  bool get _canManage => _localPlaylistId != null && !_isWatchLater;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < AppSpacing.xxxl &&
        !_isLocal) {
      unawaited(_loadMore());
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_data == null && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }

    final parsedId = int.tryParse(widget.playlistId);
    try {
      if (_isLiked) {
        final db = ref.read(dbProvider);
        final likedRows = await db.reactionsDao.getLikedVideos();
        final latestLike = await db.reactionsDao.getLatestLikedAt();
        final items = likedRows.map(_videoFromMedia).toList();
        _setPlaylistData(
          PlaylistPageData(
            id: 'liked',
            title: 'Liked videos',
            videoCountText: '${items.length} videos',
            thumbUrl: items.isNotEmpty ? items.first.thumbUrl : '',
            videos: items,
          ),
          isLocal: true,
          localPlaylistId: null,
          updatedAt: latestLike,
          unavailableIds: {
            for (var index = 0; index < likedRows.length; index++)
              if (likedRows[index].title == likedRows[index].videoId)
                likedRows[index].videoId,
          },
        );
        return;
      }

      if (_isWatchLater || parsedId != null) {
        final db = ref.read(dbProvider);
        final playlist = _isWatchLater
            ? await db.playlistsDao.getOrCreateWatchLater()
            : await db.playlistsDao.getPlaylist(parsedId!);
        if (playlist == null) throw StateError('Playlist not found');
        final itemsWithMedia = await db.playlistsDao.getPlaylistItems(
          playlist.id,
        );
        final items = itemsWithMedia.map((entry) {
          final media = entry.media;
          final duration = media?.durationSec;
          return VideoItem(
            id: entry.item.videoId,
            title: media?.title ?? entry.item.videoId,
            channelId: media?.channelId ?? '',
            channelName: media?.channelName ?? '',
            thumbUrl: media?.thumbUrl ?? '',
            durationText: duration == null ? '' : _formatDuration(duration),
          );
        }).toList();
        _setPlaylistData(
          PlaylistPageData(
            id: widget.playlistId,
            title: playlist.name,
            videoCountText: '${items.length} videos',
            thumbUrl: items.isNotEmpty ? items.first.thumbUrl : '',
            videos: items,
          ),
          isLocal: true,
          localPlaylistId: playlist.id,
          updatedAt: playlist.updatedAt,
          unavailableIds: {
            for (final entry in itemsWithMedia)
              if (entry.media == null ||
                  entry.media!.title == entry.item.videoId)
                entry.item.videoId,
          },
        );
        return;
      }

      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.playlistPage(widget.playlistId);
      _setPlaylistData(
        page,
        isLocal: false,
        localPlaylistId: null,
        updatedAt: null,
        unavailableIds: {
          for (final video in page.videos)
            if (_isUnavailable(video)) video.id,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('[Playlist] load failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _setPlaylistData(
    PlaylistPageData page, {
    required bool isLocal,
    required int? localPlaylistId,
    required int? updatedAt,
    required Set<String> unavailableIds,
  }) {
    if (!mounted) return;
    setState(() {
      _data = page;
      _isLocal = isLocal;
      _localPlaylistId = localPlaylistId;
      _updatedAt = updatedAt;
      _continuation = page.continuation;
      _videos
        ..clear()
        ..addAll(page.videos);
      _unavailableIds
        ..clear()
        ..addAll(unavailableIds);
      _loading = false;
      _error = null;
    });
  }

  VideoItem _videoFromMedia(MediaRow media) => VideoItem(
    id: media.videoId,
    title: media.title,
    channelId: media.channelId,
    channelName: media.channelName,
    thumbUrl: media.thumbUrl,
    durationText: media.durationSec == null
        ? ''
        : _formatDuration(media.durationSec!),
  );

  String _formatDuration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  bool _isUnavailable(VideoItem video) =>
      video.title.trim().isEmpty ||
      video.title == video.id ||
      video.title.toLowerCase().contains('unavailable');

  Future<void> _loadMore() async {
    final token = _continuation;
    if (token == null || _loadingMore || _data == null || _isLocal) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.playlistPage(
        widget.playlistId,
        continuation: token,
      );
      if (!mounted) return;
      setState(() {
        _continuation = page.continuation;
        _videos.addAll(page.videos);
        _unavailableIds.addAll(
          page.videos.where(_isUnavailable).map((video) => video.id),
        );
        _loadingMore = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[Playlist] load more failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loadingMore = false;
        });
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_videos.isEmpty) return;
    final list = List<VideoItem>.from(_videos);
    if (shuffle) list.shuffle();
    openWatchPanel(ref, list.first.id);
  }

  Future<void> _removeItem(int index) async {
    final item = _videos[index];
    final db = ref.read(dbProvider);
    if (_localPlaylistId != null) {
      await db.playlistsDao.removePlaylistItem(_localPlaylistId!, item.id);
    } else if (_isLiked) {
      await db.reactionsDao.setReaction(item.id, null);
    }
    if (!mounted) return;
    setState(() {
      _videos.removeAt(index);
      _unavailableIds.remove(item.id);
      _data = _copyData(videos: _videos);
    });
  }

  PlaylistPageData _copyData({required List<VideoItem> videos}) {
    final page = _data!;
    return PlaylistPageData(
      id: page.id,
      title: page.title,
      author: page.author,
      authorId: page.authorId,
      thumbUrl: videos.isNotEmpty ? videos.first.thumbUrl : '',
      videoCountText: '${videos.length} videos',
      description: page.description,
      videos: List.unmodifiable(videos),
      continuation: page.continuation,
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final item = _videos.removeAt(oldIndex);
    _videos.insert(newIndex, item);
    setState(() => _data = _copyData(videos: _videos));
    final playlistId = _localPlaylistId;
    if (playlistId != null) {
      await ref
          .read(dbProvider)
          .playlistsDao
          .reorderPlaylistItems(playlistId, oldIndex, newIndex);
    }
  }

  Future<void> _moveToTop(VideoItem item) async {
    final playlistId = _localPlaylistId;
    final index = _videos.indexOf(item);
    if (playlistId == null || index < 1) return;
    await _onReorder(index, 0);
  }

  MediaCompanion _mediaCompanion(VideoItem video) => MediaCompanion.insert(
    videoId: video.id,
    title: video.title,
    channelId: video.channelId,
    channelName: video.channelName,
    durationSec: Value(_durationSeconds(video.durationText)),
    thumbUrl: video.thumbUrl,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );

  int? _durationSeconds(String duration) {
    final parts = duration.split(':');
    if (parts.length != 2) return null;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  Future<void> _showVideoMenu(VideoItem video) async {
    final action = await showAppSheet<String>(
      context,
      fit: true,
      builder: (sheetContext, _) => ListView(
        shrinkWrap: true,
        children: [
          if (_isLocal)
            AppSheetRow(
              icon: LucideIcons.listMinus,
              label: _isLiked
                  ? 'Remove from Liked videos'
                  : 'Remove from playlist',
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
          if (_localPlaylistId != null)
            AppSheetRow(
              icon: LucideIcons.arrowUpToLine,
              label: 'Move to top',
              onTap: () => Navigator.of(sheetContext).pop('top'),
            ),
          AppSheetRow(
            icon: LucideIcons.listPlus,
            label: 'Save to other playlist',
            onTap: () => Navigator.of(sheetContext).pop('save'),
          ),
          AppSheetRow(
            icon: LucideIcons.share,
            label: 'Share',
            onTap: () => Navigator.of(sheetContext).pop('share'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'remove':
        await _removeItem(_videos.indexOf(video));
        break;
      case 'top':
        await _moveToTop(video);
        break;
      case 'save':
        await showSaveToPlaylistSheet(
          context,
          videoId: video.id,
          media: _mediaCompanion(video),
        );
        break;
      case 'share':
        await _shareVideo(video);
        break;
    }
  }

  Future<void> _shareVideo(VideoItem video) async {
    await SharePlus.instance.share(
      ShareParams(uri: Uri.https('www.youtube.com', '/watch', {'v': video.id})),
    );
  }

  Future<void> _sharePlaylist() async {
    final title = _data?.title ?? 'Playlist';
    if (!_isLocal) {
      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.https('www.youtube.com', '/playlist', {
            'list': widget.playlistId,
          }),
        ),
      );
      return;
    }
    final links = _videos.map(
      (video) => Uri.https('www.youtube.com', '/watch', {'v': video.id}),
    );
    await SharePlus.instance.share(
      ShareParams(text: '$title\n${links.join('\n')}'),
    );
  }

  Future<void> _showPlaylistMenu() async {
    final action = await showAppSheet<String>(
      context,
      fit: true,
      builder: (sheetContext, _) => ListView(
        shrinkWrap: true,
        children: [
          AppSheetRow(
            icon: LucideIcons.pencil,
            label: 'Rename',
            onTap: () => Navigator.of(sheetContext).pop('rename'),
          ),
          AppSheetRow(
            icon: LucideIcons.trash2,
            label: 'Delete',
            onTap: () => Navigator.of(sheetContext).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'rename') await _renamePlaylist();
    if (action == 'delete') await _confirmDeletePlaylist();
  }

  Future<void> _renamePlaylist() async {
    final playlistId = _localPlaylistId;
    if (playlistId == null || _data == null) return;
    final controller = TextEditingController(text: _data!.title);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Rename playlist',
        content: ClipRRect(
          borderRadius: AppRadius.mdBorder,
          child: ColoredBox(
            color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Playlist name',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ),
        ),
        actions: [
          AppButton.text(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton.text(
            label: 'Save',
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await ref.read(dbProvider).playlistsDao.renamePlaylist(playlistId, name);
    if (!mounted) return;
    setState(() {
      _data = PlaylistPageData(
        id: _data!.id,
        title: name,
        author: _data!.author,
        authorId: _data!.authorId,
        thumbUrl: _data!.thumbUrl,
        videoCountText: _data!.videoCountText,
        description: _data!.description,
        videos: _data!.videos,
        continuation: _data!.continuation,
      );
    });
  }

  Future<void> _confirmDeletePlaylist() async {
    final playlistId = _localPlaylistId;
    if (playlistId == null || !_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Delete playlist?',
        content: const Text(
          'This playlist and its saved order will be deleted.',
        ),
        actions: [
          AppButton.text(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.text(
            label: 'Delete',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(dbProvider).playlistsDao.deletePlaylist(playlistId);
    if (mounted) context.pop();
  }

  String _relativeUpdated() {
    final updatedAt = _updatedAt;
    if (updatedAt == null) return 'Updated recently';
    final delta = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
    if (delta.inMinutes < 1) return 'Updated just now';
    if (delta.inHours < 1) return 'Updated ${delta.inMinutes}m ago';
    if (delta.inDays < 1) return 'Updated ${delta.inHours}h ago';
    if (delta.inDays < 30) return 'Updated ${delta.inDays}d ago';
    return 'Updated ${delta.inDays ~/ 30}mo ago';
  }

  Widget _buildHeader(PlaylistPageData page) {
    final theme = Theme.of(context);
    final cover = page.thumbUrl.isNotEmpty
        ? page.thumbUrl
        : _videos.isNotEmpty
        ? _videos.first.thumbUrl
        : '';
    final count = page.videoCountText.isNotEmpty
        ? page.videoCountText
        : '${_videos.length} videos';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ClipRRect(
            borderRadius: AppRadius.mdBorder,
            child: AspectRatio(
              aspectRatio: AppSpacing.thumbnailRatio,
              child: cover.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(
                          LucideIcons.listMusic,
                          size: AppSizes.iconLg + AppSizes.icon,
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (constraints.maxWidth *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil(),
                        maxWidthDiskCache:
                            (constraints.maxWidth *
                                    MediaQuery.devicePixelRatioOf(context))
                                .ceil(),
                        placeholder: (_, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(
                              LucideIcons.listMusic,
                              size: AppSizes.iconLg + AppSizes.icon,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _canManage ? _renamePlaylist : null,
                child: Text(
                  page.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.pageTitle,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$count · ${_relativeUpdated()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() => Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.md,
      top: AppSpacing.md,
      right: AppSpacing.md,
      bottom: AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: AppButton.filled(
            label: 'Play all',
            icon: LucideIcons.play,
            onPressed: _videos.isEmpty ? null : _playAll,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppButton.tonal(
            label: 'Shuffle',
            icon: LucideIcons.shuffle,
            onPressed: _videos.isEmpty ? null : () => _playAll(shuffle: true),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: 'Share playlist',
          icon: const Icon(LucideIcons.share),
          onPressed: _sharePlaylist,
          constraints: const BoxConstraints.tightFor(
            width: AppSizes.buttonIconTouch,
            height: AppSizes.buttonIconTouch,
          ),
        ),
      ],
    ),
  );

  Widget _buildVideoRow(VideoItem video, int index) {
    final unavailable = _unavailableIds.contains(video.id);
    final displayVideo = unavailable
        ? VideoItem(id: video.id, title: 'Unavailable video', thumbUrl: '')
        : video;
    final canShowMenu = !unavailable;
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canShowMenu)
          SizedBox.square(
            dimension: AppSizes.buttonIcon,
            child: IconButton(
              tooltip: 'More options',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(
                width: AppSizes.buttonIcon,
                height: AppSizes.buttonIcon,
              ),
              icon: const Icon(LucideIcons.ellipsis, size: AppSizes.iconSm),
              onPressed: () => _showVideoMenu(video),
            ),
          ),
        if (_localPlaylistId != null && !unavailable)
          ReorderableDelayedDragStartListener(
            index: index,
            child: SizedBox.square(
              dimension: AppSizes.buttonIconTouch,
              child: const Center(
                child: Icon(LucideIcons.gripVertical, size: AppSizes.icon),
              ),
            ),
          ),
      ],
    );

    return RepaintBoundary(
      key: ValueKey(video.id),
      child: VideoCard.compact(
        key: ValueKey('playlist-card:${video.id}'),
        video: displayVideo,
        enabled: !unavailable,
        onTap: () {
          if (!unavailable) openWatchPanel(ref, video.id);
        },
        trailing: trailing.children.isEmpty ? null : trailing,
      ),
    );
  }

  Widget _buildList(PlaylistPageData page) {
    if (_videos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: LucideIcons.listMusic,
          title: 'This playlist is empty',
          message: 'Add videos from Watch or Search',
        ),
      );
    }

    if (_localPlaylistId != null) {
      return SliverToBoxAdapter(
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _videos.length,
          onReorderItem: _onReorder,
          itemBuilder: (context, index) =>
              _buildVideoRow(_videos[index], index),
        ),
      );
    }

    return SliverList.builder(
      itemCount: _videos.length,
      itemBuilder: (context, index) => _buildVideoRow(_videos[index], index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _data;
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom +
        MiniPlayerInset.of(context) +
        AppSpacing.lg;

    if (_loading && page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: PlaylistScreenSkeleton(bottomPadding: bottomPadding),
        ),
      );
    }

    if (_error != null && page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorRetry(
                  message: 'Could not load playlist',
                  onRetry: _load,
                ),
              ),
              SliverBottomInset(
                extra: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
              ),
            ],
          ),
        ),
      );
    }

    if (page == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Playlist options',
              icon: const Icon(LucideIcons.ellipsis),
              onPressed: _showPlaylistMenu,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_error != null)
              SliverToBoxAdapter(
                child: InlineBanner(
                  message: 'Could not load more playlist videos',
                  actionLabel: 'Retry',
                  onAction: _loadMore,
                ),
              ),
            SliverToBoxAdapter(child: _buildHeader(page)),
            SliverToBoxAdapter(child: _buildActions()),
            _buildList(page),
            if (_loadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: SizedBox.square(
                      dimension: AppSizes.icon,
                      child: const CircularProgressIndicator(
                        strokeWidth: AppSpacing.borderWidth * 2,
                      ),
                    ),
                  ),
                ),
              ),
            SliverBottomInset(
              extra: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
          ],
        ),
      ),
    );
  }
}
