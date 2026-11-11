import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/settings/app_settings.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/glass_surface.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
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
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Language'),
                  subtitle: Text(languages[settings.hl] ?? settings.hl),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => pick(
                    'Language',
                    languages,
                    settings.hl,
                    (value) => ref
                        .read(appSettingsProvider.notifier)
                        .update(hl: value),
                  ),
                ),
                ListTile(
                  title: const Text('Location'),
                  subtitle: Text(regions[settings.gl] ?? settings.gl),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => pick(
                    'Location',
                    regions,
                    settings.gl,
                    (value) => ref
                        .read(appSettingsProvider.notifier)
                        .update(gl: value),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Local content'),
                  value: settings.localContent,
                  onChanged: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .update(localContent: value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
