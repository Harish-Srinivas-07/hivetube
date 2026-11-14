import 'dart:async';

import 'package:flutter/material.dart';
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
  String _query = '';
  final Map<String, String> _notificationModes = {};
  final Set<String> _loadingModes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _notificationKey(String channelId) =>
      'subscription_notifications_$channelId';

  void _loadNotificationModes(List<SubscriptionRow> subscriptions) {
    for (final subscription in subscriptions) {
      if (_notificationModes.containsKey(subscription.channelId) ||
          !_loadingModes.add(subscription.channelId)) {
        continue;
      }
      unawaited(() async {
        final value = await ref
            .read(dbProvider)
            .getValue(_notificationKey(subscription.channelId));
        if (mounted) {
          setState(() {
            _notificationModes[subscription.channelId] =
                value ?? 'Personalized';
            _loadingModes.remove(subscription.channelId);
          });
        }
      }());
    }
  }

  Future<void> _openNotificationSheet(SubscriptionRow subscription) async {
    final channelId = subscription.channelId;
    final current = _notificationModes[channelId] ?? 'Personalized';
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('Notifications', style: AppTextStyles.sectionTitle),
            ),
            for (final option in const ['All', 'Personalized', 'None'])
              ListTile(
                leading: Icon(
                  option == 'None' ? LucideIcons.bellOff : LucideIcons.bell,
                ),
                title: Text(option, style: AppTextStyles.body),
                trailing: option == current
                    ? Icon(
                        LucideIcons.check,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(dbProvider).setValue(_notificationKey(channelId), selected);
    if (mounted) {
      setState(() => _notificationModes[channelId] = selected);
    }
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
      if (mounted) {
        setState(() => _notificationModes.remove(subscription.channelId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionsStreamProvider);
    final subscriptions = subscriptionsAsync.asData?.value;
    if (subscriptions != null) _loadNotificationModes(subscriptions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage subscriptions'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'takeout') {
                unawaited(importSubscriptionsFromTakeout(context, ref));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'takeout',
                child: Text('Import from Google Takeout'),
              ),
            ],
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
                style: AppTextStyles.settingsTitle,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  hintText: 'Search subscriptions',
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: AppSizes.iconSm,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: AppSizes.touchMin,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
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
                    notificationMode:
                        _notificationModes[filtered[index].channelId] ??
                        'Personalized',
                    onNotifications: () =>
                        _openNotificationSheet(filtered[index]),
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
    required this.notificationMode,
    required this.onNotifications,
    required this.onUnsubscribe,
  });

  final SubscriptionRow subscription;
  final String notificationMode;
  final VoidCallback onNotifications;
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
              tooltip: 'Notifications: $notificationMode',
              constraints: const BoxConstraints.tightFor(
                width: AppSizes.buttonIconTouch,
                height: AppSizes.buttonIconTouch,
              ),
              onPressed: onNotifications,
              icon: const Icon(LucideIcons.bell, size: AppSizes.iconSm),
            ),
            PopupMenuButton<String>(
              tooltip: 'Channel options',
              onSelected: (value) {
                if (value == 'unsubscribe') onUnsubscribe();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'unsubscribe', child: Text('Unsubscribe')),
              ],
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
