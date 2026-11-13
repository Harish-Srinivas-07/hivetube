import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_sizes.dart';

/// Normalizes protocol-relative URLs and optimizes avatar size parameters.
String normalizeAvatarUrl(String url, {int size = 96}) {
  var clean = url.trim();
  if (clean.isEmpty) return '';
  if (clean.startsWith('//')) {
    clean = 'https:$clean';
  }
  return clean.replaceFirst(
    RegExp(r'=s\d+(-[^/?#]*)?(?=[?#]|$)'),
    '=s$size-c-k-c0x00ffffff-no-rj',
  );
}

/// The unified channel avatar component used across all screens.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.name,
    required this.url,
    this.size = AppSizes.avatar,
    this.onTap,
  });

  final String name;
  final String url;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? AppColors.dark : AppColors.light;

    final trimmedName = name.trim();
    final letter = trimmedName.isEmpty
        ? ''
        : trimmedName.characters.first.toUpperCase();

    Widget fallback() => CircleAvatar(
          radius: size / 2,
          backgroundColor: colors.surfaceVariant,
          child: Text(
            letter.isNotEmpty ? letter : '?',
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        );

    final normalizedUrl = normalizeAvatarUrl(url, size: (size * 2).toInt());

    Widget avatarWidget = SizedBox(
      width: size,
      height: size,
      child: normalizedUrl.isEmpty
          ? fallback()
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: normalizedUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: AppMotion.fast,
                placeholder: (_, _) => fallback(),
                errorWidget: (_, _, _) => fallback(),
              ),
            ),
    );

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}

