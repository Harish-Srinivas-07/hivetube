import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/yt/models.dart';
import '../../features/home/home_variety.dart';
import '../../features/watch/watch_panel.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  Timer? debounce;
  List<String> suggestions = [];
  List<VideoItem> results = [];
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

  Future<void> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    FocusScope.of(context).unfocus();
    debounce?.cancel();
    setState(() {
      input.text = normalized;
      activeQuery = normalized;
      suggestions = [];
      results = [];
      continuation = null;
      searching = true;
      showHidden = false;
    });
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.search.videos(normalized);
      if (!mounted || activeQuery != normalized) return;
      setState(() {
        results = page.items;
        continuation = page.continuation;
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
      final page = await api.search.videos(query, continuation: token);
      if (!mounted || activeQuery != query || continuation != token) return;
      final existing = results.map((item) => item.id).toSet();
      setState(() {
        results.addAll(page.items.where((item) => existing.add(item.id)));
        continuation = page.continuation;
      });
    } catch (_) {
      if (mounted && activeQuery == query) setState(() => continuation = null);
    } finally {
      if (mounted && activeQuery == query) setState(() => loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(contentPrefsProvider);
    ref.listen(contentPrefsProvider, (previous, next) {
      if (previous != null &&
          (previous.gl != next.gl || previous.hl != next.hl) &&
          input.text.trim().isNotEmpty &&
          activeQuery.isEmpty) {
        unawaited(loadSuggestions(input.text.trim()));
      }
    });
    final visible = results
        .where((item) => !hiddenLanguage(item, prefs.hiddenLanguages))
        .toList();
    final dropped = results
        .where((item) => hiddenLanguage(item, prefs.hiddenLanguages))
        .toList();
    final shownResults = showHidden ? results : visible;
    final colors = Theme.of(context).colorScheme;

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
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onChanged: queryChanged,
                            onSubmitted: search,
                            decoration: InputDecoration(
                              hintText: 'Search HiveTube',
                              prefixIcon: const Icon(LucideIcons.search),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              border: const OutlineInputBorder(
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
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom +
                        (ref.watch(watchPanelProvider) != null
                            ? 120
                            : AppSpacing.lg),
                  ),
                  children: [
                    if (loadingSuggestions)
                      const LinearProgressIndicator(minHeight: 2),
                    if (activeQuery.isEmpty)
                      for (final suggestion in suggestions)
                        ListTile(
                          key: ValueKey('suggestion_$suggestion'),
                          leading: const Icon(LucideIcons.search),
                          title: Text(suggestion),
                          onTap: () => search(suggestion),
                        ),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (activeQuery.isNotEmpty && !searching)
                      for (final item in shownResults)
                        ListTile(
                          key: ValueKey('searchResult_${item.id}'),
                          title: Text(item.title),
                          subtitle: item.channelName.isEmpty
                              ? null
                              : Text(item.channelName),
                          onTap: () => openWatchPanel(ref, item.id),
                        ),
                    if (activeQuery.isNotEmpty && dropped.isNotEmpty)
                      ListTile(
                        key: const ValueKey('searchShowHidden'),
                        leading: Icon(
                          showHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: colors.onSurfaceVariant,
                        ),
                        title: Text(
                          showHidden
                              ? 'Hide filtered results'
                              : 'Show hidden (${dropped.length})',
                        ),
                        onTap: () => setState(() => showHidden = !showHidden),
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
