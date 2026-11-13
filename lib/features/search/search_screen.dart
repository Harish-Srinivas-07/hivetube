import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/yt/models.dart';
import '../../features/home/home_variety.dart';
import '../../features/watch/mini_player_inset.dart';
import '../../features/watch/watch_panel.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui/ui.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  Timer? debounce;
  List<String> suggestions = [];
  List<SearchResultItem> results = [];
  List<SearchFilterChip> filterChips = [];
  String? activeFilterParam;
  String? continuation;
  String activeQuery = '';
  bool loadingSuggestions = false,
      searching = false,
      loadingMore = false,
      showHidden = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 400) unawaited(loadMore());
    });
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        input.text = widget.initialQuery!;
        search(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void queryChanged(String value) {
    debounce?.cancel();
    setState(() {
      suggestions = [];
      results = [];
      filterChips = [];
      activeFilterParam = null;
      continuation = null;
      activeQuery = '';
      showHidden = false;
    });
    final query = value.trim();
    if (query.isEmpty) return;
    debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(loadSuggestions(query));
    });
  }

  Future<void> loadSuggestions(String query) async {
    setState(() => loadingSuggestions = true);
    try {
      final api = await ref.read(ytApiProvider.future);
      final values = await api.search.suggestions(query);
      if (!mounted || input.text.trim() != query) return;
      setState(() => suggestions = values);
    } catch (_) {
      if (mounted && input.text.trim() == query) {
        setState(() => suggestions = []);
      }
    } finally {
      if (mounted && input.text.trim() == query) {
        setState(() => loadingSuggestions = false);
      }
    }
  }

  Future<void> search(String query, {String? filterParam}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    FocusScope.of(context).unfocus();
    debounce?.cancel();
    setState(() {
      input.text = normalized;
      activeQuery = normalized;
      activeFilterParam = filterParam;
      suggestions = [];
      results = [];
      continuation = null;
      searching = true;
      showHidden = false;
    });
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.search.search(normalized, params: filterParam);
      if (!mounted || activeQuery != normalized) return;
      setState(() {
        results = page.items;
        continuation = page.continuation;
        if (page.filters.isNotEmpty) {
          filterChips = page.filters;
        }
      });
    } catch (_) {
      if (mounted && activeQuery == normalized) {
        setState(() => continuation = null);
      }
    } finally {
      if (mounted && activeQuery == normalized) {
        setState(() => searching = false);
      }
    }
  }

  Future<void> loadMore() async {
    final token = continuation;
    final query = activeQuery;
    if (token == null || query.isEmpty || loadingMore || searching) return;
    setState(() => loadingMore = true);
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.search.search(
        query,
        continuation: token,
        params: activeFilterParam,
      );
      if (!mounted || activeQuery != query || continuation != token) return;
      setState(() {
        results.addAll(page.items);
        continuation = page.continuation;
      });
    } catch (_) {
      if (mounted && activeQuery == query) setState(() => continuation = null);
    } finally {
      if (mounted && activeQuery == query) setState(() => loadingMore = false);
    }
  }

  Widget _buildChannelRow(ChannelItem item) {
    final theme = Theme.of(context);
    return ListTile(
      leading: ChannelAvatar(
        name: item.title,
        url: item.avatarUrl,
        size: AppSizes.avatarSm * 2,
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          item.handle,
          item.subscriberCountText,
        ].where((s) => s.isNotEmpty).join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
      trailing: FilledButton.tonal(
        onPressed: () => context.push('/channel/${item.id}'),
        child: const Text('View'),
      ),
      onTap: () => context.push('/channel/${item.id}'),
    );
  }

  Widget _buildPlaylistRow(PlaylistItem item) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SizedBox(
        width: 80,
        child: ThumbnailWithDuration(
          url: item.thumbUrl,
          borderRadius: AppRadius.smBorder,
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          item.channelName,
          item.videoCountText,
        ].where((s) => s.isNotEmpty).join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
      onTap: () => context.push('/playlist/${item.id}'),
    );
  }

  Widget _buildShortsShelf(List<ShortItem> shorts) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'Shorts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 140.0 +
              AppSpacing.xs +
              MediaQuery.textScalerOf(context).scale(40.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: shorts.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final s = shorts[i];
              return GestureDetector(
                onTap: () => openWatchPanel(ref, s.id),
                child: SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.mdBorder,
                        child: CachedNetworkImage(
                          imageUrl: s.thumbUrl,
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        s.title ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(contentPrefsProvider);

    // Filter hidden languages
    final filteredResults = results.where((item) {
      if (item is VideoSearchResult) {
        return showHidden || !hiddenLanguage(item.video, prefs.hiddenLanguages);
      }
      if (item is ShortSearchResult) {
        final v = VideoItem(
          id: item.short.id,
          title: item.short.title ?? '',
          isShort: true,
        );
        return showHidden || !hiddenLanguage(v, prefs.hiddenLanguages);
      }
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(LucideIcons.arrowLeft),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.searchMaxWidth,
                        ),
                        child: SizedBox(
                          height: AppSpacing.searchHeight,
                          child: TextField(
                            key: const ValueKey('searchQueryField'),
                            controller: input,
                            autofocus: widget.initialQuery == null,
                            textInputAction: TextInputAction.search,
                            onChanged: queryChanged,
                            onSubmitted: (q) => search(q),
                            decoration: const InputDecoration(
                              hintText: 'Search HiveTube',
                              prefixIcon: Icon(LucideIcons.search),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.pillBorder,
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Filter Chips
              if (activeQuery.isNotEmpty && filterChips.isNotEmpty)
                AppChipBar(
                  children: [
                    for (final chip in filterChips)
                      AppChip(
                        label: chip.label,
                        selected: activeFilterParam == chip.params,
                        onTap: () {
                          final isSelected = activeFilterParam == chip.params;
                          search(
                            activeQuery,
                            filterParam: isSelected ? null : chip.params,
                          );
                        },
                      ),
                  ],
                ),

              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom +
                        MiniPlayerInset.of(context) +
                        AppSpacing.lg,
                  ),
                  children: [
                    if (loadingSuggestions)
                      const LinearProgressIndicator(minHeight: 2),

                    // Suggestions
                    if (activeQuery.isEmpty)
                      for (final suggestion in suggestions)
                        ListTile(
                          key: ValueKey('suggestion_$suggestion'),
                          leading: const Icon(LucideIcons.search),
                          title: Text(suggestion),
                          onTap: () => search(suggestion),
                        ),

                    // Loading
                    if (searching) ...[
                      const SkeletonVideoCard(),
                      const SizedBox(height: AppSpacing.lg),
                      const SkeletonVideoCard(),
                    ],

                    // Results
                    if (activeQuery.isNotEmpty && !searching)
                      for (final res in filteredResults) ...[
                        if (res is VideoSearchResult)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: VideoCard.grid(
                              video: res.video,
                              onTap: () => openWatchPanel(ref, res.video.id),
                            ),
                          )
                        else if (res is ChannelSearchResult)
                          _buildChannelRow(res.channel)
                        else if (res is PlaylistSearchResult)
                          _buildPlaylistRow(res.playlist)
                        else if (res is ShortsShelfSearchResult)
                          _buildShortsShelf(res.shorts)
                        else if (res is ShortSearchResult)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: VideoCard.grid(
                              video: VideoItem(
                                id: res.short.id,
                                title: res.short.title ?? '',
                                channelId: res.short.channelId ?? '',
                                channelName: res.short.channelName ?? '',
                                channelAvatarUrl:
                                    res.short.channelAvatarUrl ?? '',
                                thumbUrl: res.short.thumbUrl,
                                viewsText: res.short.viewsText ?? '',
                                isShort: true,
                              ),
                              onTap: () => openWatchPanel(ref, res.short.id),
                            ),
                          ),
                      ],

                    if (activeQuery.isNotEmpty && !searching && results.isEmpty)
                      const AppEmptyState(
                        icon: LucideIcons.search,
                        title: 'No results found',
                        hint: 'Try searching with different keywords',
                      ),

                    if (loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
