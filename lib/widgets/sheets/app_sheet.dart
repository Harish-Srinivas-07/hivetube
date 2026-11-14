import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/watch/mini_player_inset.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../ui/app_controls.dart';

/// Bottom sheet header with centered handle and optional title/actions.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    this.title,
    this.action,
    this.onBack,
    this.showClose = true,
    this.isScrolledUnder = false,
  });

  final String? title;
  final Widget? action;
  final VoidCallback? onBack;
  final bool showClose;
  final bool isScrolledUnder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasHeaderRow =
        title != null || action != null || onBack != null || showClose;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Center(
            child: Container(
              width: AppSizes.sheetHandleWidth,
              height: AppSizes.sheetHandleHeight,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.sheetHandle),
              ),
            ),
          ),
        ),
        if (hasHeaderRow) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  AppIconButton(
                    icon: LucideIcons.arrowLeft,
                    onPressed: onBack,
                    tonal: false,
                    size: AppSizes.iconSm,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.settingsTitle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (action != null)
                  action!
                else if (showClose)
                  AppIconButton(
                    icon: LucideIcons.x,
                    onPressed: () => Navigator.of(context).pop(),
                    tonal: false,
                    size: AppSizes.iconSm,
                  ),
              ],
            ),
          ),
        ] else
          const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

/// Standard bottom sheet row matching YouTube's options and settings menus.
class AppSheetRow extends StatelessWidget {
  const AppSheetRow({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.subtitle,
    this.onTap,
    this.showChevron = false,
    this.selected = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSizes.settingsRowHeight,
      child: Opacity(
        opacity: enabled ? 1 : AppColors.disabledOpacity,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: cs.onSurface, size: AppSizes.icon),
                  const SizedBox(width: AppSpacing.xl),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.settingsTitle.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.settingsSub.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    LucideIcons.check,
                    size: AppSizes.icon,
                    color: cs.onSurface,
                  )
                else if (value != null || showChevron)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value != null && value!.isNotEmpty)
                        Flexible(
                          child: Text(
                            value!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.settingsSub.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (showChevron) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          LucideIcons.chevronRight,
                          size: AppSizes.iconSm,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified bottom-anchored modal sheet.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(
    BuildContext context,
    ScrollController? scrollController,
  )
  builder,
  String? title,
  Widget? headerAction,
  VoidCallback? onBack,
  bool showClose = true,
  bool fit = false,
  double? fraction,
  double initialFraction = 0.6,
  double minFraction = 0.25,
  double maxFraction = 1,
  List<double>? snapSizes,
  bool expand = false,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  bool onVideo = false,
}) {
  final inheritedTheme = onVideo ? AppTheme.dark : Theme.of(context);
  final cs = inheritedTheme.colorScheme;
  final sheetBg = backgroundColor ?? cs.surface;
  final callerMiniInset = MiniPlayerInset.of(context);
  final callerBottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
  final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
  final effectiveInitial = fraction ?? (fit ? 0.6 : initialFraction);
  final heightLimit = landscape ? AppSpacing.sheetMaxHeightFactor : 1.0;
  final effectiveMaximum = maxFraction
      .clamp(minFraction, math.max(minFraction, heightLimit))
      .toDouble();
  final effectiveSnapSizes = snapSizes ?? [0.6, effectiveMaximum];

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: false,
    barrierColor: AppColors.scrim50,
    backgroundColor: AppColors.transparent,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (modalContext) {
      final mq = MediaQuery.of(modalContext);
      final effectiveBg = inheritedTheme.brightness == Brightness.dark
          ? AppColors.videoSheet
          : sheetBg;
      final borderRadius = AppRadius.sheetTopBorder;

      Widget content;

      if (fit) {
        content = Material(
          key: const ValueKey('appSheetSurface'),
          color: effectiveBg,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mq.size.height * AppSpacing.sheetMaxHeightFactor,
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: AppSpacing.sm + callerMiniInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSheetHeader(
                      title: title,
                      action: headerAction,
                      onBack: onBack,
                      showClose: showClose,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: builder(modalContext, null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        content = DraggableScrollableSheet(
          snap: true,
          snapSizes: effectiveSnapSizes,
          initialChildSize: effectiveInitial
              .clamp(minFraction, effectiveMaximum)
              .toDouble(),
          minChildSize: minFraction,
          maxChildSize: effectiveMaximum,
          expand: expand,
          builder: (sheetContext, scrollController) {
            return Material(
              key: const ValueKey('appSheetSurface'),
              color: effectiveBg,
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: AppSpacing.sm + callerMiniInset,
                ),
                child: _DraggableSheetBody(
                  title: title,
                  headerAction: headerAction,
                  onBack: onBack,
                  showClose: showClose,
                  scrollController: scrollController,
                  builder: builder,
                ),
              ),
            );
          },
        );
      }

      return Theme(
        data: inheritedTheme,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: math.max(mq.viewInsets.bottom, callerBottomSafeArea),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: math.min(mq.size.width, AppSizes.sheetMaxWidth),
              child: content,
            ),
          ),
        ),
      );
    },
  );
}

class _DraggableSheetBody extends StatefulWidget {
  const _DraggableSheetBody({
    required this.title,
    required this.headerAction,
    required this.onBack,
    required this.showClose,
    required this.scrollController,
    required this.builder,
  });

  final String? title;
  final Widget? headerAction;
  final VoidCallback? onBack;
  final bool showClose;
  final ScrollController scrollController;
  final Widget Function(BuildContext, ScrollController?) builder;

  @override
  State<_DraggableSheetBody> createState() => _DraggableSheetBodyState();
}

class _DraggableSheetBodyState extends State<_DraggableSheetBody> {
  bool _isScrolledUnder = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final scrolled =
        widget.scrollController.hasClients &&
        widget.scrollController.offset > 0;
    if (scrolled != _isScrolledUnder) {
      if (mounted) setState(() => _isScrolledUnder = scrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSheetHeader(
          title: widget.title,
          action: widget.headerAction,
          onBack: widget.onBack,
          showClose: widget.showClose,
          isScrolledUnder: _isScrolledUnder,
        ),
        Expanded(child: widget.builder(context, widget.scrollController)),
      ],
    );
  }
}

/// Standard bottom sheet wrapper (kept for backward compatibility).
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showHandle;

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isDismissible = true,
  }) {
    return showAppSheet<T>(
      context,
      fit: true,
      title: title,
      showClose: isDismissible,
      isDismissible: isDismissible,
      builder: (_, _) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSheetHeader(title: title, showClose: false),
        child,
      ],
    );
  }
}

/// Standard dialog wrapper with rounded corners (16 radius, 400 max-width) and 24 padding.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.insetPadding,
  });

  final String? title;
  final Widget content;
  final List<Widget>? actions;
  final EdgeInsets? insetPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final miniInset = MiniPlayerInset.of(context);
    final effectiveInsetPadding =
        insetPadding ??
        EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + miniInset,
        );

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      insetPadding: effectiveInsetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Flexible(child: content),
              if (actions != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final a in actions!)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: a,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
