import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/settings/app_settings.dart';
import '../features/home/home_variety.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'ui/ui.dart';

Future<void> showContentLanguageSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final initial = ref.read(contentPrefsProvider);
  var shown = Set<String>.of(initial.contentLanguages);
  var hidden = Set<String>.of(initial.hiddenLanguages);
  var region = initial.gl;
  var localRatio = initial.localRatio;
  var showHint = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    constraints: BoxConstraints(
      maxHeight:
          MediaQuery.sizeOf(context).height *
          AppSpacing.contentSheetMaxHeightFactor,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 1,
      minChildSize: AppSpacing.contentSheetMinExtent,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setSheetState) {
          void setShown(String code, bool value) {
            setSheetState(() {
              showHint = false;
              if (value) {
                shown.add(code);
                hidden.remove(code);
                return;
              }
              shown.remove(code);
              if (shown.isEmpty) {
                shown.add('en');
                hidden.remove('en');
                showHint = true;
              }
            });
          }

          void setHidden(String code, bool value) {
            setSheetState(() {
              showHint = false;
              if (!value) {
                hidden.remove(code);
                return;
              }
              if (shown.length == 1 && shown.contains(code)) {
                showHint = true;
                return;
              }
              hidden.add(code);
              shown.remove(code);
            });
          }

          Future<void> chooseRegion() async {
            final selected = await showAppSheet<String>(
              context,
              title: 'Choose region',
              builder: (pickerContext, scrollController) => ListView(
                controller: scrollController,
                children: [
                  for (final entry in regions.entries)
                    ListTile(
                      key: ValueKey('contentRegion_${entry.key}'),
                      title: Text(entry.value),
                      trailing: entry.key == region
                          ? Icon(
                              LucideIcons.check,
                              color: Theme.of(
                                pickerContext,
                              ).colorScheme.primary,
                            )
                          : null,
                      onTap: () =>
                          Navigator.pop(pickerContext, entry.key),
                    ),
                ],
              ),
            );
            if (selected != null) {
              setSheetState(() => region = selected);
            }
          }

          final colors = Theme.of(context).colorScheme;
          return Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: AppSpacing.contentSheetHandleWidth,
                          height: AppSpacing.contentSheetHandleHeight,
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: .45,
                            ),
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Content language',
                        key: const ValueKey('contentLanguageSheetTitle'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Choose what Home, Shorts and suggestions show.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    children: [
                      Text(
                        'Languages',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final entry in contentLanguageOptions.entries)
                        _LanguageRow(
                          code: entry.key,
                          englishName: entry.value,
                          isShown: shown.contains(entry.key),
                          isHidden: hidden.contains(entry.key),
                          onShow: (value) => setShown(entry.key, value),
                          onHide: (value) => setHidden(entry.key, value),
                        ),
                      if (showHint)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            'Keep at least one language shown. English was restored.',
                            key: const ValueKey('contentLanguageHint'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.primary),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          bottom: AppSpacing.md,
                        ),
                        child: Text(
                          'Other covers Latin-script languages such as Spanish and French. They are recognized from query bias and language keywords only.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Region',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ListTile(
                        key: const ValueKey('contentPrefsRegion'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(regions[region] ?? region),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: chooseRegion,
                      ),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Mix',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _MixChoice(
                            label: 'More local',
                            value: .8,
                            selected: localRatio == .8,
                            onTap: () => setSheetState(() => localRatio = .8),
                          ),
                          _MixChoice(
                            label: 'Balanced',
                            value: .6,
                            selected: localRatio == .6,
                            onTap: () => setSheetState(() => localRatio = .6),
                          ),
                          _MixChoice(
                            label: 'More global',
                            value: .4,
                            selected: localRatio == .4,
                            onTap: () => setSheetState(() => localRatio = .4),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          'Local topics ${(localRatio * 100).round()}% · Global ${(100 - localRatio * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      AppButton.text(
                        key: const ValueKey('contentPrefsReset'),
                        label: 'Reset to default',
                        onPressed: () => setSheetState(() {
                          shown = {'ta', 'en'};
                          hidden = {'hi'};
                          region = 'IN';
                          localRatio = .6;
                          showHint = false;
                        }),
                      ),
                      const Spacer(),
                      AppButton.filled(
                        key: const ValueKey('contentPrefsDone'),
                        label: 'Done',
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  await ref
      .read(contentPrefsProvider.notifier)
      .update(
        contentLanguages: shown,
        hiddenLanguages: hidden,
        gl: region,
        localRatio: localRatio,
      );
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.code,
    required this.englishName,
    required this.isShown,
    required this.isHidden,
    required this.onShow,
    required this.onHide,
  });
  final String code, englishName;
  final bool isShown, isHidden;
  final ValueChanged<bool> onShow, onHide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSpacing.contentLanguageRowHeight,
      child: Row(
        children: [
          Tooltip(
            message: 'Show $englishName',
            child: Checkbox(
              key: ValueKey('showLanguage_$code'),
              value: isShown,
              onChanged: (value) => onShow(value ?? false),
            ),
          ),
          Expanded(
            child: Text(
              englishName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            key: ValueKey('hideLanguage_$code'),
            tooltip: isHidden ? 'Unhide $englishName' : 'Hide $englishName',
            onPressed: () => onHide(!isHidden),
            icon: Icon(
              isHidden ? LucideIcons.eyeOff : LucideIcons.eye,
              color: isHidden ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MixChoice extends StatelessWidget {
  const _MixChoice({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: AppChip(
        key: ValueKey('contentMix_$value'),
        label: label,
        selected: selected,
        onTap: onTap,
      ),
    ),
  );
}
