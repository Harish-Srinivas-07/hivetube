import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/settings/app_settings.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'glass_surface.dart';
import 'content_language_sheet.dart';

class ContentLanguageButton extends ConsumerWidget {
  const ContentLanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(contentPrefsProvider);
    final changed =
        prefs.contentLanguages.length != 2 ||
        !prefs.contentLanguages.containsAll({'ta', 'en'}) ||
        prefs.hiddenLanguages.length != 1 ||
        !prefs.hiddenLanguages.contains('hi') ||
        prefs.gl != 'IN' ||
        prefs.localRatio != .6;
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Content language',
      child: Semantics(
        button: true,
        label: 'Content language',
        child: GestureDetector(
          key: const ValueKey('contentLanguageButton'),
          onTap: () => showContentLanguageSheet(context, ref),
          child: GlassSurface(
            borderRadius: AppRadius.pillBorder,
            child: SizedBox(
              width: AppSpacing.topButton,
              height: AppSpacing.topButton,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(LucideIcons.languages, color: colors.onSurface),
                  if (changed)
                    Positioned(
                      top: 7,
                      right: 7,
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
