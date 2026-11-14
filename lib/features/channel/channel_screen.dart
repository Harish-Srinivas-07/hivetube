import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../core/yt/models.dart';
import '../../core/yt/yt_browse.dart';
import '../../features/shorts/shorts_screen.dart';
import '../../features/watch/mini_player_inset.dart';
import '../../features/watch/watch_panel.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key, required this.channelId});
  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen>
    with TickerProviderStateMixin {
  ChannelPageData? data;
  bool loading = true;
  String? error;
  String? partialError;
  bool isSubscribed = false;
  bool loadingMore = false;
  String _notificationMode = 'Personalized';
  String _resolvedChannelId = '';
  List<String> _tabs = const ['Home', 'Videos', 'Shorts', 'About'];
  TabController? _tabController;
  int _selectedTabIndex = 0;
  final Map<String, List<dynamic>> _itemsByTab = {};
  final Map<String, String?> _continuationByTab = {};
  final Set<String> _loadedTabs = {};
  final Map<String, String?> _sortByTab = {};
  final Set<String> _loadingTabs = {};

  String get _selectedTab =>
      _tabs[_selectedTabIndex.clamp(0, _tabs.length - 1).toInt()];

  @override
  void initState() {
    super.initState();
    _configureTabController(_tabs);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ChannelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _itemsByTab.clear();
      _continuationByTab.clear();
      _loadedTabs.clear();
      _sortByTab.clear();
      _resolvedChannelId = '';
      data = null;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _configureTabController(List<String> tabs) {
    if (_tabController != null &&
        _tabs.length == tabs.length &&
        List.generate(
          tabs.length,
          (i) => _tabs[i] == tabs[i],
        ).every((v) => v)) {
      return;
    }
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabs = tabs;
    _selectedTabIndex = _selectedTabIndex.clamp(0, tabs.length - 1).toInt();
    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: _selectedTabIndex,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    final index = controller.index;
    if (index != _selectedTabIndex) {
      setState(() => _selectedTabIndex = index);
    }
    unawaited(_loadTab(_tabs[index]));
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      partialError = null;
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
      final page = await api.browse.channelPage(id);
      final subs = await ref.read(subscriptionRepoProvider).channelIds();
      final tabs = <String>['Home', 'Videos', 'Shorts', 'About'];
      if (!mounted) return;
      setState(() {
        _resolvedChannelId = id;
        data = page;
        _itemsByTab['Home'] = List<dynamic>.of(page.currentTabItems);
        _continuationByTab['Home'] = page.continuation;
        _loadedTabs.add('Home');
        isSubscribed = subs.contains(id);
        loading = false;
      });
      _configureTabController(tabs);
      if (isSubscribed) unawaited(_loadNotificationMode());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadNotificationMode() async {
    final id = _resolvedChannelId;
    if (id.isEmpty) return;
    final value = await ref
        .read(dbProvider)
        .getValue('subscription_notifications_$id');
    if (mounted && value != null) setState(() => _notificationMode = value);
  }

  String? _paramsForTab(String tab) => switch (tab) {
    'Videos' => _sortByTab['Videos'] ?? YtBrowse.tabParamsVideos,
    'Shorts' => YtBrowse.tabParamsShorts,
    _ => null,
  };

  Future<void> _loadTab(String tab, {bool refresh = false}) async {
    if (tab == 'About' || data == null || _loadingTabs.contains(tab)) return;
    if (!refresh && _loadedTabs.contains(tab)) return;
    _loadingTabs.add(tab);
    if (mounted) setState(() {});
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.channelPage(
        data!.id,
        params: _paramsForTab(tab),
      );
      if (!mounted) return;
      setState(() {
        _itemsByTab[tab] = List<dynamic>.of(page.currentTabItems);
        _continuationByTab[tab] = page.continuation;
        _loadedTabs.add(tab);
        if (page.sortChips.isNotEmpty) {
          data = _copyWithSortChips(data!, page.sortChips);
        }
        partialError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => partialError = 'Some channel content could not load.');
      }
    } finally {
      _loadingTabs.remove(tab);
      if (mounted) setState(() {});
    }
  }

  ChannelPageData _copyWithSortChips(
    ChannelPageData value,
    List<({String label, String params})> chips,
  ) => ChannelPageData(
    id: value.id,
    name: value.name,
    handle: value.handle,
    avatarUrl: value.avatarUrl,
    bannerUrl: value.bannerUrl,
    subscribersText: value.subscribersText,
    videosCountText: value.videosCountText,
    description: value.description,
    tabs: value.tabs,
    currentTabItems: value.currentTabItems,
    continuation: value.continuation,
    sortChips: chips,
  );

  Future<void> _refreshTab(String tab) async {
    if (tab == 'About') {
      await _load();
      return;
    }
    await _loadTab(tab, refresh: true);
  }

  Future<void> _loadMore(String tab) async {
    final token = _continuationByTab[tab];
    if (token == null || loadingMore || data == null) return;
    setState(() => loadingMore = true);
    try {
      final api = await ref.read(ytApiProvider.future);
      final page = await api.browse.channelPage(data!.id, continuation: token);
      if (!mounted) return;
      setState(() {
        _continuationByTab[tab] = page.continuation;
        _itemsByTab.putIfAbsent(tab, () => []).addAll(page.currentTabItems);
        partialError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => partialError = 'More channel content could not load.');
      }
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _selectSort(String params) async {
    _sortByTab['Videos'] = params;
    _loadedTabs.remove('Videos');
    await _loadTab('Videos', refresh: true);
  }

  Future<void> _toggleSubscription(bool next) async {
    final channel = data;
    if (channel == null) return;
    setState(() => isSubscribed = next);
    try {
      await ref
          .read(subscriptionRepoProvider)
          .setSubscribed(
            channel.id,
            next,
            name: channel.name,
            avatarUrl: channel.avatarUrl,
            handle: channel.handle,
          );
      if (next) unawaited(_loadNotificationMode());
    } catch (_) {
      if (!mounted) return;
      setState(() => isSubscribed = !next);
      AppSnackbar.show(context, 'Could not update subscription', isError: true);
    }
  }

  Future<void> _onSubscribePressed() async {
    if (isSubscribed) {
      await _showNotificationSheet();
    } else {
      await _toggleSubscription(true);
    }
  }

  Future<void> _showNotificationSheet() async {
    final selected = await showAppSheet<String>(
      context,
      fit: true,
      title: 'Notifications',
      showClose: false,
      builder: (sheetContext, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in const ['All', 'Personalized', 'None'])
            AppSheetRow(
              icon: option == 'None' ? LucideIcons.bellOff : LucideIcons.bell,
              label: option,
              selected: _notificationMode == option,
              onTap: () => Navigator.pop(sheetContext, option),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await ref
        .read(dbProvider)
        .setValue('subscription_notifications_$_resolvedChannelId', selected);
    if (mounted) setState(() => _notificationMode = selected);
  }

  Future<void> _showMenu() async {
    final action = await showAppSheet<String>(
      context,
      fit: true,
      showClose: false,
      builder: (sheetContext, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetRow(
            icon: LucideIcons.info,
            label: 'About',
            onTap: () {
              Navigator.pop(sheetContext, 'about');
              _selectTab('About');
            },
          ),
          if (isSubscribed)
            AppSheetRow(
              icon: LucideIcons.userRoundMinus,
              label: 'Unsubscribe',
              onTap: () => Navigator.pop(sheetContext, 'unsubscribe'),
            ),
        ],
      ),
    );
    if (action == 'unsubscribe') await _toggleSubscription(false);
  }

  void _selectTab(String name) {
    final index = _tabs.indexOf(name);
    if (index >= 0) _tabController?.animateTo(index, duration: AppMotion.base);
  }

  String _channelMeta(ChannelPageData channel) => [
    if (channel.handle.isNotEmpty) channel.handle,
    if (channel.subscribersText.isNotEmpty) channel.subscribersText,
    if (channel.videosCountText.isNotEmpty) channel.videosCountText,
  ].join(' · ');

  double _bannerHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width / (AppSpacing.xl / AppSpacing.xs);

  double _profileHeaderHeight(ChannelPageData channel) =>
      AppSpacing.lg +
      AppSizes.avatarLg +
      (channel.description.isNotEmpty
          ? AppSpacing.md +
                AppTextStyles.meta.height! * AppTextStyles.meta.fontSize! * 2
          : 0) +
      AppSpacing.md +
      AppSizes.buttonLarge +
      AppSpacing.md;

  void _openShorts(List<ShortItem> items, int index) {
    ref.read(shortsSelectionProvider.notifier).open(items, index);
    context.go('/shorts');
  }

  @override
  Widget build(BuildContext context) {
    final channel = data;
    if (loading && channel == null) return const _ChannelLoadingScreen();
    if (error != null && channel == null) {
      return Scaffold(
        body: SafeArea(
          child: ErrorRetry(message: 'Unable to load channel.', onRetry: _load),
        ),
      );
    }
    if (channel == null) return const _ChannelLoadingScreen();

    final colors = Theme.of(context).colorScheme;
    final hasBanner = channel.bannerUrl.isNotEmpty;
    final bannerHeight = hasBanner ? _bannerHeight(context) : 0.0;
    final headerTop = hasBanner ? bannerHeight : AppSizes.topBar;
    final expandedHeight = headerTop + _profileHeaderHeight(channel);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: expandedHeight,
            toolbarHeight: AppSizes.topBar,
            backgroundColor: innerBoxIsScrolled || !hasBanner
                ? colors.surface
                : AppColors.transparent,
            surfaceTintColor: AppColors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              icon: Icon(
                LucideIcons.arrowLeft,
                color: innerBoxIsScrolled || !hasBanner
                    ? colors.onSurface
                    : AppColors.white,
              ),
            ),
            title: AnimatedSwitcher(
              duration: AppMotion.base,
              child: innerBoxIsScrolled
                  ? Text(
                      channel.name,
                      key: const ValueKey('channelToolbarTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: colors.onSurface,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('channelToolbarEmpty')),
            ),
            actions: [
              IconButton(
                tooltip: 'Search',
                onPressed: () => context.push('/search'),
                icon: Icon(
                  LucideIcons.search,
                  color: innerBoxIsScrolled || !hasBanner
                      ? colors.onSurface
                      : AppColors.white,
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: _showMenu,
                icon: Icon(
                  LucideIcons.ellipsis,
                  color: innerBoxIsScrolled || !hasBanner
                      ? colors.onSurface
                      : AppColors.white,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasBanner)
                            SizedBox(
                              height: bannerHeight,
                              child: CachedNetworkImage(
                                imageUrl: channel.bannerUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => ColoredBox(
                                  color: colors.surfaceContainerHighest,
                                ),
                                errorWidget: (_, _, _) => ColoredBox(
                                  color: colors.surfaceContainerHighest,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: AppSizes.topBar),
                          _profileHeader(context, channel),
                        ],
                      ),
                    ),
                    if (hasBanner)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: AppSizes.topBar,
                        child: ColoredBox(color: AppColors.scrim),
                      ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(AppSizes.settingsRowHeight),
              child: Container(
                color: colors.surface,
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  labelStyle: AppTextStyles.videoTitle,
                  unselectedLabelStyle: AppTextStyles.videoTitle,
                  labelColor: colors.onSurface,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  indicatorColor: colors.onSurface,
                  indicatorWeight: AppSpacing.xs / 2,
                  tabs: [for (final tab in _tabs) Tab(text: tab)],
                ),
              ),
            ),
          ),
        ],
        body: _tabController == null
            ? const SizedBox.shrink()
            : TabBarView(
                controller: _tabController,
                children: [
                  for (final tab in _tabs) _tabBody(context, tab, channel),
                ],
              ),
      ),
    );
  }

  Widget _profileHeader(BuildContext context, ChannelPageData channel) {
    final colors = Theme.of(context).colorScheme;
    final meta = _channelMeta(channel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChannelAvatar(
                name: channel.name,
                url: channel.avatarUrl,
                size: AppSizes.avatarLg,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.pageTitle.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.meta.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (channel.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => _selectTab('About'),
              child: Text(
                channel.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.meta.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppSubscribedButton(
              isSubscribed: isSubscribed,
              size: AppButtonSize.large,
              onPressed: _onSubscribePressed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBody(BuildContext context, String tab, ChannelPageData channel) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical &&
            notification.metrics.extentAfter <
                AppSizes.compactRowMinHeight * 4) {
          unawaited(_loadMore(tab));
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _refreshTab(tab),
        child: CustomScrollView(
          key: PageStorageKey<String>('channel_${channel.id}_$tab'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: _tabSlivers(context, tab, channel),
        ),
      ),
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    String tab,
    ChannelPageData channel,
  ) {
    final items = _itemsByTab[tab] ?? const <dynamic>[];
    final videos = items.whereType<VideoItem>().toList(growable: false);
    final shorts = items.whereType<ShortItem>().toList(growable: false);
    final slivers = <Widget>[];
    if (partialError != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: InlineBanner(
            message: partialError!,
            actionLabel: 'Retry',
            onAction: () => _refreshTab(tab),
          ),
        ),
      );
    }

    if (tab == 'About') {
      slivers.addAll(_aboutSlivers(context, channel));
      slivers.add(_bottomInset(context));
      return slivers;
    }

    if (_loadingTabs.contains(tab) && !_loadedTabs.contains(tab)) {
      slivers.add(const SliverToBoxAdapter(child: _ChannelTabSkeleton()));
      slivers.add(_bottomInset(context));
      return slivers;
    }

    if (tab == 'Home') {
      if (videos.isNotEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Latest videos',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
            ),
          ),
        );
        slivers.add(
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  AppSizes.trendingCardW / AppSpacing.thumbnailRatio +
                  AppSpacing.xxxl * 2,
              child: ListView.separated(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: videos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) => SizedBox(
                  width: AppSizes.trendingCardW,
                  child: VideoCard.grid(
                    key: ValueKey(videos[index].id),
                    video: videos[index],
                    onTap: () => openWatchPanel(ref, videos[index].id),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (shorts.isNotEmpty) slivers.add(_shortsShelfSliver(shorts));
      if (videos.isEmpty && shorts.isEmpty) {
        slivers.add(
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LucideIcons.video,
              title: 'This channel has no videos',
            ),
          ),
        );
      }
    } else if (tab == 'Videos') {
      if (channel.sortChips.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: AppChipBar(
              children: [
                for (final chip in channel.sortChips)
                  AppChip(
                    label: chip.label,
                    selected: _sortByTab['Videos'] == chip.params,
                    onTap: () => _selectSort(chip.params),
                  ),
              ],
            ),
          ),
        );
      }
      if (videos.isEmpty && !_loadingTabs.contains(tab)) {
        slivers.add(
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LucideIcons.video,
              title: 'This channel has no videos',
            ),
          ),
        );
      } else {
        slivers.add(
          SliverList.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) => Padding(
              key: ValueKey(videos[index].id),
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: VideoCard.feed(
                video: videos[index],
                onTap: () => openWatchPanel(ref, videos[index].id),
              ),
            ),
          ),
        );
      }
    } else if (tab == 'Shorts') {
      if (shorts.isEmpty && !_loadingTabs.contains(tab)) {
        slivers.add(
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(icon: LucideIcons.play, title: 'No Shorts'),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            sliver: SliverGrid.builder(
              itemCount: shorts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
                childAspectRatio: AppSpacing.homeShortRatio,
              ),
              itemBuilder: (context, index) => _ShortTile(
                item: shorts[index],
                onTap: () => _openShorts(shorts, index),
              ),
            ),
          ),
        );
      }
    }

    if (loadingMore && _selectedTab == tab) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: SizedBox.square(
                dimension: AppSizes.icon,
                child: CircularProgressIndicator(strokeWidth: AppSpacing.xxs),
              ),
            ),
          ),
        ),
      );
    }
    slivers.add(_bottomInset(context));
    return slivers;
  }

  Widget _shortsShelfSliver(List<ShortItem> shorts) => SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Shorts',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
        ),
        SizedBox(
          height: AppSizes.shortShelfCardW * 1.5,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: shorts.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => SizedBox(
              width: AppSizes.shortShelfCardW,
              child: _ShortTile(
                item: shorts[index],
                onTap: () => _openShorts(shorts, index),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _aboutSlivers(BuildContext context, ChannelPageData channel) {
    final values = <({String label, String value})>[
      if (channel.description.isNotEmpty)
        (label: 'Description', value: channel.description),
      if (channel.handle.isNotEmpty) (label: 'Handle', value: channel.handle),
      if (channel.subscribersText.isNotEmpty)
        (label: 'Subscribers', value: channel.subscribersText),
      if (channel.videosCountText.isNotEmpty)
        (label: 'Videos', value: channel.videosCountText),
      (label: 'Channel ID', value: channel.id),
    ];
    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        sliver: SliverList.builder(
          itemCount: values.length,
          itemBuilder: (context, index) =>
              _AboutRow(label: values[index].label, value: values[index].value),
        ),
      ),
    ];
  }

  Widget _bottomInset(BuildContext context) => SliverBottomInset(
    extra: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.settingsTitle.copyWith(
              color: colors.onSurface,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.settingsSub.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortTile extends StatelessWidget {
  const _ShortTile({required this.item, required this.onTap});
  final ShortItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: AppRadius.smBorder,
      child: Material(
        color: colors.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: colors.surfaceContainerHighest),
                errorWidget: (_, _, _) =>
                    ColoredBox(color: colors.surfaceContainerHighest),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: AppColors.scrim,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      item.viewsText ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelTabSkeleton extends StatelessWidget {
  const _ChannelTabSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(
          width: AppSizes.trendingCardW / 2,
          height: AppTextStyles.sectionTitle.fontSize!,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < 3; i++) ...[
          const AspectRatio(
            aspectRatio: AppSpacing.thumbnailRatio,
            child: SkeletonBox(
              height: double.infinity,
              borderRadius: AppRadius.md,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    ),
  );
}

class _ChannelLoadingScreen extends StatelessWidget {
  const _ChannelLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSizes.topBar + AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  const SkeletonBox(
                    width: AppSizes.avatarLg,
                    height: AppSizes.avatarLg,
                    borderRadius: AppSizes.avatarLg / 2,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: AppTextStyles.pageTitle.fontSize!),
                        const SizedBox(height: AppSpacing.xs),
                        SkeletonBox(
                          width: AppSizes.compactThumbW,
                          height: AppTextStyles.meta.fontSize!,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SkeletonBox(
                height: AppSizes.buttonLarge,
                borderRadius: AppRadius.pill,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.lg),
                    const SkeletonBox(width: AppSizes.compactThumbW / 4),
                  ],
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: AppSizes.trendingCardW / 2,
                    height: AppTextStyles.sectionTitle.fontSize!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height:
                        AppSizes.trendingCardW / AppSpacing.thumbnailRatio +
                        AppSpacing.xxxl * 2,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 2,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, _) => const SizedBox(
                        width: AppSizes.trendingCardW,
                        child: SkeletonBox(
                          height:
                              AppSizes.trendingCardW /
                              AppSpacing.thumbnailRatio,
                          borderRadius: AppRadius.md,
                        ),
                      ),
                    ),
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
