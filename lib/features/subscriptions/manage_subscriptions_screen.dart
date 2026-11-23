import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/channel_metadata.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../watch/mini_player_inset.dart';
import '../../widgets/common/common.dart';
import '../../widgets/ui/app_controls.dart';
import '../../widgets/ui/app_states.dart';
import 'takeout_import.dart';

class ManageSubscriptionsScreen extends ConsumerStatefulWidget {
  const ManageSubscriptionsScreen({super.key});

  @override
  ConsumerState<ManageSubscriptionsScreen> createState() =>
      _ManageSubscriptionsScreenState();
}

class _ManageSubscriptionsScreenState
    extends ConsumerState<ManageSubscriptionsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _confirmUnsubscribe(SubscriptionRow subscription) async {
    final name = isMissingChannelName(subscription.name, subscription.channelId)
        ? 'Channel'
        : subscription.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unsubscribe', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.md),
              Text('Unsubscribe from $name?', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.text(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.filled(
                    label: 'Unsubscribe',
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await ref
          .read(dbProvider)
          .subscriptionsDao
          .unsubscribe(subscription.channelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage subscriptions'),
        actions: [
          IconButton(
            tooltip: 'Import subscriptions from Google Takeout',
            onPressed: () =>
                unawaited(importSubscriptionsFromTakeout(context, ref)),
            icon: const Icon(LucideIcons.fileUp),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SizedBox(
              height: AppSpacing.searchHeight,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onTapOutside: (_) => _searchFocusNode.unfocus(),
                cursorColor: Theme.of(context).colorScheme.primary,
                textAlignVertical: TextAlignVertical.center,
                style: AppTextStyles.settingsTitle,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  hintText: 'Search subscriptions',
                  hintStyle: AppTextStyles.settingsTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: AppSizes.iconSm,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: AppSizes.touchMin,
                    minHeight: AppSpacing.searchHeight,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: AppSizes.touchMin - AppSpacing.sm,
                            height: AppSpacing.searchHeight,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close, size: AppSizes.iconSm),
                        ),
                  suffixIconConstraints: const BoxConstraints.tightFor(
                    width: AppSizes.touchMin - AppSpacing.sm,
                    height: AppSpacing.searchHeight,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.none,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.pillBorder,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.pillBorder,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.pillBorder,
                    borderSide: BorderSide.none,
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.pillBorder,
                    borderSide: BorderSide.none,
                  ),
                  disabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.pillBorder,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: subscriptionsAsync.when(
              data: (subscriptions) {
                final filtered = subscriptions.where((subscription) {
                  if (_query.isEmpty) return true;
                  return subscription.name.toLowerCase().contains(_query) ||
                      subscription.handle.toLowerCase().contains(_query) ||
                      subscription.channelId.toLowerCase().contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: _query.isEmpty
                        ? LucideIcons.bellOff
                        : LucideIcons.search,
                    title: _query.isEmpty
                        ? 'No subscriptions yet'
                        : 'No channels found',
                    hint: _query.isEmpty
                        ? 'Subscribe to channels to manage them here'
                        : 'Try another channel name or handle',
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom +
                        AppSizes.bottomNav +
                        MiniPlayerInset.of(context) +
                        AppSpacing.lg,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ManageSubscriptionRow(
                    subscription: filtered[index],
                    onUnsubscribe: () => _confirmUnsubscribe(filtered[index]),
                  ),
                );
              },
              loading: () => const _ManageSubscriptionsSkeleton(),
              error: (error, _) => ErrorRetry(
                message: 'Unable to load subscriptions.',
                onRetry: () => ref.invalidate(subscriptionsStreamProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageSubscriptionRow extends StatelessWidget {
  const _ManageSubscriptionRow({
    required this.subscription,
    required this.onUnsubscribe,
  });

  final SubscriptionRow subscription;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final name = isMissingChannelName(subscription.name, subscription.channelId)
        ? 'Channel'
        : subscription.name;
    final handle = subscription.handle.isNotEmpty
        ? subscription.handle
        : subscription.channelId;

    return InkWell(
      onTap: () => context.push('/channel/${subscription.channelId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            ChannelAvatar(
              name: name,
              url: subscription.avatarUrl,
              size: AppSizes.manageSubscriptionAvatar,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong,
                  ),
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Unsubscribe',
              constraints: const BoxConstraints.tightFor(
                width: AppSizes.buttonIconTouch,
                height: AppSizes.buttonIconTouch,
              ),
              onPressed: onUnsubscribe,
              icon: const Icon(LucideIcons.unlink, size: AppSizes.iconSm),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageSubscriptionsSkeleton extends StatelessWidget {
  const _ManageSubscriptionsSkeleton();

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: 8,
    itemBuilder: (_, _) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: AppSizes.manageSubscriptionAvatar,
            height: AppSizes.manageSubscriptionAvatar,
            borderRadius: AppSizes.manageSubscriptionAvatar / 2,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: AppSizes.libraryHistoryCardWidth,
                  height: AppSizes.iconXs,
                ),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(
                  width: AppSizes.searchCompactThumbnailWidth,
                  height: AppSizes.iconXs,
                ),
              ],
            ),
          ),
          const SizedBox(
            width: AppSizes.buttonIconTouch,
            height: AppSizes.buttonIconTouch,
            child: Center(
              child: SkeletonBox(
                width: AppSizes.iconSm,
                height: AppSizes.iconSm,
                borderRadius: AppRadius.pill,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.buttonIconTouch),
        ],
      ),
    ),
  );
}
