import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../core/providers.dart';
import '../../core/yt/channel_metadata.dart';
import '../../widgets/common.dart';

class ManageSubscriptionsScreen extends ConsumerStatefulWidget {
  const ManageSubscriptionsScreen({super.key});

  @override
  ConsumerState<ManageSubscriptionsScreen> createState() =>
      _ManageSubscriptionsScreenState();
}

class _ManageSubscriptionsScreenState
    extends ConsumerState<ManageSubscriptionsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(subscriptionsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscriptions'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search subscriptions...',
                prefixIcon: const Icon(LucideIcons.search, size: AppSizes.iconMd),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: subsAsync.when(
              data: (subs) {
                final filtered = subs.where((s) {
                  if (_query.isEmpty) return true;
                  return s.name.toLowerCase().contains(_query) ||
                      s.channelId.toLowerCase().contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No subscriptions'
                          : 'No matching subscriptions',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final sub = filtered[idx];
                    final displayName = isMissingChannelName(
                      sub.name,
                      sub.channelId,
                    )
                        ? 'Channel'
                        : sub.name;
                    return ListTile(
                      leading: Avatar(
                        name: displayName,
                        url: sub.avatarUrl,
                        size: AppSizes.avatar,
                      ),
                      title: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        sub.channelId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Unsubscribe'),
                              content: Text(
                                'Unsubscribe from $displayName?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dCtx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(dCtx).pop(true),
                                  child: const Text('Unsubscribe'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(dbProvider)
                                .subscriptionsDao
                                .unsubscribe(sub.channelId);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Unsubscribe'),
                      ),
                      onTap: () => context.push('/channel/${sub.channelId}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
