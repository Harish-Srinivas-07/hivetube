import 'package:flutter/material.dart';

import '../core/yt/models.dart';
import 'ui/video_card.dart';

export 'ui/video_card.dart';

/// Backward-compatible alias for [VideoCard] with rounded thumbnail.
class VarietyVideoCard extends StatelessWidget {
  const VarietyVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.trailing,
    this.progress,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final Widget? trailing;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return VideoCard(
      video: video,
      onTap: onTap,
      progress: progress,
      trailing: trailing,
      roundedThumbnail: true,
    );
  }
}
