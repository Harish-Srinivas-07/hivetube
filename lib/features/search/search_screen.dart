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
import '../../theme/app_text_styles.dart';
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
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        SkeletonBox(
                          width: 20,
                          height: 20,
                          borderRadius: AppRadius.pill,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SkeletonBox(
                            height: 14,
                            borderRadius: AppRadius.xs,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
              _buildSuggestionRow(suggestion),
          ],
        );
      },
    );
  }

  Widget _buildSuggestionRow(String suggestion) {
    final theme = Theme.of(context);
    final query = input.text.trim();
    final startsWithQuery =
        query.isNotEmpty &&
        suggestion.toLowerCase().startsWith(query.toLowerCase());
    final titleStyle = theme.textTheme.bodyLarge;
    final matchStyle = titleStyle?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      children: [
        InkWell(
          key: ValueKey('suggestion_$suggestion'),
          onTap: () => search(suggestion),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 19,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: titleStyle,
                        children: startsWithQuery
                            ? [
                                TextSpan(
                                  text: suggestion.substring(0, query.length),
                                  style: matchStyle,
                                ),
                                TextSpan(
                                  text: suggestion.substring(query.length),
                                ),
                              ]
                            : [TextSpan(text: suggestion)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Use suggestion',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.north_west, size: 19),
                    onPressed: () {
                      input.value = TextEditingValue(
                        text: suggestion,
                        selection: TextSelection.collapsed(
                          offset: suggestion.length,
                        ),
                      );
                      queryChanged(suggestion);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          indent: AppSpacing.md + 19 + AppSpacing.md,
          endIndent: AppSpacing.md,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: ChannelAvatar(
          name: item.title,
          url: item.avatarUrl,
          size: AppSizes.avatarLg,
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.subscriberCountText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => context.push('/channel/${item.id}'),
      ),
    );
  }

  Widget _buildPlaylistRow(PlaylistItem item) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      child: InkWell(
        onTap: () => context.push('/playlist/${item.id}'),
        child: Row(
          children: [
            SizedBox(
              width: AppSizes.searchCompactThumbnailWidth,
              child: ThumbnailWithDuration(
                url: item.thumbUrl,
                borderRadius: AppRadius.mdBorder,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      item.channelName,
                      item.videoCountText,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortsShelf(List<ShortItem> shorts) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
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
                AppSizes.horizontalThumbCardHeight +
                AppSpacing.xs +
                MediaQuery.textScalerOf(
                  context,
                ).scale(AppTextStyles.caption.fontSize! * 2),
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
                    width: AppSpacing.shortWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.mdBorder,
                          child: CachedNetworkImage(
                            imageUrl: s.thumbUrl,
                            width: AppSpacing.shortWidth,
                            height: AppSizes.horizontalThumbCardHeight,
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
      ),
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
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
                      const SkeletonVideoCard(searchResult: true),
                      const SkeletonVideoCard(searchResult: true),
                      const SkeletonVideoCard(searchResult: true),
                    ],

                    // Results
                    if (activeQuery.isNotEmpty && !searching)
                      for (final res in filteredResults) ...[
                        if (res is VideoSearchResult)
                          VideoCard.searchResult(
                            video: res.video,
                            onTap: () => openWatchPanel(ref, res.video.id),
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
                            child: VideoCard.compact(
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
