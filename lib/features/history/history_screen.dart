import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_db.dart';
import '../../core/playback/session_queue.dart';
import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/common.dart';
import '../playlist/save_to_playlist_sheet.dart';
import '../../widgets/sheets/app_sheet.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/ui/app_controls.dart';
import '../watch/mini_player_inset.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _pageSize = 50;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final List<HistoryItemWithMedia> _items = [];
  String _query = '';
  bool _searchOpen = false;
  bool _historyPaused = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  final Set<String> _metadataBackfills = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadSettings());
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final value = await ref.read(dbProvider).getValue('history_paused');
    if (mounted) setState(() => _historyPaused = value == 'true');
  }

  Future<void> _loadFirstPage({bool refresh = false}) async {
    if (!refresh && _items.isEmpty && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final page = await ref
          .read(dbProvider)
          .historyDao
          .getHistory(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page);
        _hasMore = page.length == _pageSize;
        _loadError = null;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[History] load failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loadError != null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(dbProvider)
          .historyDao
          .getHistory(limit: _pageSize, offset: _items.length);
      if (!mounted) return;
      setState(() {
        final knownIds = _items.map((item) => item.history.id).toSet();
        _items.addAll(
          page.where((item) => !knownIds.contains(item.history.id)),
        );
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[History] load more failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _loadingMore = false;
        });
      }
    }
  }

  void _retryLoadMore() {
    setState(() => _loadError = null);
    unawaited(_loadMore());
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < AppSpacing.xxxl) {
      unawaited(_loadMore());
    }
  }

  Future<void> _togglePauseHistory() async {
    final next = !_historyPaused;
    await ref.read(dbProvider).setValue('history_paused', next.toString());
    if (mounted) setState(() => _historyPaused = next);
  }

  Future<void> _clearAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Clear watch history?',
        content: const Text('This removes watch history from this device.'),
        actions: [
          AppButton.text(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.text(
            label: 'Clear',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(dbProvider).historyDao.clearHistory();
      if (!mounted) return;
      setState(() {
        _items.clear();
        _hasMore = false;
        _loadError = null;
      });
      AppSnackbar.show(context, 'History cleared');
    } catch (error, stackTrace) {
      debugPrint('[History] clear failed: $error\n$stackTrace');
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  Future<void> _showTopMenu() async {
    final action = await showAppSheet<String>(
      context,
      fit: true,
      builder: (sheetContext, _) => ListView(
        shrinkWrap: true,
        children: [
          AppSheetRow(
            icon: LucideIcons.trash2,
            label: 'Clear all history',
            onTap: () => Navigator.of(sheetContext).pop('clear'),
          ),
          AppSheetRow(
            icon: _historyPaused ? LucideIcons.play : LucideIcons.pause,
            label: _historyPaused ? 'Resume history' : 'Pause history',
            onTap: () => Navigator.of(sheetContext).pop('pause'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'clear') await _clearAllHistory();
    if (action == 'pause') await _togglePauseHistory();
  }

  Future<void> _showItemMenu(HistoryItemWithMedia item) async {
    final videoId = item.history.videoId;
    final action = await showAppSheet<String>(
      context,
      fit: true,
      builder: (sheetContext, _) => ListView(
        shrinkWrap: true,
        children: [
          AppSheetRow(
            icon: LucideIcons.listStart,
            label: 'Play next',
            onTap: () => Navigator.of(sheetContext).pop('next'),
          ),
          AppSheetRow(
            icon: LucideIcons.listPlus,
            label: 'Add to queue',
            onTap: () => Navigator.of(sheetContext).pop('queue'),
          ),
          AppSheetRow(
            icon: LucideIcons.trash2,
            label: 'Remove from history',
            onTap: () => Navigator.of(sheetContext).pop('remove'),
          ),
          AppSheetRow(
            icon: LucideIcons.listPlus,
            label: 'Save to playlist',
            onTap: () => Navigator.of(sheetContext).pop('playlist'),
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
      case 'next':
        ref.read(sessionQueueProvider.notifier).playNext(_toVideo(item));
        AppSnackbar.show(context, 'Will play next');
        break;
      case 'queue':
        ref.read(sessionQueueProvider.notifier).add(_toVideo(item));
        AppSnackbar.show(context, 'Added to queue');
        break;
      case 'remove':
        await _removeItem(item);
        break;
      case 'playlist':
        await showSaveToPlaylistSheet(context, videoId: videoId);
        break;
      case 'share':
        unawaited(
          SharePlus.instance.share(
            ShareParams(
              uri: Uri.https('www.youtube.com', '/watch', {'v': videoId}),
            ),
          ),
        );
        break;
    }
  }

  Future<void> _removeItem(HistoryItemWithMedia item) async {
    final db = ref.read(dbProvider);
    await db.historyDao.deleteHistoryItem(item.history.id);
    if (!mounted) return;
    setState(
      () => _items.removeWhere((row) => row.history.id == item.history.id),
    );
    AppSnackbar.show(
      context,
      'Removed from history',
      actionLabel: 'Undo',
      onAction: () => unawaited(_restoreItem(item)),
    );
  }

  Future<void> _restoreItem(HistoryItemWithMedia item) async {
    await ref.read(dbProvider).historyDao.restoreHistoryItem(item.history);
    await _reloadLoadedItems();
  }

  Future<void> _reloadLoadedItems() async {
    final count = _items.length;
    final limit = count < _pageSize ? _pageSize : count;
    final page = await ref.read(dbProvider).historyDao.getHistory(limit: limit);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(page);
      _hasMore = page.length == limit;
    });
  }

  Future<void> _backfillMetadata(String videoId) async {
    if (!_metadataBackfills.add(videoId)) return;
    final db = ref.read(dbProvider);
    try {
      final api = await ref.read(ytApiProvider.future);
      final info = await api.next.watch(videoId);
      await db.historyDao.updateMediaMetadata(
        videoId: videoId,
        title: info.title,
        channelId: info.channelId,
        channelName: info.channelName,
        thumbUrl: info.thumbnail.isNotEmpty
            ? info.thumbnail
            : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        durationSec: info.durationSec,
      );
      if (mounted) await _reloadLoadedItems();
    } catch (error, stackTrace) {
      debugPrint('[History] metadata backfill failed: $error\n$stackTrace');
      await db.historyDao.updateMediaMetadata(
        videoId: videoId,
        title: 'Untitled video',
        channelId: '',
        channelName: '',
        thumbUrl: '',
      );
      if (mounted) await _reloadLoadedItems();
    }
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      _searchFocusNode.requestFocus();
    } else {
      _searchController.clear();
      setState(() => _query = '');
      _searchFocusNode.unfocus();
    }
  }

  List<HistoryItemWithMedia> get _filteredItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final title = item.media?.title.toLowerCase() ?? '';
      final channel = item.media?.channelName.toLowerCase() ?? '';
      return title.contains(query) || channel.contains(query);
    }).toList();
  }

  List<({String? header, HistoryItemWithMedia? item})> _groupItems(
    List<HistoryItemWithMedia> items,
  ) {
    final result = <({String? header, HistoryItemWithMedia? item})>[];
    DateTime? lastDay;
    for (final item in items) {
      final at = DateTime.fromMillisecondsSinceEpoch(item.history.at);
      final day = DateTime(at.year, at.month, at.day);
      if (day != lastDay) {
        result.add((header: _dayLabel(day), item: null));
        lastDay = day;
      }
      result.add((header: null, item: item));
    }
    return result;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    final shortDate = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(date);
    return '$weekday, $shortDate';
  }

  VideoItem _toVideo(HistoryItemWithMedia item) {
    final media = item.media;
    final videoId = item.history.videoId;
    final title = media?.title.isNotEmpty == true && media?.title != videoId
        ? media!.title
        : 'Untitled video';
    if (title == 'Untitled video' || media?.channelName.isEmpty != false) {
      unawaited(_backfillMetadata(videoId));
    }
    return VideoItem(
      id: videoId,
      title: title,
      channelId: media?.channelId ?? '',
      channelName: media?.channelName ?? '',
      thumbUrl:
          media?.thumbUrl ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      durationText: AppFormatters.formatDurationSeconds(
        item.history.durationMs ~/ 1000,
      ),
      publishedText: MaterialLocalizations.of(context).formatShortMonthDay(
        DateTime.fromMillisecondsSinceEpoch(item.history.at),
      ),
    );
  }

  Widget _buildRow(HistoryItemWithMedia item) {
    final progress = item.history.durationMs > 0
        ? item.history.positionMs / item.history.durationMs
        : 0.0;
    return RepaintBoundary(
      key: ValueKey(item.history.videoId),
      child: Dismissible(
        key: ValueKey('history:${item.history.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Icon(
            LucideIcons.trash2,
            size: AppSizes.icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        onDismissed: (_) => unawaited(_removeItem(item)),
        child: VideoCard.compact(
          video: _toVideo(item),
          progress: item.history.positionMs > 0 ? progress : null,
          onTap: () => context.push('/watch/${item.history.videoId}'),
          trailing: SizedBox.square(
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
              onPressed: () => _showItemMenu(item),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final grouped = _groupItems(items);
    final bottomInset =
        MediaQuery.paddingOf(context).bottom +
        MiniPlayerInset.of(context) +
        AppSpacing.lg;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Search history',
            icon: const Icon(LucideIcons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: 'History options',
            icon: const Icon(LucideIcons.ellipsis),
            onPressed: _showTopMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: SizedBox(
                height: AppSpacing.searchHeight,
                child: ClipRRect(
                  borderRadius: AppRadius.pillBorder,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search history',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(LucideIcons.x),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading && _items.isEmpty
                ? HistorySkeleton(bottomPadding: bottomInset)
                : RefreshIndicator(
                    onRefresh: () => _loadFirstPage(refresh: true),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_historyPaused)
                          SliverToBoxAdapter(
                            child: InlineBanner(
                              message: 'Watch history is paused',
                              actionLabel: 'Turn on',
                              onAction: _togglePauseHistory,
                            ),
                          ),
                        if (_loadError != null && _items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: ErrorRetry(
                              message: 'Could not load watch history',
                              onRetry: () => _loadFirstPage(refresh: true),
                            ),
                          )
                        else if (items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: LucideIcons.clock3,
                              title: _query.isEmpty
                                  ? 'No watch history'
                                  : 'No matching history',
                              message: _query.isEmpty
                                  ? 'Videos you watch will appear here'
                                  : 'Try a different title or channel',
                            ),
                          )
                        else
                          SliverList.builder(
                            itemCount: grouped.length,
                            itemBuilder: (context, index) {
                              final entry = grouped[index];
                              if (entry.item != null) {
                                return _buildRow(entry.item!);
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  AppSpacing.lg,
                                  AppSpacing.md,
                                  AppSpacing.sm,
                                ),
                                child: Text(
                                  entry.header!,
                                  style: AppTextStyles.sectionTitle,
                                ),
                              );
                            },
                          ),
                        if (_loadError != null && _items.isNotEmpty)
                          SliverToBoxAdapter(
                            child: ErrorRetry(
                              message: 'Could not load more history',
                              onRetry: _retryLoadMore,
                            ),
                          )
                        else if (_loadingMore)
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
                        SliverToBoxAdapter(
                          child: SizedBox(height: bottomInset),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
