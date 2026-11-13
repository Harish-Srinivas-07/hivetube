import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/content/home_trace.dart';
import '../../core/providers.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui/ui.dart';

enum TraceFilter { all, kept, dropped, ambiguous }

class ContentDebugScreen extends StatefulWidget {
  const ContentDebugScreen({super.key});

  @override
  State<ContentDebugScreen> createState() => _ContentDebugScreenState();
}

class _ContentDebugScreenState extends State<ContentDebugScreen> {
  TraceFilter _activeFilter = TraceFilter.all;

  @override
  void initState() {
    super.initState();
    HomeTraceStore.instance.addListener(_onTraceChanged);
  }

  @override
  void dispose() {
    HomeTraceStore.instance.removeListener(_onTraceChanged);
    super.dispose();
  }

  void _onTraceChanged() {
    if (mounted) setState(() {});
  }

  void _showDiagnosticSheet(BuildContext context, HomeTraceItem item) {
    final colors = Theme.of(context).colorScheme;
    showAppSheet<void>(
      context,
      fit: true,
      title: 'Diagnostic Details',
      builder: (ctx, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: item.kept
                        ? colors.primaryContainer
                        : colors.errorContainer,
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Text(
                    item.kept ? 'KEPT' : 'DROPPED',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: item.kept
                          ? colors.onPrimaryContainer
                          : colors.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Text(
                    item.finalLanguage.toUpperCase(),
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.source,
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.title,
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Channel: ${item.channelName}',
              style: Theme.of(
                ctx,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const AppDivider(),
            _diagRow(
              ctx,
              'Script verdict',
              item.scriptVerdict ?? 'None (Latin / neutral)',
            ),
            _diagRow(
              ctx,
              'Lexicon hits',
              item.lexiconVerdict == null
                  ? 'None'
                  : '${item.lexiconVerdict} (${item.matchedWords.join(", ")})',
            ),
            _diagRow(
              ctx,
              'Channel votes',
              item.channelVoteVerdict ?? 'No prior votes',
            ),
            _diagRow(
              ctx,
              'Probe result',
              item.probeVerdict ?? 'Not probed / timed out',
            ),
            _diagRow(ctx, 'Final verdict', item.finalLanguage.toUpperCase()),
            _diagRow(ctx, 'Filter reason', item.reason),
            _diagRow(ctx, 'Ambiguous Latin', item.isAmbiguous ? 'Yes' : 'No'),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTraces = HomeTraceStore.instance.traces.reversed.take(60).toList();
    final colors = Theme.of(context).colorScheme;

    // Compute summary stats
    final total = allTraces.length;
    final keptCount = allTraces.where((t) => t.kept).length;
    final droppedCount = allTraces.where((t) => !t.kept).length;
    final byLang = <String, int>{};
    var mismatchCount = 0;
    for (final t in allTraces) {
      byLang.update(t.finalLanguage, (c) => c + 1, ifAbsent: () => 1);
      if (!t.kept &&
          t.probeVerdict != null &&
          t.probeVerdict != t.finalLanguage) {
        mismatchCount++;
      }
    }

    final filteredTraces = allTraces.where((t) {
      return switch (_activeFilter) {
        TraceFilter.all => true,
        TraceFilter.kept => t.kept,
        TraceFilter.dropped => !t.kept,
        TraceFilter.ambiguous => t.isAmbiguous,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Debug - Home Trace'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: 'Copy trace log dump',
            onPressed: () {
              final log = HomeTraceStore.instance.dumpLog();
              Clipboard.setData(ClipboardData(text: log));
              debugPrint(log);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Trace log copied to clipboard & printed to console',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: 'Clear trace',
            onPressed: () {
              HomeTraceStore.instance.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trace log cleared')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder(
            future: ProviderScope.containerOf(
              context,
            ).read(discoveryStoreProvider).topTerms('ta', limit: 20),
            builder: (context, snapshot) {
              final terms = snapshot.data;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                color: colors.secondaryContainer.withAlpha(70),
                child: Text(
                  terms?.isEmpty != false
                      ? 'Mined Tamil terms: none verified yet'
                      : 'Mined Tamil terms (review): ${terms!.map((e) => '${e.term} ×${e.seenCount}').join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            },
          ),
          // Summary row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: colors.surfaceContainerHighest.withAlpha(80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total: $total',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Kept: $keptCount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Dropped: $droppedCount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (mismatchCount > 0)
                      Text(
                        'Mismatches: $mismatchCount',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: colors.error),
                      ),
                  ],
                ),
                if (byLang.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Languages: ${byLang.entries.map((e) => "${e.key}: ${e.value}").join(", ")}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                AppChip(
                  label: 'All',
                  selected: _activeFilter == TraceFilter.all,
                  onTap: () => setState(() => _activeFilter = TraceFilter.all),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: 'Kept',
                  selected: _activeFilter == TraceFilter.kept,
                  onTap: () => setState(() => _activeFilter = TraceFilter.kept),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: 'Dropped',
                  selected: _activeFilter == TraceFilter.dropped,
                  onTap: () =>
                      setState(() => _activeFilter = TraceFilter.dropped),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppChip(
                  label: 'Ambiguous',
                  selected: _activeFilter == TraceFilter.ambiguous,
                  onTap: () =>
                      setState(() => _activeFilter = TraceFilter.ambiguous),
                ),
              ],
            ),
          ),

          // Trace list
          Expanded(
            child: filteredTraces.isEmpty
                ? Center(
                    child: Text(
                      'No trace items match filter.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filteredTraces.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final trace = filteredTraces[index];
                      return InkWell(
                        onTap: () => _showDiagnosticSheet(context, trace),
                        borderRadius: AppRadius.smBorder,
                        child: Material(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: AppRadius.smBorder,
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: trace.kept
                                            ? colors.primaryContainer
                                            : colors.errorContainer,
                                        borderRadius: AppRadius.xsBorder,
                                      ),
                                      child: Text(
                                        trace.kept ? 'KEPT' : 'DROPPED',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: trace.kept
                                                  ? colors.onPrimaryContainer
                                                  : colors.onErrorContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerHighest,
                                        borderRadius: AppRadius.xsBorder,
                                      ),
                                      child: Text(
                                        trace.finalLanguage.toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    if (trace.isAmbiguous) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs,
                                          vertical: AppSpacing.xxs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.tertiaryContainer,
                                          borderRadius: AppRadius.xsBorder,
                                        ),
                                        child: Text(
                                          'AMBIGUOUS',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color:
                                                    colors.onTertiaryContainer,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      trace.source,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  trace.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  trace.channelName,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    if (trace.scriptVerdict != null)
                                      Text(
                                        'script: ${trace.scriptVerdict}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    if (trace.lexiconVerdict != null)
                                      Text(
                                        'lex: ${trace.lexiconVerdict}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    if (trace.channelVoteVerdict != null)
                                      Text(
                                        'channelVotes: ${trace.channelVoteVerdict}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    if (trace.probeVerdict != null)
                                      Text(
                                        'probe: ${trace.probeVerdict}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    Text(
                                      'reason: ${trace.reason}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: colors.outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}
