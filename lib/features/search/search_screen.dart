import 'dart:async';
import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/yt/models.dart';
import '../../services/search_suggestions.dart';
import '../../features/home/home_variety.dart';
import '../../features/watch/mini_player_inset.dart';
import '../../features/watch/watch_panel.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui/ui.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.suggestionSource});
  final String? initialQuery;
  final SearchSuggestionSource? suggestionSource;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  late final SearchSuggestionSource suggestionSource;
  late final SearchSuggestionController suggestionController;
  List<SearchResultItem> results = [];
  List<SearchFilterChip> filterChips = [];
  String? activeFilterParam;
  String? continuation;
  String activeQuery = '';
  Object? searchError;
  Object? loadMoreError;
  bool searching = false, loadingMore = false, showHidden = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(contentPrefsProvider);
    suggestionSource =
        widget.suggestionSource ??
        YoutubeSearchSuggestionSource(
          hl: 'en',
          gl: prefs.gl == 'AUTO' ? '' : prefs.gl,
        );
    suggestionController = SearchSuggestionController(source: suggestionSource);
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
    suggestionController.dispose();
    suggestionSource.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void queryChanged(String value) {
    suggestionController.updateQuery(value);
    setState(() {
      results = [];
      filterChips = [];
      activeFilterParam = null;
      continuation = null;
      activeQuery = '';
      showHidden = false;
      searchError = null;
      loadMoreError = null;
    });
  }

  Future<void> search(String query, {String? filterParam}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    FocusScope.of(context).unfocus();
    suggestionController.updateQuery('');
    setState(() {
      input.text = normalized;
      activeQuery = normalized;
      activeFilterParam = filterParam;
      results = [];
      continuation = null;
      searching = true;
      showHidden = false;
      searchError = null;
      loadMoreError = null;
    });
    try {
      await ref.read(dbProvider).searchHistoryDao.saveSearchTerm(normalized);
    } catch (error, stackTrace) {
      dev.log(
        'Failed to save search term "$normalized"',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && activeQuery == normalized) {
        setState(() => searchError = error);
      }
    }
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
    } catch (error, stackTrace) {
      dev.log(
        'Search request failed for "$normalized"',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && activeQuery == normalized) {
        setState(() {
          continuation = null;
          searchError = error;
        });
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
    setState(() {
      loadingMore = true;
      loadMoreError = null;
    });
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
    } catch (error, stackTrace) {
      dev.log(
        'Loading more search results failed for "$query"',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && activeQuery == query) {
        setState(() {
          continuation = null;
          loadMoreError = error;
        });
      }
    } finally {
      if (mounted && activeQuery == query) setState(() => loadingMore = false);
    }
  }

  Widget _buildSuggestionState() {
    if (input.text.trim().isEmpty || activeQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: suggestionController,
      builder: (context, _) {
        if (suggestionController.isLoading) {
          return const Column(
            children: [
              LinearProgressIndicator(minHeight: 2),
              ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading suggestions…'),
              ),
            ],
          );
        }
        if (suggestionController.error != null) {
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Suggestions unavailable'),
                subtitle: const Text('Tap to retry or search this text.'),
                trailing: IconButton(
                  tooltip: 'Retry suggestions',
                  onPressed: () => suggestionController.updateQuery(input.text),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              _buildTypedQueryRow(),
            ],
          );
        }
        if (suggestionController.suggestions.isEmpty) {
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.search_off),
                title: const Text('No suggestions found'),
              ),
              _buildTypedQueryRow(),
            ],
          );
        }
        return Column(
          children: [
            for (final suggestion in suggestionController.suggestions)
              ListTile(
                key: ValueKey('suggestion_$suggestion'),
                leading: const Icon(LucideIcons.search),
                title: Text(suggestion),
                onTap: () => search(suggestion),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTypedQueryRow() => ListTile(
    key: const ValueKey('searchTypedQueryFallback'),
    leading: const Icon(LucideIcons.search),
    title: Text('Search for “${input.text.trim()}”'),
    onTap: () => search(input.text),
  );

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
          height:
              140.0 +
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
                    bottom:
                        MediaQuery.paddingOf(context).bottom +
                        MiniPlayerInset.of(context) +
                        AppSpacing.lg,
                  ),
                  children: [
                    _buildSuggestionState(),

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

                    if (activeQuery.isNotEmpty &&
                        !searching &&
                        searchError != null)
                      ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('Search failed'),
                        subtitle: const Text(
                          'Check your connection and retry.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Retry search',
                          onPressed: () => search(
                            activeQuery,
                            filterParam: activeFilterParam,
                          ),
                          icon: const Icon(Icons.refresh),
                        ),
                      ),

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
                    if (loadMoreError != null)
                      const ListTile(
                        leading: Icon(Icons.error_outline),
                        title: Text('Could not load more results'),
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
