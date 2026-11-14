import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/settings/app_settings.dart';
import '../../core/providers.dart';
import '../home/home_controller.dart';
import '../home/home_screen.dart';
import '../home/home_variety.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
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
            AppButton.filled(
              onPressed: () => Navigator.pop(dialogContext, true),
              label: 'Clear database',
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
      final chosen = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTopBorder,
        ),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height:
                MediaQuery.sizeOf(context).height *
                AppSpacing.contentRegionPickerHeightFactor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                Expanded(
                  child: RadioGroup<String>(
                    groupValue: current,
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                    child: ListView(
                      children: [
                        for (final entry in values.entries)
                          RadioListTile<String>(
                            value: entry.key,
                            title: Text(entry.value),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (chosen != null) await update(chosen);
    }

    Future<void> pickLanguages(
      String title,
      Set<String> selected,
      bool hidden,
    ) async {
      final result = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTopBorder,
        ),
        builder: (sheetContext) {
          final draft = selected.toSet();
          return StatefulBuilder(
            builder: (context, setDialogState) => SafeArea(
              child: SizedBox(
                height:
                    MediaQuery.sizeOf(context).height *
                    AppSpacing.contentRegionPickerHeightFactor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final option in contentLanguageOptions.entries)
                            CheckboxListTile(
                              dense: true,
                              title: Text(option.value),
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
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                          AppButton.tonal(
                            onPressed: () => Navigator.pop(sheetContext, draft),
                            label: 'Save',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
        AppSpacing.xs,
      ),
    );

    Widget leadingIcon(IconData icon) => Icon(
      icon,
      size: AppSizes.icon,
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget settingTile({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) => ListTile(
      leading: leadingIcon(icon),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: AppSizes.iconSm,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      minTileHeight: AppSizes.settingsRowHeight,
      onTap: onTap,
    );

    Widget switchTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => ListTile(
      leading: leadingIcon(icon),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      minTileHeight: AppSizes.settingsRowHeight,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local content share · ${(settings.localRatio * 100).round()}%',
                    style: theme.textTheme.titleSmall,
                  ),
                  Slider(
                    value: settings.localRatio,
                    divisions: 10,
                    label: '${(settings.localRatio * 100).round()}%',
                    onChanged: (value) => ref
                        .read(contentPrefsProvider.notifier)
                        .update(localRatio: value),
                  ),
                ],
              ),
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
            section('Privacy'),
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
            section('Data'),
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
