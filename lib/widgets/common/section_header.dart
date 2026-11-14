import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// YouTube-style section header with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.titleStyle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
  });

  final String title;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (trailing == null) {
      return Padding(
        padding: padding,
        child: Text(
          title,
          style:
              titleStyle ??
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  titleStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          trailing!,
        ],
      ),
    );
  }
}
