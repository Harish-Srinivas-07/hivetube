import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_sizes.dart';
import 'hive_logo.dart';
import 'content_language_button.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.appBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            const Expanded(child: HiveLogo()),
            const ContentLanguageButton(plain: true),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(LucideIcons.search),
              tooltip: 'Search',
              onPressed: () => context.push('/search'),
            ),
          ],
        ),
      ),
    );
  }
}
