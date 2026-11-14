import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/settings/app_settings.dart';
import '../theme/app_spacing.dart';
import 'content_language_sheet.dart';

class ContentLanguageButton extends ConsumerWidget {
  const ContentLanguageButton({super.key, this.plain = false});

  final bool plain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(contentPrefsProvider);
    final changed =
        prefs.contentLanguages.length != 2 ||
        !prefs.contentLanguages.containsAll({'ta', 'en'}) ||
        prefs.hiddenLanguages.length != 1 ||
        !prefs.hiddenLanguages.contains('hi') ||
        prefs.gl != 'AUTO' ||
        prefs.localRatio != .6;
    final colors = Theme.of(context).colorScheme;
    if (plain) {
      return IconButton(
        key: const ValueKey('contentLanguageButton'),
        tooltip: 'Content language',
        onPressed: () => showContentLanguageSheet(context, ref),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(LucideIcons.languages),
            if (changed)
              Positioned(
                right: -AppSpacing.xxs,
                top: -AppSpacing.xxs,
                child: DecoratedBox(
                  key: const ValueKey('contentLanguageChangedDot'),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: AppSpacing.badgeDotSize,
                    height: AppSpacing.badgeDotSize,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Tooltip(
      message: 'Content language',
      child: Semantics(
        button: true,
        label: 'Content language',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('contentLanguageButton'),
            onTap: () => showContentLanguageSheet(context, ref),
            child: SizedBox(
              width: AppSpacing.topButton,
              height: AppSpacing.topButton,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(LucideIcons.languages, color: colors.onSurface),
                  if (changed)
                    Positioned(
                      top: AppSpacing.xs + AppSpacing.xxs,
                      right: AppSpacing.xs + AppSpacing.xxs,
                      child: DecoratedBox(
                        key: const ValueKey('contentLanguageChangedDot'),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.surface,
                            width: AppSpacing.borderWidth,
                          ),
                        ),
                        child: const SizedBox(
                          width: AppSpacing.badgeDotSize,
                          height: AppSpacing.badgeDotSize,
                        ),
                      ),
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
