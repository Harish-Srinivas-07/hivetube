import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/yt/models.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final controller = ScrollController();
  String chip = 'All';
  static const chips = ['All', 'Live', 'Gaming', 'Podcasts', 'Music', 'News'];
  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.offset > 0) ref.read(homeProvider.notifier).touched = true;
      if (controller.position.extentAfter < AppSpacing.xxxl) {
        ref.read(homeProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                for (final item in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(item),
                      selected: chip == item,
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.onSurface,
                      labelStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            color: chip == item
                                ? Theme.of(context).colorScheme.surface
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                      onSelected: (_) {
                        setState(() => chip = item);
                        ref.read(homeProvider.notifier).select(item);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: home.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load Home'),
                    TextButton(
                      onPressed: () =>
                          ref.read(homeProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () => ref.read(homeProvider.notifier).refresh(),
                child: CustomScrollView(
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (data.shorts.isNotEmpty)
                      SliverToBoxAdapter(child: _Shorts(items: data.shorts)),
                    if (data.trending.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _Heading('Trending')),
                      _grid(data.trending),
                    ],
                    if (data.errors.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TextButton(
                          onPressed: () =>
                              ref.read(homeProvider.notifier).refresh(),
                          child: Text('Some sections could not load. Retry'),
                        ),
                      ),
                    if (data.videos.isEmpty &&
                        data.trending.isEmpty &&
                        data.shorts.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: Text('No videos found')),
                      ),
                    _grid(data.videos),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<VideoItem> items) => SliverPadding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    sliver: SliverLayoutBuilder(
      builder: (context, constraints) {
        final count =
            constraints.crossAxisExtent < AppSpacing.navigationBreakpoint
            ? 1
            : (constraints.crossAxisExtent / AppSpacing.videoMaxWidth).ceil();
        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _VideoCard(items[index]),
            childCount: items.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent:
                (constraints.crossAxisExtent - (count - 1) * AppSpacing.lg) /
                    count /
                    AppSpacing.thumbnailRatio +
                AppSpacing.xxxl +
                AppSpacing.xxxl,
          ),
        );
      },
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _VideoCard extends StatelessWidget {
  const _VideoCard(this.item);
  final VideoItem item;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {},
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: AppSpacing.thumbnailRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: CachedNetworkImage(
                  imageUrl: item.thumbUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (item.durationText.isNotEmpty)
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: AppRadius.xsBorder,
                    ),
                    child: Text(
                      item.durationText,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          [
            item.channelName,
            item.viewsText,
            item.publishedText,
          ].where((s) => s.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _Shorts extends StatelessWidget {
  const _Shorts({required this.items});
  final List<ShortItem> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading('Shorts'),
      SizedBox(
        height: AppSpacing.shortWidth / AppSpacing.shortRatio,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => InkWell(
            onTap: () {},
            child: SizedBox(
              width: AppSpacing.shortWidth,
              child: ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: CachedNetworkImage(
                  imageUrl: items[index].thumbUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
