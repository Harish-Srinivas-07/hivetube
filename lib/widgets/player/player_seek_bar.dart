import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
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
  });

  final List<WatchChapter> chapters;
  final Duration position, buffered, duration;
  final ValueChanged<Duration> onScrubStart, onScrubUpdate, onScrubEnd;
  final bool overlayVisible;
  final VoidCallback? onScrubCancel;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  bool active = false;
  Duration current = Duration.zero;

  Duration _position(double dx, double width) => Duration(
    milliseconds:
        (widget.duration.inMilliseconds * (dx / width).clamp(0.0, 1.0)).round(),
  );

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
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: active ? 1 : 0),
                  duration: const Duration(milliseconds: 150),
                  builder: (context, animation, _) => CustomPaint(
                    painter: _SeekPainter(
                      fraction(position),
                      fraction(widget.buffered),
                      animation,
                      widget.overlayVisible,
                      widget.chapters.map((c) => fraction(c.start)).toList(),
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  left: (constraints.maxWidth * fraction(position) - 30).clamp(
                    0.0,
                    (constraints.maxWidth - 60).clamp(0.0, double.infinity),
                  ),
                  top: -30,
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
                        '${current.inMinutes}:${current.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: AppColors.shortsForeground,
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
    this.chapters,
  );
  final List<double> chapters;
  final double position, buffered;
  final double active;
  final bool overlayVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
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
    if (active > 0) {
      canvas.drawCircle(
        Offset(size.width * position, y),
        6 * active,
        Paint()..color = const Color(0xFFFF0000),
      );
    }
  }

  @override
  bool shouldRepaint(_SeekPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.buffered != buffered ||
      oldDelegate.active != active ||
      oldDelegate.overlayVisible != overlayVisible ||
      oldDelegate.chapters.toString() != chapters.toString();
}
