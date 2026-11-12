import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../core/yt/yt_browse.dart';
import '../../features/watch/watch_panel.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/variety_video_card.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key, required this.channelId});
  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  final scroll = ScrollController();
  ChannelPageData? data;
  bool loading = true;
  String? error;
  int selectedTabIndex = 0;
  String? activeSortParam;
  bool loadingMore = false;
  final List<dynamic> loadedItems = [];
  String? continuation;
  bool isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _load();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 400) {
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
    try {
      final api = await ref.read(ytApiProvider.future);
      var id = widget.channelId;
      if (id.startsWith('@') || id.startsWith('http')) {
        final resolved = await api.browse.resolveUrl(
          id.startsWith('http') ? id : 'https://www.youtube.com/$id',
        );
        if (resolved.isNotEmpty) id = resolved;
      }
      final page = await api.browse.channelPage(id, params: activeSortParam);
      final subs = await ref.read(subscriptionRepoProvider).channelIds();

      if (!mounted) return;
      setState(() {
        data = page;
        continuation = page.continuation;
        loadedItems.clear();
        loadedItems.addAll(page.currentTabItems);
        isSubscribed = subs.contains(id);
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
    if (token == null || loadingMore || data == null) return;
    setState(() => loadingMore = true);
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.channelPage(data!.id, continuation: token);
      if (!mounted) return;
      setState(() {
        continuation = page.continuation;
        loadedItems.addAll(page.currentTabItems);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _switchTab(String? param) async {
    if (data == null) return;
    setState(() {
      activeSortParam = param;
      loadingMore = true;
    });
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.channelPage(data!.id, params: param);
      if (!mounted) return;
      setState(() {
        continuation = page.continuation;
        loadedItems.clear();
        loadedItems.addAll(page.currentTabItems);
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void _showAboutSheet(BuildContext context) {
    if (data == null) return;
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'About',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              if (data!.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(data!.description),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Channel Details',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (data!.handle.isNotEmpty) Text('Handle: ${data!.handle}'),
              if (data!.subscribersText.isNotEmpty)
                Text('Subscribers: ${data!.subscribersText}'),
              if (data!.videosCountText.isNotEmpty)
                Text('Videos: ${data!.videosCountText}'),
              Text('Channel ID: ${data!.id}'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSubscribe() async {
    if (data == null) return;
    final next = !isSubscribed;
    setState(() => isSubscribed = next);
    try {
      await ref.read(subscriptionRepoProvider).setSubscribed(data!.id, next);
    } catch (_) {
      if (mounted) setState(() => isSubscribed = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(data?.name ?? 'Channel', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.info),
            onPressed: () => _showAboutSheet(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Failed to load channel: $error'),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : CustomScrollView(
                  controller: scroll,
                  slivers: [
                    // Banner & Profile Header
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data!.bannerUrl.isNotEmpty)
                            AspectRatio(
                              aspectRatio: 16 / 4.5,
                              child: CachedNetworkImage(
                                imageUrl: data!.bannerUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(color: theme.colorScheme.surfaceContainerHigh),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                                  backgroundImage: data!.avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(data!.avatarUrl)
                                      : null,
                                  child: data!.avatarUrl.isEmpty
                                      ? Text(data!.name.isNotEmpty ? data!.name[0] : 'C')
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data!.name, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                      if (data!.handle.isNotEmpty)
                                        Text(data!.handle, style: textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      if (data!.subscribersText.isNotEmpty || data!.videosCountText.isNotEmpty)
                                        Text(
                                          [data!.subscribersText, data!.videosCountText]
                                              .where((s) => s.isNotEmpty)
                                              .join(' • '),
                                          style: textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      const SizedBox(height: AppSpacing.sm),
                                      FilledButton.tonal(
                                        onPressed: _toggleSubscribe,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: isSubscribed ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.primary,
                                          foregroundColor: isSubscribed ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary,
                                          shape: const StadiumBorder(),
                                        ),
                                        child: Text(isSubscribed ? 'Subscribed' : 'Subscribe'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (data!.tabs.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: Row(
                                children: List.generate(data!.tabs.length, (i) {
                                  final isSelected = i == selectedTabIndex;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                                    child: ChoiceChip(
                                      label: Text(data!.tabs[i]),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() => selectedTabIndex = i);
                                          final tabName = data!.tabs[i];
                                          final param = YtBrowse.tabParamsMap[tabName];
                                          _switchTab(param);
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                          const Divider(),
                        ],
                      ),
                    ),

                    // Items Grid/List
                    if (loadedItems.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('No videos found')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = loadedItems[index];
                              if (item is VideoItem) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: VarietyVideoCard(
                                    video: item,
                                    onTap: () => openWatchPanel(ref, item.id),
                                  ),
                                );
                              } else if (item is ShortItem) {
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: AppRadius.smBorder,
                                    child: CachedNetworkImage(
                                      imageUrl: item.thumbUrl,
                                      width: 48,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text(item.title ?? 'Short', maxLines: 2),
                                  subtitle: Text(item.viewsText ?? ''),
                                  onTap: () => openWatchPanel(ref, item.id),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            childCount: loadedItems.length,
                          ),
                        ),
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
