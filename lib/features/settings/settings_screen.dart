import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/settings/app_settings.dart';
import '../../core/providers.dart';
import '../home/home_controller.dart';
import '../home/home_screen.dart';
import '../home/home_variety.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../watch/mini_player_inset.dart';
import '../../widgets/ui/ui.dart';
import 'content_debug_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(contentPrefsProvider);
    Future<void> clearDatabase() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: 'Clear app database?',
          content: const Text(
            'This permanently removes saved settings, watch history, cached feed data, and channel avatars from this device.',
          ),
          actions: [
            AppButton.text(
              onPressed: () => Navigator.pop(dialogContext, false),
              label: 'Cancel',
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Clear',
                style: AppTextStyles.buttonLabel.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await ref.read(dbProvider).clearAppData();
      ref.read(channelAvatarCacheProvider).clearMemory();
      ref.read(contentPrefsProvider.notifier).resetAfterDatabaseClear();
      ref.invalidate(homeHistoryProvider);
      ref.invalidate(homeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App database cleared')));
      }
    }

    Future<void> pick(
      String title,
      Map<String, String> values,
      String current,
      Future<void> Function(String) update,
    ) async {
      var selected = current;
      await showAppSheet<void>(
        context,
        title: title,
        builder: (sheetContext, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) async {
              if (value == null) return;
              setSheetState(() => selected = value);
              await update(value);
              await Future<void>.delayed(AppMotion.imageFade);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
            child: ListView(
              controller: scrollController,
              children: [
                for (final entry in values.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    title: Text(
                      entry.value,
                      style: AppTextStyles.settingsTitle,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> pickLanguages(
      String title,
      Set<String> selected,
      bool hidden,
    ) async {
      final draft = selected.toSet();
      final result = await showAppSheet<Set<String>>(
        context,
        title: title,
        builder: (sheetContext, scrollController) => StatefulBuilder(
          builder: (context, setDialogState) => Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    for (final option in contentLanguageOptions.entries)
                      CheckboxListTile(
                        title: Text(
                          option.value,
                          style: AppTextStyles.settingsTitle,
                        ),
                        value: draft.contains(option.key),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            draft.add(option.key);
                          } else {
                            draft.remove(option.key);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton.text(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                    AppButton.tonal(
                      label: 'Save',
                      onPressed: () => Navigator.pop(sheetContext, draft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (result == null || result.isEmpty) return;
      final controller = ref.read(contentPrefsProvider.notifier);
      await controller.update(
        contentLanguages: hidden ? null : result,
        hiddenLanguages: hidden ? result : null,
      );
    }

    Widget section(String title) => SectionHeader(
      title: title,
      titleStyle: AppTextStyles.bodySmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
    );

    Widget settingTile({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) => SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );

    Widget switchTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.paddingOf(context).bottom +
              MiniPlayerInset.of(context) +
              AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            section('General'),
            settingTile(
              icon: LucideIcons.mapPin,
              title: 'Location',
              subtitle: regions[settings.gl] ?? settings.gl,
              onTap: () => pick(
                'Location',
                regions,
                settings.gl,
                (value) =>
                    ref.read(contentPrefsProvider.notifier).update(gl: value),
              ),
            ),
            switchTile(
              icon: LucideIcons.map,
              title: 'Local content',
              subtitle: settings.localContent ? 'On' : 'Off',
              value: settings.localContent,
              onChanged: (value) => ref
                  .read(contentPrefsProvider.notifier)
                  .update(localContent: value),
            ),
            settingTile(
              icon: LucideIcons.languages,
              title: 'Content languages',
              subtitle: settings.contentLanguages
                  .map((code) => contentLanguageOptions[code] ?? code)
                  .join(', '),
              onTap: () => pickLanguages(
                'Content languages',
                settings.contentLanguages,
                false,
              ),
            ),
            settingTile(
              icon: LucideIcons.eyeOff,
              title: 'Hide languages',
              subtitle: settings.hiddenLanguages
                  .map((code) => contentLanguageOptions[code] ?? code)
                  .join(', '),
              onTap: () => pickLanguages(
                'Hide languages',
                settings.hiddenLanguages,
                true,
              ),
            ),
            switchTile(
              icon: LucideIcons.listFilter,
              title: 'Strict Home',
              subtitle: settings.strictHome
                  ? 'Only selected languages'
                  : 'All allowed languages',
              value: settings.strictHome,
              onChanged: (value) => ref
                  .read(contentPrefsProvider.notifier)
                  .update(strictHome: value),
            ),
            settingTile(
              icon: LucideIcons.slidersHorizontal,
              title: 'Home content mix',
              subtitle: '${(settings.localRatio * 100).round()}% local content',
              onTap: () {
                var ratio = settings.localRatio;
                showAppSheet<void>(
                  context,
                  title: 'Home content mix',
                  fit: true,
                  builder: (sheetContext, _) => StatefulBuilder(
                    builder: (context, setSheetState) => Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(ratio * 100).round()}% local content',
                            style: AppTextStyles.settingsTitle,
                          ),
                          Slider(
                            value: ratio,
                            divisions: 10,
                            label: '${(ratio * 100).round()}%',
                            onChanged: (value) {
                              setSheetState(() => ratio = value);
                              ref
                                  .read(contentPrefsProvider.notifier)
                                  .update(localRatio: value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            section('Playback'),
            switchTile(
              icon: LucideIcons.play,
              title: 'Autoplay',
              subtitle: settings.autoplay ? 'On' : 'Off',
              value: settings.autoplay,
              onChanged: (value) =>
                  ref.read(contentPrefsProvider.notifier).setAutoplay(value),
            ),
            section('Privacy & data'),
            FutureBuilder<String?>(
              future: ref.watch(dbProvider).getValue('history_enabled'),
              builder: (ctx, snap) {
                final enabled = snap.data != 'false';
                return switchTile(
                  icon: LucideIcons.history,
                  title: 'Save watch history',
                  subtitle: enabled ? 'On' : 'Off',
                  value: enabled,
                  onChanged: (value) async {
                    await ref
                        .read(dbProvider)
                        .setValue('history_enabled', value.toString());
                    (ctx as Element).markNeedsBuild();
                  },
                );
              },
            ),
            FutureBuilder<String?>(
              future: ref.watch(dbProvider).getValue('history_paused'),
              builder: (ctx, snap) {
                final paused = snap.data == 'true';
                return switchTile(
                  icon: LucideIcons.pause,
                  title: 'Pause watch history',
                  subtitle: paused ? 'On' : 'Off',
                  value: paused,
                  onChanged: (value) async {
                    await ref
                        .read(dbProvider)
                        .setValue('history_paused', value.toString());
                    (ctx as Element).markNeedsBuild();
                  },
                );
              },
            ),
            settingTile(
              icon: LucideIcons.trash2,
              title: 'Clear app database',
              subtitle: 'Remove saved data from this device',
              onTap: clearDatabase,
            ),
            section('About'),
            settingTile(
              icon: LucideIcons.bug,
              title: 'Content debug',
              subtitle: 'Home trace and language filter diagnostics',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ContentDebugScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
