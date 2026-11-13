import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/settings/app_settings.dart';
import '../../core/providers.dart';
import '../home/home_controller.dart';
import '../home/home_screen.dart';
import '../home/home_variety.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/glass_surface.dart';
import 'content_debug_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(contentPrefsProvider);
    Future<void> clearDatabase() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Clear app database?'),
          content: const Text(
            'This permanently removes saved settings, watch history, cached feed data, and channel avatars from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear database'),
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
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: AppSpacing.searchMaxWidth,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in values.entries)
                  ListTile(
                    title: Text(e.value),
                    trailing: e.key == current
                        ? const Icon(LucideIcons.check)
                        : null,
                    onTap: () => Navigator.pop(context, e.key),
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
      final result = await showDialog<Set<String>>(
        context: context,
        builder: (dialogContext) {
          final draft = selected.toSet();
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: AppSpacing.searchMaxWidth,
                child: ListView(
                  shrinkWrap: true,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, draft),
                  child: const Text('Save'),
                ),
              ],
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassSurface(
          borderRadius: AppRadius.mdBorder,
          child: Material(
            color: AppColors.transparent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Location'),
                    subtitle: Text(regions[settings.gl] ?? settings.gl),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => pick(
                      'Location',
                      regions,
                      settings.gl,
                      (value) => ref
                          .read(contentPrefsProvider.notifier)
                          .update(gl: value),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Local content'),
                    value: settings.localContent,
                    onChanged: (value) => ref
                        .read(contentPrefsProvider.notifier)
                        .update(localContent: value),
                  ),
                  ListTile(
                    title: const Text('Content languages'),
                    subtitle: Text(
                      settings.contentLanguages
                          .map((code) => contentLanguageOptions[code] ?? code)
                          .join(', '),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => pickLanguages(
                      'Content languages',
                      settings.contentLanguages,
                      false,
                    ),
                  ),
                  ListTile(
                    title: const Text('Hide languages'),
                    subtitle: Text(
                      settings.hiddenLanguages
                          .map((code) => contentLanguageOptions[code] ?? code)
                          .join(', '),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => pickLanguages(
                      'Hide languages',
                      settings.hiddenLanguages,
                      true,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Strict Home'),
                    subtitle: const Text(
                      'Show only videos in selected languages',
                    ),
                    value: settings.strictHome,
                    onChanged: (value) => ref
                        .read(contentPrefsProvider.notifier)
                        .update(strictHome: value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local-language share: ${(settings.localRatio * 100).round()}%',
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
                  FutureBuilder<String?>(
                    future: ref.watch(dbProvider).getValue('history_enabled'),
                    builder: (ctx, snap) {
                      final enabled = snap.data != 'false';
                      return SwitchListTile(
                        title: const Text('Save watch history'),
                        subtitle: const Text(
                          'Record videos and resume playback position',
                        ),
                        value: enabled,
                        onChanged: (val) async {
                          await ref
                              .read(dbProvider)
                              .setValue('history_enabled', val.toString());
                          (ctx as Element).markNeedsBuild();
                        },
                      );
                    },
                  ),
                  FutureBuilder<String?>(
                    future: ref.watch(dbProvider).getValue('history_paused'),
                    builder: (ctx, snap) {
                      final paused = snap.data == 'true';
                      return SwitchListTile(
                        title: const Text('Pause watch history'),
                        subtitle: const Text(
                          'Temporarily pause adding new videos to history',
                        ),
                        value: paused,
                        onChanged: (val) async {
                          await ref
                              .read(dbProvider)
                              .setValue('history_paused', val.toString());
                          (ctx as Element).markNeedsBuild();
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.bug),
                    title: const Text('Content debug'),
                    subtitle: const Text(
                      'Home trace and language filter diagnostic log',
                    ),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ContentDebugScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.trash2),
                    title: const Text('Clear app database'),
                    subtitle: const Text('Remove saved data from this device'),
                    onTap: clearDatabase,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
