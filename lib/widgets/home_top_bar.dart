import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../core/playback/player_ui_state.dart';
import '../core/yt/models.dart';
import '../features/shorts/shorts_screen.dart';
import '../features/watch/watch_panel.dart';
import 'ui/ui.dart';
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

({String id, bool isShort})? parseYouTubeLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  final host = uri.host.toLowerCase();
  String? id;
  var isShort = false;
  final parts = uri.pathSegments;
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (parts.length == 1) id = parts.first;
  } else if (host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com') {
    if (uri.path == '/watch') {
      id = uri.queryParameters['v'];
    } else if (parts.length == 2 &&
        ['shorts', 'embed', 'live'].contains(parts.first)) {
      id = parts[1];
      isShort = parts.first == 'shorts';
    }
  }
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
  return (id: id, isShort: isShort);
}

class HomeTopBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
              icon: const Icon(LucideIcons.link),
              tooltip: 'Open YouTube link',
              onPressed: () async {
                final result = await showDialog<({String id, bool isShort})>(
                  context: context,
                  builder: (_) => const _OpenLinkDialog(),
                );
                if (result == null || !context.mounted) return;
                if (result.isShort) {
                  if (ref.read(watchPanelProvider) != null) {
                    ref.read(watchPanelProvider.notifier).close();
                    ref.read(playerUiProvider.notifier).setDismissed(true);
                  }
                  ref.read(shortsSelectionProvider.notifier).open([
                    ShortItem(
                      id: result.id,
                      thumbUrl:
                          'https://i.ytimg.com/vi/${result.id}/hqdefault.jpg',
                    ),
                  ], 0);
                  context.go('/shorts');
                } else {
                  openWatchPanel(ref, result.id);
                }
              },
            ),
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

class _OpenLinkDialog extends StatefulWidget {
  const _OpenLinkDialog();
  @override
  State<_OpenLinkDialog> createState() => _OpenLinkDialogState();
}

class _OpenLinkDialogState extends State<_OpenLinkDialog> {
  final controller = TextEditingController();
  bool invalid = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void open({bool alternate = false}) {
    final link = parseYouTubeLink(controller.text);
    if (link == null) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(context, (
      id: link.id,
      isShort: alternate ? !link.isShort : link.isShort,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final link = parseYouTubeLink(controller.text);
    return AlertDialog(
      title: const Text('Open YouTube link'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: 'Video or Short link',
          errorText: invalid ? 'Enter a valid YouTube video link' : null,
        ),
        onChanged: (_) => setState(() => invalid = false),
        onSubmitted: (_) => open(),
      ),
      actions: [
        AppButton.text(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        AppButton.text(
          label: link?.isShort == true ? 'Open as video' : 'Open as Short',
          onPressed: () => open(alternate: true),
        ),
        AppButton.filled(label: 'Open', onPressed: open),
      ],
    );
  }
}
