import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'glass_surface.dart';
import 'hive_logo.dart';
import 'content_language_button.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});
  @override
  Widget build(BuildContext context) {
    final desktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(child: HiveLogo()),
          const ContentLanguageButton(),
          const SizedBox(width: AppSpacing.sm),
          if (!desktop) ...[
            _GlassButton(icon: LucideIcons.cast, tooltip: 'Cast', onTap: () {}),
            const SizedBox(width: AppSpacing.sm),
          ],
          _GlassButton(
            icon: LucideIcons.bell,
            tooltip: 'Notifications',
            onTap: () {},
          ),
          const SizedBox(width: AppSpacing.sm),
          _GlassButton(
            icon: LucideIcons.search,
            tooltip: 'Search',
            onTap: () => context.push('/search'),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GlassSurface(
    borderRadius: AppRadius.pillBorder,
    child: SizedBox(
      width: AppSpacing.topButton,
      height: AppSpacing.topButton,
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
    ),
  );
}
