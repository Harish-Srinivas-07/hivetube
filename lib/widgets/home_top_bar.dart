import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'content_language_button.dart';
import 'glass_surface.dart';
import 'hive_logo.dart';

/// Shared scroll-reactive glass layer used by the main tab app bars.
class GlassAppBar extends StatelessWidget {
  const GlassAppBar({
    super.key,
    this.scrollController,
    this.topInset = 0,
    this.barHeight = AppSizes.appBarHeight,
    required this.child,
  });

  final ScrollController? scrollController;
  final double topInset;
  final double barHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark
        ? AppColors.navGlassFillDark
        : AppColors.navGlassFillLight;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    );
    final contents = Padding(
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(height: barHeight, child: child),
    );
    final controller = scrollController;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: SizedBox(
        height: topInset + barHeight,
        child: controller == null
            ? contents
            : AnimatedBuilder(
                animation: controller,
                child: contents,
                builder: (context, content) {
                  final offset = controller.hasClients
                      ? controller.offset
                      : AppSpacing.none;
                  final amount = (offset / AppSpacing.glassScrollRange).clamp(
                    0.0,
                    1.0,
                  );
                  if (amount == AppSpacing.none) return content!;

                  return ClipRect(
                    // allowed: scroll-reactive top bar glass
                    child: GlassSurface(
                      borderRadius: BorderRadius.zero,
                      blurSigma: AppSpacing.navGlassBlur * amount,
                      fill: Color.lerp(AppColors.transparent, fill, amount),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.navGlassBorder.withValues(
                            alpha: amount,
                          ),
                          width: AppSpacing.glassBorderWidth,
                        ),
                      ),
                      child: content!,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    this.scrollController,
    this.topInset = 0,
    this.barHeight = AppSizes.appBarHeight,
  });

  final ScrollController? scrollController;
  final double topInset;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      scrollController: scrollController,
      topInset: topInset,
      barHeight: barHeight,
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
