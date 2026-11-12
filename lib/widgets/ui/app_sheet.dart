import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import 'app_controls.dart';

/// Pinned sheet header with centered handle, 56-high title row, and optional back/action buttons.
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top 12 padding with 4x32 centered handle
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Center(
            child: Container(
              width: AppSizes.sheetHandleWidth,
              height: AppSizes.sheetHandleHeight,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
        ),
        // 56-high title row with 16 gutters
        SizedBox(
          height: AppSizes.sheetHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
        ),
        if (isScrolledUnder)
          Divider(
            height: AppSpacing.borderWidth,
            thickness: AppSpacing.borderWidth,
            color: cs.outlineVariant.withAlpha(50),
          ),
      ],
    );
  }
}

/// Unified modal bottom sheet launcher with snappy physics, draggable handle, and responsive max-width.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, ScrollController? scrollController) builder,
  String? title,
  Widget? headerAction,
  VoidCallback? onBack,
  bool showClose = true,
  bool fit = false,
  List<double> snapSizes = const [0.5, 0.92],
  double initialFraction = 0.5,
  double minFraction = 0.25,
  double maxFraction = 0.92,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool isDismissible = true,
  Color? backgroundColor,
}) {
  final cs = Theme.of(context).colorScheme;
  final sheetBg = backgroundColor ?? cs.surface;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: false,
    barrierColor: AppColors.scrim50,
    backgroundColor: AppColors.transparent,
    builder: (modalContext) {
      final mq = MediaQuery.of(modalContext);
      final bottomInset = mq.padding.bottom + AppSpacing.lg;

      if (fit) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.sheetMaxWidth),
            child: Material(
              color: sheetBg,
              borderRadius: AppRadius.sheetTopBorder,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSheetHeader(
                      title: title,
                      action: headerAction,
                      onBack: onBack,
                      showClose: showClose,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        bottomInset,
                      ),
                      child: builder(modalContext, null),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.sheetMaxWidth),
          child: DraggableScrollableSheet(
            snap: true,
            snapSizes: snapSizes,
            initialChildSize: initialFraction,
            minChildSize: minFraction,
            maxChildSize: maxFraction,
            expand: false,
            builder: (sheetContext, scrollController) {
              return Material(
                color: sheetBg,
                borderRadius: AppRadius.sheetTopBorder,
                child: _DraggableSheetBody(
                  title: title,
                  headerAction: headerAction,
                  onBack: onBack,
                  showClose: showClose,
                  scrollController: scrollController,
                  builder: builder,
                ),
              );
            },
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
    final scrolled = widget.scrollController.hasClients &&
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
        Expanded(
          child: widget.builder(context, widget.scrollController),
        ),
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

/// Standard dialog wrapper with rounded corners (lg radius) and 24 padding.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
  });

  final String? title;
  final Widget content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
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
            content,
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
    );
  }
}
