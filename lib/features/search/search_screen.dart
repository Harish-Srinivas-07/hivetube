import 'dart:async';
import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
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
  final searchFocus = FocusNode();
  final scroll = ScrollController();
  late final SearchSuggestionSource suggestionSource;
  late final SearchSuggestionController suggestionController;
  List<SearchResultItem> results = [];
  List<SearchFilterChip> filterChips = [];
  String? activeFilterParam;
  String? continuation;
  String activeQuery = '';
  Object? searchError;
  Object? partialError;
  Future<void> Function()? partialRetry;
  bool searching = false, loadingMore = false, showHidden = false;
  int _searchGeneration = 0;

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
    searchFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void queryChanged(String value) {
    suggestionController.updateQuery(value);
    _searchGeneration++;
    setState(() {
      results = [];
      filterChips = [];
      activeFilterParam = null;
      continuation = null;
      activeQuery = '';
      showHidden = false;
      searching = false;
      searchError = null;
      partialError = null;
      partialRetry = null;
    });
  }

  int? _statusCode(Object error) =>
      error is DioException ? error.response?.statusCode : null;

  Future<void> search(
    String query, {
    String? filterParam,
    bool saveHistory = true,
    bool keepResults = false,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final generation = ++_searchGeneration;
    suggestionController.updateQuery('');
    setState(() {
      input.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      activeQuery = normalized;
      activeFilterParam = filterParam;
      if (!keepResults) results = [];
      continuation = null;
      searching = true;
      showHidden = false;
      searchError = null;
      partialError = null;
      partialRetry = null;
      if (!keepResults) filterChips = [];
    });
    if (saveHistory) {
      try {
        await ref.read(dbProvider).searchHistoryDao.saveSearchTerm(normalized);
      } catch (error, stackTrace) {
        dev.log(
          'Failed to save search term status=n/a query="$normalized" error=$error',
          name: 'SearchScreen',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted && generation == _searchGeneration) {
          setState(() => partialError = error);
        }
      }
    }
    if (!mounted || generation != _searchGeneration) return;
    searchFocus.unfocus();
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.search.search(normalized, params: filterParam);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        results = page.items;
        continuation = page.continuation;
        if (page.filters.isNotEmpty) {
          filterChips = page.filters;
        }
      });
    } catch (error, stackTrace) {
      dev.log(
        'Search request failed status=${_statusCode(error)} query="$normalized" error=$error',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && generation == _searchGeneration) {
        setState(() {
          continuation = null;
          if (keepResults && results.isNotEmpty) {
            partialError = error;
            partialRetry = () => search(
              normalized,
              filterParam: filterParam,
              saveHistory: false,
              keepResults: true,
            );
          } else {
            searchError = error;
          }
        });
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => searching = false);
      }
    }
  }

  Future<void> loadMore() async {
    final token = continuation;
    final query = activeQuery;
    final generation = _searchGeneration;
    if (token == null || query.isEmpty || loadingMore || searching) return;
    setState(() {
      loadingMore = true;
      partialError = null;
      partialRetry = null;
    });
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.search.search(
        query,
        continuation: token,
        params: activeFilterParam,
      );
      if (!mounted ||
          generation != _searchGeneration ||
          activeQuery != query ||
          continuation != token) {
        return;
      }
      setState(() {
        results.addAll(page.items);
        continuation = page.continuation;
      });
    } catch (error, stackTrace) {
      dev.log(
        'Loading more search results failed status=${_statusCode(error)} query="$query" error=$error',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && generation == _searchGeneration && activeQuery == query) {
        setState(() {
          partialError = error;
          partialRetry = loadMore;
        });
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => loadingMore = false);
      }
    }
  }

  Future<void> refreshResults() async {
    await search(
      activeQuery,
      filterParam: activeFilterParam,
      saveHistory: false,
      keepResults: true,
    );
  }

  Future<void> _removeRecent(String query) async {
    try {
      await ref.read(dbProvider).searchHistoryDao.removeSearch(query);
    } catch (error, stackTrace) {
      dev.log(
        'Failed to remove recent search status=n/a query="$query" error=$error',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => partialError = error);
    }
  }

  Future<void> _clearRecents() async {
    try {
      await ref.read(dbProvider).searchHistoryDao.clearSearches();
    } catch (error, stackTrace) {
      dev.log(
        'Failed to clear recent searches status=n/a error=$error',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => partialError = error);
    }
  }

  Future<void> _toggleSubscription(ChannelItem item, bool isSubscribed) async {
    try {
      await ref
          .read(subscriptionRepoProvider)
          .setSubscribed(
            item.id,
            !isSubscribed,
            name: item.title,
            avatarUrl: item.avatarUrl,
            handle: item.handle,
          );
    } catch (error, stackTrace) {
      dev.log(
        'Failed to update subscription status=n/a channel=${item.id} error=$error',
        name: 'SearchScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => partialError = error);
    }
  }

  Widget _buildRecentSearches(List<String> recents) {
    final queries = recents.toSet().take(10).toList();
    if (queries.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.xs,
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: AppTextStyles.meta.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearRecents,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        for (final query in queries) _buildSuggestionRow(query, recent: true),
      ],
    );
  }

  Widget _buildSuggestionState() {
    return ListenableBuilder(
      listenable: suggestionController,
      builder: (context, _) {
        if (suggestionController.isLoading) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: SizedBox(
              height: AppSizes.touchMin,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xxxl),
                  child: SkeletonBox(
                    height: AppSpacing.sm,
                    borderRadius: AppRadius.xs,
                  ),
                ),
              ),
            ),
          );
        }
        if (suggestionController.error != null) {
          return Column(
            children: [
              _buildInlineError(
                'Suggestions unavailable',
                onRetry: () async =>
                    suggestionController.updateQuery(input.text),
              ),
              _buildSuggestionRow(input.text.trim()),
            ],
          );
        }
        if (suggestionController.suggestions.isEmpty) {
          return _buildSuggestionRow(input.text.trim());
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

  Widget _buildSuggestionRow(String suggestion, {bool recent = false}) {
    final theme = Theme.of(context);
    final query = input.text.trim();
    final startsWithQuery =
        !recent &&
        query.isNotEmpty &&
        suggestion.toLowerCase().startsWith(query.toLowerCase());
    final titleStyle = theme.textTheme.bodyLarge;
    final completionStyle = titleStyle?.copyWith(fontWeight: FontWeight.w700);

    return InkWell(
      key: ValueKey('suggestion_$suggestion'),
      onTap: () => search(suggestion),
      onLongPress: recent ? () => unawaited(_removeRecent(suggestion)) : null,
      child: SizedBox(
        height: AppSizes.touchMin,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(
                recent ? LucideIcons.history : LucideIcons.search,
                size: AppSizes.iconSm,
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
                            ),
                            TextSpan(
                              text: suggestion.substring(query.length),
                              style: completionStyle,
                            ),
                          ]
                        : [TextSpan(text: suggestion)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Fill search field',
                icon: const Icon(Icons.north_west, size: AppSizes.iconSm),
                onPressed: () {
                  input.value = TextEditingValue(
                    text: suggestion,
                    selection: TextSelection.collapsed(
                      offset: suggestion.length,
                    ),
                  );
                  queryChanged(suggestion);
                  searchFocus.requestFocus();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError(String message, {Future<void> Function()? onRetry}) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: AppSizes.iconSm,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
          if (onRetry != null)
            TextButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(ChannelItem item, Set<String> subscribedIds) {
    final theme = Theme.of(context);
    final handle = item.handle.isEmpty
        ? ''
        : item.handle.startsWith('@')
        ? item.handle
        : '@${item.handle}';
    final meta = [
      handle,
      item.subscriberCountText,
    ].where((value) => value.isNotEmpty).join(' · ');
    final isSubscribed = subscribedIds.contains(item.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          ChannelAvatar(
            name: item.title,
            url: item.avatarUrl,
            size: AppSizes.avatarLg,
            onTap: () => context.push('/channel/${item.id}'),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/channel/${item.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.meta.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppSubscribedButton(
            isSubscribed: isSubscribed,
            size: AppButtonSize.standard,
            onPressed: () => unawaited(_toggleSubscription(item, isSubscribed)),
          ),
        ],
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
              child: Stack(
                children: [
                  ThumbnailWithDuration(
                    url: item.thumbUrl,
                    borderRadius: AppRadius.mdBorder,
                  ),
                  if (item.videoCountText.isNotEmpty)
                    Positioned(
                      right: AppSpacing.xs,
                      bottom: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadius.xsBorder,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.listVideo,
                              size: AppSizes.iconXs,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              item.videoCountText,
                              style: AppTextStyles.badge,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
                    style: AppTextStyles.videoTitle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      item.channelName,
                      item.videoCountText,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(
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
            child: Text('Shorts', style: AppTextStyles.sectionTitle),
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
                          style: AppTextStyles.caption,
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
    final recentSearches =
        ref.watch(recentSearchesStreamProvider).asData?.value ??
        const <String>[];
    final subscribedIds =
        ref
            .watch(subscriptionsStreamProvider)
            .asData
            ?.value
            .map((subscription) => subscription.channelId)
            .toSet() ??
        <String>{};
    final visibleFilters = filterChips
        .where((chip) => chip.type != SearchFilterType.shorts)
        .toList();
    if (visibleFilters.every((chip) => chip.type != SearchFilterType.all)) {
      visibleFilters.insert(
        0,
        const SearchFilterChip(
          label: 'All',
          params: '',
          type: SearchFilterType.all,
        ),
      );
    }

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

    final isResultsMode = activeQuery.isNotEmpty;
    final historyList = _buildRecentSearches(recentSearches);
    final typingList = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            AppSizes.bottomNav +
            MiniPlayerInset.of(context) +
            AppSpacing.lg,
      ),
      children: [
        if (partialError != null)
          _buildInlineError('Could not update search history'),
        if (input.text.trim().isNotEmpty) _buildSuggestionState(),
        if (input.text.trim().isEmpty) historyList,
      ],
    );

    final resultsList = RefreshIndicator(
      onRefresh: refreshResults,
      child: ListView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.paddingOf(context).bottom +
              AppSizes.bottomNav +
              MiniPlayerInset.of(context) +
              AppSpacing.lg,
        ),
        children: [
          if (partialError != null &&
              (results.isNotEmpty || searchError == null))
            _buildInlineError(
              'Some search details could not load',
              onRetry: partialRetry,
            ),
          if (searching && results.isEmpty) ...[
            const SkeletonVideoCard(searchResult: true),
            const SkeletonVideoCard(searchResult: true),
          ] else if (searchError != null && results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: ErrorRetry(
                message: 'Unable to search. Check your connection.',
                onRetry: () => search(
                  activeQuery,
                  filterParam: activeFilterParam,
                  saveHistory: false,
                ),
              ),
            )
          else if (!searching && filteredResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: AppEmptyState(
                icon: LucideIcons.search,
                title: "No results for '$activeQuery'",
                hint: 'Try different keywords',
              ),
            )
          else
            for (final result in filteredResults) ...[
              if (result is VideoSearchResult)
                VideoCard.searchResult(
                  video: result.video,
                  onTap: () => openWatchPanel(ref, result.video.id),
                )
              else if (result is ChannelSearchResult)
                _buildChannelRow(result.channel, subscribedIds)
              else if (result is PlaylistSearchResult)
                _buildPlaylistRow(result.playlist)
              else if (result is ShortsShelfSearchResult)
                _buildShortsShelf(result.shorts)
              else if (result is ShortSearchResult)
                VideoCard.searchResult(
                  video: VideoItem(
                    id: result.short.id,
                    title: result.short.title ?? '',
                    channelId: result.short.channelId ?? '',
                    channelName: result.short.channelName ?? '',
                    channelAvatarUrl: result.short.channelAvatarUrl ?? '',
                    thumbUrl: result.short.thumbUrl,
                    viewsText: result.short.viewsText ?? '',
                    isShort: true,
                  ),
                  onTap: () => openWatchPanel(ref, result.short.id),
                ),
            ],
          if (loadingMore)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: SizedBox.square(
                  dimension: AppSizes.icon,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
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
                              focusNode: searchFocus,
                              autofocus: true,
                              style: AppTextStyles.settingsTitle,
                              textInputAction: TextInputAction.search,
                              onChanged: queryChanged,
                              onSubmitted: (query) => search(query),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                hintText: 'Search',
                                prefixIcon: const Icon(
                                  LucideIcons.search,
                                  size: AppSizes.iconSm,
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: AppSizes.touchMin,
                                ),
                                suffixIcon: input.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          input.clear();
                                          queryChanged('');
                                          searchFocus.requestFocus();
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
              ),
              if (isResultsMode && visibleFilters.isNotEmpty)
                AppChipBar(
                  children: [
                    for (final chip in visibleFilters)
                      AppChip(
                        label: chip.label,
                        selected: chip.type == SearchFilterType.all
                            ? activeFilterParam == null
                            : activeFilterParam == chip.params,
                        onTap: () {
                          if (chip.type == SearchFilterType.all) {
                            search(activeQuery);
                            return;
                          }
                          final isSelected = activeFilterParam == chip.params;
                          search(
                            activeQuery,
                            filterParam: isSelected ? null : chip.params,
                          );
                        },
                      ),
                  ],
                ),
              Expanded(child: isResultsMode ? resultsList : typingList),
            ],
          ),
        ),
      ),
    );
  }
}
