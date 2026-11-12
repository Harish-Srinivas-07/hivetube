import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

String avatarImageUrl(String url) => url.replaceFirst(
  RegExp(r'=s\d+(-[^/?#]*)?(?=[?#]|$)'),
  '=s96-c-k-c0x00ffffff-no-rj',
);

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.url,
    this.size = AppSpacing.avatar,
  });
  final String name, url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final letter = name.trim().isEmpty
        ? ''
        : name.trim().characters.first.toUpperCase();
    Widget fallback() => CircleAvatar(
      radius: size / 2,
      backgroundColor: colors.surfaceVariant,
      child: Text(letter, style: TextStyle(color: colors.textPrimary)),
    );
    return SizedBox(
      width: size,
      height: size,
      child: url.isEmpty
          ? fallback()
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarImageUrl(url),
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: AppMotion.fast,
                placeholder: (_, _) => fallback(),
                errorWidget: (_, _, _) => fallback(),
              ),
            ),
    );
  }
}
