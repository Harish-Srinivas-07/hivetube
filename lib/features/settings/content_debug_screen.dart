import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/content/home_trace.dart';
import '../../core/providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
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

  void _showDiagnosticSheet(HomeTraceItem item) {
    final details = <String, String>{
      'Status': item.kept ? 'Kept' : 'Dropped',
      'Language': item.finalLanguage.toUpperCase(),
      'Source': item.source,
      'Channel': item.channelName,
      'Script verdict': item.scriptVerdict ?? 'None (Latin / neutral)',
      'Lexicon hits': item.lexiconVerdict == null
          ? 'None'
          : '${item.lexiconVerdict} (${item.matchedWords.join(", ")})',
      'Channel votes': item.channelVoteVerdict ?? 'No prior votes',
      'Probe result': item.probeVerdict ?? 'Not probed / timed out',
      'Final verdict': item.finalLanguage.toUpperCase(),
      'Filter reason': item.reason,
      'Ambiguous Latin': item.isAmbiguous ? 'Yes' : 'No',
    };
    showAppSheet<void>(
      context,
      title: 'Diagnostic Details',
      builder: (ctx, controller) => ListView(
        controller: controller,
        children: [
          ListTile(title: Text(item.title, style: AppTextStyles.settingsTitle)),
          for (final entry in details.entries)
            ListTile(
              title: Text(entry.key, style: AppTextStyles.settingsTitle),
              subtitle: Text(
                entry.value,
                style: AppTextStyles.settingsSub.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final traces = HomeTraceStore.instance.traces.reversed.take(60).toList();
    final colors = Theme.of(context).colorScheme;
    final filtered = traces
        .where(
          (t) => switch (_activeFilter) {
            TraceFilter.all => true,
            TraceFilter.kept => t.kept,
            TraceFilter.dropped => !t.kept,
            TraceFilter.ambiguous => t.isAmbiguous,
          },
        )
        .toList();
    final languages = <String, int>{};
    var mismatches = 0;
    for (final trace in traces) {
      languages.update(
        trace.finalLanguage,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (!trace.kept &&
          trace.probeVerdict != null &&
          trace.probeVerdict != trace.finalLanguage) {
        mismatches++;
      }
    }
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
              return ListTile(
                title: Text(
                  terms?.isEmpty != false
                      ? 'Mined Tamil terms: none verified yet'
                      : 'Mined Tamil terms (review): ${terms!.map((e) => '${e.term} ×${e.seenCount}').join(', ')}',
                  style: AppTextStyles.settingsSub,
                ),
              );
            },
          ),
          ListTile(
            title: Text(
              'Total: ${traces.length} · Kept: ${traces.where((t) => t.kept).length} · Dropped: ${traces.where((t) => !t.kept).length}',
              style: AppTextStyles.settingsTitle,
            ),
            subtitle: Text(
              'Mismatches: $mismatches · Languages: ${languages.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
              style: AppTextStyles.settingsSub.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                for (final filter in TraceFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: AppChip(
                      label: switch (filter) {
                        TraceFilter.all => 'All',
                        TraceFilter.kept => 'Kept',
                        TraceFilter.dropped => 'Dropped',
                        TraceFilter.ambiguous => 'Ambiguous',
                      },
                      selected: _activeFilter == filter,
                      onTap: () => setState(() => _activeFilter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No trace items match filter.',
                      style: AppTextStyles.body.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final trace = filtered[index];
                      return ListTile(
                        onTap: () => _showDiagnosticSheet(trace),
                        title: Text(
                          trace.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.settingsTitle,
                        ),
                        subtitle: Text(
                          '${trace.channelName} · ${trace.kept ? 'KEPT' : 'DROPPED'} · ${trace.finalLanguage.toUpperCase()} · ${trace.source}${trace.isAmbiguous ? ' · AMBIGUOUS' : ''}\n${trace.reason}',
                          style: AppTextStyles.settingsSub.copyWith(
                            color: colors.onSurfaceVariant,
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
