import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../core/yt/watch_info.dart';

class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.buffered,
    required this.duration,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    this.overlayVisible = true,
    this.onScrubCancel,
    this.chapters = const [],
    this.seeking = false,
    this.buffering = false,
  });

  final List<WatchChapter> chapters;
  final Duration position, buffered, duration;
  final ValueChanged<Duration> onScrubStart, onScrubUpdate, onScrubEnd;
  final bool overlayVisible;
  final VoidCallback? onScrubCancel;
  final bool seeking;
  final bool buffering;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar>
    with SingleTickerProviderStateMixin {
  bool active = false;
  Duration current = Duration.zero;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.pulse,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Duration _position(double dx, double width) => Duration(
    milliseconds:
        (widget.duration.inMilliseconds * (dx / width).clamp(0.0, 1.0)).round(),
  );

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (widget.duration.inHours > 0) {
      final h = d.inHours;
      final remM = m.remainder(60).toString().padLeft(2, '0');
      return '$h:$remM:$s';
    }
    return '$m:$s';
  }

  String? _chapterTitle(Duration pos) {
    if (widget.chapters.isEmpty) return null;
    WatchChapter? match;
    for (final c in widget.chapters) {
      if (c.start <= pos) {
        match = c;
      } else {
        break;
      }
    }
    return match?.title;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final total = widget.duration.inMilliseconds;
      final position = active ? current : widget.position;
      double fraction(Duration value) =>
          total <= 0 ? 0 : (value.inMilliseconds / total).clamp(0.0, 1.0);
      void update(double dx) {
        current = _position(dx, constraints.maxWidth);
        setState(() {});
        widget.onScrubUpdate(current);
      }

      final chapter = _chapterTitle(position);
      final bubbleText = active
          ? '${_format(current)} / ${_format(widget.duration)}${chapter != null ? ' · $chapter' : ''}'
          : '';

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: total <= 0
            ? null
            : (details) {
                current = _position(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
                setState(() => active = true);
                widget.onScrubStart(current);
              },
        onHorizontalDragUpdate: total <= 0
            ? null
            : (details) => update(details.localPosition.dx),
        onHorizontalDragEnd: total <= 0
            ? null
            : (_) {
                setState(() => active = false);
                widget.onScrubEnd(current);
              },
        onHorizontalDragCancel: () {
          if (active) {
            setState(() => active = false);
            widget.onScrubCancel?.call();
          }
        },
        onTapUp: total <= 0
            ? null
            : (details) {
                current = _position(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
                widget.onScrubStart(current);
                widget.onScrubEnd(current);
              },
        child: SizedBox(
          height: 20,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => TweenAnimationBuilder<double>(
                    tween: Tween(end: active ? 1 : 0),
                    duration: AppMotion.fast,
                    builder: (context, animation, _) => CustomPaint(
                      painter: _SeekPainter(
                        fraction(position),
                        fraction(widget.buffered),
                        animation,
                        widget.overlayVisible,
                        widget.chapters.map((c) => fraction(c.start)).toList(),
                        seeking: widget.seeking || widget.buffering,
                        pulseValue: _pulseController.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  left: (constraints.maxWidth * fraction(position) - 60).clamp(
                    8.0,
                    (constraints.maxWidth - 200).clamp(8.0, double.infinity),
                  ),
                  top: -36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.shortsScrim,
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        bubbleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.shortsForeground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _SeekPainter extends CustomPainter {
  _SeekPainter(
    this.position,
    this.buffered,
    this.active,
    this.overlayVisible,
    this.chapters, {
    this.seeking = false,
    this.pulseValue = 0.0,
  });

  final List<double> chapters;
  final double position, buffered;
  final double active;
  final bool overlayVisible;
  final bool seeking;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 3;
    final stroke = 2.0 + 2.0 * active;
    void line(double end, Color color) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * end, y),
        Paint()
          ..color = color
          ..strokeWidth = stroke,
      );
    }

    if (overlayVisible || active > 0) {
      line(1, AppColors.shortsForeground.withValues(alpha: 0.3));
      line(buffered, AppColors.shortsForeground.withValues(alpha: 0.5));
      line(position, AppColors.primary);
    } else {
      line(position, AppColors.primary);
    }
    for (final chapter in chapters.where((v) => v > 0 && v < 1)) {
      canvas.drawLine(
        Offset(size.width * chapter, y - stroke),
        Offset(size.width * chapter, y + stroke),
        Paint()
          ..color = AppColors.shortsBackground
          ..strokeWidth = 2,
      );
    }
    if (overlayVisible || active > 0 || seeking) {
      final thumbRadius = active > 0 ? 6.0 : (overlayVisible ? 5.0 : 4.0);
      final center = Offset(size.width * position, y);

      if (seeking) {
        // Draw subtle spinner ring around thumb while seeking/buffering
        final sweep = 2 * pi * 0.7;
        final startAngle = 2 * pi * pulseValue;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: thumbRadius + 3),
          startAngle,
          sweep,
          false,
          Paint()
            ..color = AppColors.primary
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }

      canvas.drawCircle(
        center,
        thumbRadius * (active > 0 ? active : 1.0),
        Paint()..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(_SeekPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.buffered != buffered ||
      oldDelegate.active != active ||
      oldDelegate.overlayVisible != overlayVisible ||
      oldDelegate.seeking != seeking ||
      (seeking && oldDelegate.pulseValue != pulseValue) ||
      oldDelegate.chapters.toString() != chapters.toString();
}
