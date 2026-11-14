import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../common/channel_avatar.dart';

export '../common/channel_avatar.dart' show ChannelAvatar;

/// Standard compact pill chip.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.compact = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bgColor = selected ? cs.onSurface : cs.surfaceContainerHighest;
    final fgColor = selected ? cs.surface : cs.onSurface;

    final height = AppSizes.chipHeightCompact;
    final labelStyle = AppTextStyles.body.copyWith(color: fgColor);

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.smBorder,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  if (label.isNotEmpty) const SizedBox(width: AppSpacing.xs),
                ],
                if (label.isNotEmpty)
                  Flexible(
                    child: Text(
                      label,
                      style: labelStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling chip bar with right-edge fade and standard gutters.
class AppChipBar extends StatelessWidget {
  const AppChipBar({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );

    return SizedBox(
      height: AppSizes.chipHeightCompact + AppSpacing.sm * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: effectivePadding,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

enum AppButtonSize { compact, standard, large }

enum AppButtonVariant { filled, tonal, destructive, text, outlined }

/// YouTube-style pill button with tactile press feedback.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.horizontalPadding = AppSpacing.lg,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  });

  const AppButton.filled({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.horizontalPadding = AppSpacing.lg,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  }) : variant = AppButtonVariant.filled;

  const AppButton.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.horizontalPadding = AppSpacing.lg,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  }) : variant = AppButtonVariant.tonal;

  const AppButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.horizontalPadding = AppSpacing.lg,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  }) : variant = AppButtonVariant.destructive;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.horizontalPadding = AppSpacing.lg,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.horizontalPadding = AppSpacing.lg,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  }) : variant = AppButtonVariant.outlined;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final double horizontalPadding;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
    AppButtonSize.compact => AppSizes.buttonCompact,
    AppButtonSize.standard => AppSizes.buttonStandard,
    AppButtonSize.large => AppSizes.buttonLarge,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.isLoading;

    Color bgColor;
    Color fgColor;
    Border? border;

    switch (widget.variant) {
      case AppButtonVariant.filled:
        bgColor = isDark ? cs.onSurface : cs.onSurface;
        fgColor = isDark ? cs.surface : cs.surface;
      case AppButtonVariant.tonal:
        bgColor = cs.surfaceContainerHighest;
        fgColor = cs.onSurface;
      case AppButtonVariant.destructive:
        bgColor = AppColors.primary;
        fgColor = AppColors.onPrimary;
      case AppButtonVariant.text:
        bgColor = AppColors.transparent;
        fgColor = cs.onSurface;
      case AppButtonVariant.outlined:
        bgColor = AppColors.transparent;
        fgColor = cs.onSurface;
        border = Border.all(
          color: cs.outlineVariant,
          width: AppSpacing.borderWidth,
        );
    }

    final minTouchHeight = widget.variant == AppButtonVariant.text
        ? AppSizes.touchMin
        : _height;

    Widget content = widget.isLoading
        ? SizedBox.square(
            dimension: AppSizes.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: AppSpacing.borderWidth * 2,
              color: fgColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: AppSizes.iconInline, color: fgColor),
                const SizedBox(width: AppSpacing.iconGap),
              ],
              Text(
                widget.label,
                style: AppTextStyles.buttonLabel.copyWith(color: fgColor),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.iconGap),
                Icon(
                  widget.trailingIcon,
                  size: AppSizes.iconXs,
                  color: fgColor,
                ),
              ],
            ],
          );

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minTouchHeight,
            minWidth: _height,
          ),
          child: Material(
            color: bgColor,
            shape: border != null
                ? RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                    side: border.top,
                  )
                : const StadiumBorder(),
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (h) {
                if (mounted) setState(() => _pressed = h);
              },
              borderRadius: AppRadius.pillBorder,
              child: Container(
                height: _height,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.horizontalPadding,
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented Like / Dislike pill button.
class AppLikeDislikeSegment extends StatelessWidget {
  const AppLikeDislikeSegment({
    super.key,
    required this.likeCount,
    required this.dislikeCount,
    required this.reaction,
    required this.onLike,
    required this.onDislike,
    this.size = AppButtonSize.standard,
  });

  final String likeCount;
  final String dislikeCount;
  final int reaction; // 1 = like, -1 = dislike, 0 = none
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final AppButtonSize size;

  double get _height => switch (size) {
    AppButtonSize.compact => AppSizes.buttonCompact,
    AppButtonSize.standard => AppSizes.buttonStandard,
    AppButtonSize.large => AppSizes.buttonLarge,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLiked = reaction == 1;
    final isDisliked = reaction == -1;

    final likeFg = cs.onSurface;
    final dislikeFg = cs.onSurface;

    return Material(
      color: cs.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: SizedBox(
        height: _height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onLike,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiked ? Icons.thumb_up : LucideIcons.thumbsUp,
                      size: AppSizes.iconInline,
                      color: likeFg,
                    ),
                    if (likeCount.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.iconGap),
                      Text(
                        likeCount,
                        style: AppTextStyles.buttonLabel.copyWith(
                          color: likeFg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: AppSpacing.borderWidth,
              height: _height * 0.55,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            InkWell(
              onTap: onDislike,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDisliked ? Icons.thumb_down : LucideIcons.thumbsDown,
                      size: AppSizes.iconInline,
                      color: dislikeFg,
                    ),
                    if (dislikeCount.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.iconGap),
                      Text(
                        dislikeCount,
                        style: AppTextStyles.buttonLabel.copyWith(
                          color: dislikeFg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Channel subscription state button.
class AppSubscribedButton extends StatelessWidget {
  const AppSubscribedButton({
    super.key,
    required this.isSubscribed,
    required this.onPressed,
    this.size = AppButtonSize.standard,
    this.isLoading = false,
  });

  final bool isSubscribed;
  final VoidCallback? onPressed;
  final AppButtonSize size;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isSubscribed) {
      return AppButton(
        label: 'Subscribe',
        variant: AppButtonVariant.filled,
        size: size,
        onPressed: onPressed,
        isLoading: isLoading,
      );
    }

    return AppButton(
      label: 'Subscribed',
      variant: AppButtonVariant.tonal,
      size: size,
      icon: LucideIcons.bell,
      trailingIcon: LucideIcons.chevronDown,
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }
}

/// 40 tonal circle inside a 48 touch target area.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = AppSizes.icon,
    this.color,
    this.tonal = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;
    final bgColor = tonal ? cs.surfaceContainerHighest : AppColors.transparent;

    return SizedBox.square(
      dimension: AppSizes.buttonIconTouch,
      child: Center(
        child: Container(
          width: AppSizes.buttonIcon,
          height: AppSizes.buttonIcon,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Material(
            color: AppColors.transparent,
            child: IconButton(
              icon: Icon(icon, size: size, color: effectiveColor),
              onPressed: onPressed,
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard list tile with 72 height, 40 avatar, 2-line text.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.dense = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      height: dense ? AppSizes.settingsRowHeight : AppSizes.listRowHeight,
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected ? cs.primary : cs.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.sm,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      ),
    );
  }
}

/// Backward-compatibility alias for [ChannelAvatar].
typedef AppAvatar = ChannelAvatar;
