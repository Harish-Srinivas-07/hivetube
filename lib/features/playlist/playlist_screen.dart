import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../features/watch/watch_panel.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  final scroll = ScrollController();
  PlaylistPageData? data;
  bool loading = true;
  String? error;
  bool loadingMore = false;
  final List<VideoItem> videos = [];
  String? continuation;
  bool isLocal = false;
  int? localPlaylistId;

  @override
  void initState() {
    super.initState();
    _load();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 400 && !isLocal) {
        unawaited(_loadMore());
      }
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    final isLiked = widget.playlistId == 'liked';
    final isWatchLater = widget.playlistId == 'watch_later';
    final parsedId = int.tryParse(widget.playlistId);

    if (isLiked) {
      isLocal = true;
      try {
        final db = ref.read(dbProvider);
        final likedRows = await db.reactionsDao.getLikedVideos();
        final items = likedRows
            .map(
              (m) => VideoItem(
                id: m.videoId,
                title: m.title,
                channelId: m.channelId,
                channelName: m.channelName,
                thumbUrl: m.thumbUrl,
                durationText: m.durationSec != null
                    ? '${m.durationSec! ~/ 60}:${(m.durationSec! % 60).toString().padLeft(2, '0')}'
                    : '',
              ),
            )
            .toList();

        if (!mounted) return;
        setState(() {
          data = PlaylistPageData(
            id: 'liked',
            title: 'Liked videos',
            videoCountText: '${items.length} videos',
            thumbUrl: items.isNotEmpty ? items.first.thumbUrl : '',
            videos: items,
          );
          videos.clear();
          videos.addAll(items);
          loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
      return;
    }

    if (isWatchLater || parsedId != null) {
      isLocal = true;
      try {
        final db = ref.read(dbProvider);
        PlaylistRow playlist;
        if (isWatchLater) {
          playlist = await db.playlistsDao.getOrCreateWatchLater();
        } else {
          final found = await db.playlistsDao.getPlaylist(parsedId!);
          if (found == null) throw Exception('Playlist not found');
          playlist = found;
        }
        localPlaylistId = playlist.id;

        final itemsWithMedia = await db.playlistsDao.getPlaylistItems(
          playlist.id,
        );
        final items = itemsWithMedia.map((i) {
          final m = i.media;
          final dur = m?.durationSec;
          return VideoItem(
            id: i.item.videoId,
            title: m?.title ?? i.item.videoId,
            channelId: m?.channelId ?? '',
            channelName: m?.channelName ?? '',
            thumbUrl:
                m?.thumbUrl ??
                'https://i.ytimg.com/vi/${i.item.videoId}/hqdefault.jpg',
            durationText: dur != null
                ? '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}'
                : '',
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          data = PlaylistPageData(
            id: widget.playlistId,
            title: playlist.name,
            videoCountText: '${items.length} videos',
            thumbUrl: items.isNotEmpty ? items.first.thumbUrl : '',
            videos: items,
          );
          videos.clear();
          videos.addAll(items);
          loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
      return;
    }

    // Remote playlist
    isLocal = false;
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.playlistPage(widget.playlistId);
      if (!mounted) return;
      setState(() {
        data = page;
        continuation = page.continuation;
        videos.clear();
        videos.addAll(page.videos);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final token = continuation;
    if (token == null || loadingMore || data == null || isLocal) return;
    setState(() => loadingMore = true);
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.playlistPage(
        widget.playlistId,
        continuation: token,
      );
      if (!mounted) return;
      setState(() {
        continuation = page.continuation;
        videos.addAll(page.videos);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void _playAll({bool shuffle = false}) {
    if (videos.isEmpty) return;
    final list = List<VideoItem>.from(videos);
    if (shuffle) list.shuffle();
    openWatchPanel(ref, list.first.id);
  }

  Future<void> _removeItem(int index) async {
    final item = videos[index];
    if (localPlaylistId != null) {
      await ref
          .read(dbProvider)
          .playlistsDao
          .removePlaylistItem(localPlaylistId!, item.id);
    } else if (widget.playlistId == 'liked') {
      await ref.read(dbProvider).reactionsDao.setReaction(item.id, null);
    }
    setState(() {
      videos.removeAt(index);
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = videos.removeAt(oldIndex);
    videos.insert(newIndex, item);
    setState(() {});

    if (localPlaylistId != null) {
      await ref
          .read(dbProvider)
          .playlistsDao
          .reorderPlaylistItems(localPlaylistId!, oldIndex, newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final pData = data!;

    return Scaffold(
      appBar: AppBar(
        title: Text(pData.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: CustomScrollView(
        controller: scroll,
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.mdBorder,
                    child: SizedBox(
                      width: 140,
                      height: 80,
                      child: pData.thumbUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: pData.thumbUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: theme.colorScheme.surfaceContainerHigh,
                                child: const Icon(
                                  LucideIcons.listMusic,
                                  size: AppSizes.iconLg,
                                ),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: const Icon(
                                LucideIcons.listMusic,
                                size: AppSizes.iconLg,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pData.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (pData.author.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          InkWell(
                            onTap: pData.authorId.isNotEmpty
                                ? () =>
                                      context.push('/channel/${pData.authorId}')
                                : null,
                            child: Text(
                              pData.author,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (pData.videoCountText.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            pData.videoCountText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Action Buttons: Play all & Shuffle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: videos.isNotEmpty
                          ? () => _playAll(shuffle: false)
                          : null,
                      icon: const Icon(LucideIcons.play, size: AppSizes.iconSm),
                      label: const Text('Play all'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: videos.isNotEmpty
                          ? () => _playAll(shuffle: true)
                          : null,
                      icon: const Icon(
                        LucideIcons.shuffle,
                        size: AppSizes.iconSm,
                      ),
                      label: const Text('Shuffle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider()),
          // Video List
          if (videos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'This playlist is empty',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else if (isLocal && localPlaylistId != null)
            // Reorderable list for local playlists
            SliverToBoxAdapter(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: videos.length,
                // ignore: deprecated_member_use
                onReorder: _onReorder,
                itemBuilder: (ctx, idx) {
                  final v = videos[idx];
                  return ListTile(
                    key: ValueKey('local_pl_${v.id}_$idx'),
                    leading: ClipRRect(
                      borderRadius: AppRadius.smBorder,
                      child: SizedBox(
                        width: 80,
                        height: 45,
                        child: CachedNetworkImage(
                          imageUrl: v.thumbUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: theme.colorScheme.surfaceContainerHigh,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      v.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: AppSizes.iconSm,
                          ),
                          onPressed: () => _removeItem(idx),
                        ),
                        const Icon(
                          LucideIcons.gripVertical,
                          size: AppSizes.iconSm,
                        ),
                      ],
                    ),
                    onTap: () => openWatchPanel(ref, v.id),
                  );
                },
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((ctx, idx) {
                final v = videos[idx];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: AppRadius.smBorder,
                    child: SizedBox(
                      width: 80,
                      height: 45,
                      child: CachedNetworkImage(
                        imageUrl: v.thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    [
                      v.channelName,
                      v.durationText,
                    ].where((s) => s.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isLocal
                      ? IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: AppSizes.iconSm,
                          ),
                          onPressed: () => _removeItem(idx),
                        )
                      : null,
                  onTap: () => openWatchPanel(ref, v.id),
                );
              }, childCount: videos.length),
            ),
          if (loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
