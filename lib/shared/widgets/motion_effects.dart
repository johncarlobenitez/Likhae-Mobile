import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion_preferences.dart';
import 'motion_timeline.dart';

/// Procedural loading motion: no animation files, blur, or shader layers.
class AppActivityRing extends StatelessWidget {
  const AppActivityRing({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => AppMotionTimeline(
    duration: const Duration(milliseconds: 1400),
    repeat: true,
    builder: (context, progress) => RepaintBoundary(
      child: CustomPaint(painter: _ActivityRingPainter(progress, color)),
    ),
  );
}

class _ActivityRingPainter extends CustomPainter {
  _ActivityRingPainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.shortestSide * 0.085).clamp(2.0, 3.0);
    final rect = (Offset.zero & size).deflate(width);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    canvas.drawOval(rect, paint..color = color.withValues(alpha: 0.12));
    final phase = progress.value * math.pi * 2;
    final sweep = math.pi * (0.8 + 0.4 * math.sin(phase));
    canvas.drawArc(
      rect,
      phase - math.pi / 2,
      sweep,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ActivityRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

class AppActivityLine extends StatelessWidget {
  const AppActivityLine({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 3,
      width: double.infinity,
      child: AppMotionTimeline(
        duration: const Duration(milliseconds: 1600),
        repeat: true,
        builder: (context, progress) => RepaintBoundary(
          child: CustomPaint(
            painter: _ActivityLinePainter(
              progress,
              colors.primary,
              colors.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityLinePainter extends CustomPainter {
  _ActivityLinePainter(this.progress, this.color, this.track)
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2),
    );
    canvas.drawRRect(bounds, Paint()..color = track);
    final length = size.width * 0.28;
    final x =
        (size.width + length) *
            Curves.easeInOutCubic.transform(progress.value) -
        length;
    canvas.save();
    canvas.clipRRect(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, length, size.height),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ActivityLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.progress != progress;
}

/// A single outlined circle followed by a drawn check, then completely idle.
class AppSuccessMark extends StatelessWidget {
  const AppSuccessMark({
    super.key,
    this.size = 84,
    this.label = 'Order confirmed',
  });

  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: AppMotionTimeline(
          duration: AppMotion.emphasis,
          builder: (context, progress) => RepaintBoundary(
            child: CustomPaint(
              painter: _SuccessPainter(
                progress,
                colors.primary,
                colors.primaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.progress, this.color, this.background)
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final center = size.center(Offset.zero);
    final p = progress.value;
    final scale = 0.92 + 0.08 * Curves.easeOutCubic.transform(p);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, unit / 2, Paint()..color = background);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final circle = const Interval(
      0,
      0.55,
      curve: Curves.easeOutCubic,
    ).transform(p);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.43),
      -math.pi / 2,
      math.pi * 2 * circle,
      false,
      stroke
        ..color = color.withValues(alpha: 0.24)
        ..strokeWidth = unit * 0.018,
    );
    final check = Path()
      ..moveTo(unit * 0.29, unit * 0.51)
      ..lineTo(unit * 0.44, unit * 0.65)
      ..lineTo(unit * 0.72, unit * 0.36);
    final amount = const Interval(
      0.25,
      1,
      curve: Curves.easeOutCubic,
    ).transform(p);
    final metric = check.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * amount),
      stroke
        ..color = color
        ..strokeWidth = unit * 0.045,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.progress != progress;
}

/// Thin circular reveal around a safely padded, uncropped brand mark.
class AppBrandFrame extends StatelessWidget {
  const AppBrandFrame({super.key, required this.progress, required this.child});
  final Animation<double> progress;
  final Widget child;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      foregroundPainter: _BrandFramePainter(
        progress,
        Theme.of(context).colorScheme.secondary,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: child,
      ),
    ),
  );
}

class _BrandFramePainter extends CustomPainter {
  _BrandFramePainter(this.progress, Color color)
    : _stroke = (Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round),
      super(repaint: progress);
  final Animation<double> progress;
  final Paint _stroke;
  @override
  void paint(Canvas canvas, Size size) {
    final phase = Curves.easeOutCubic.transform(progress.value);
    canvas.drawArc(
      (Offset.zero & size).deflate(15),
      -.6 - .2 * phase,
      math.pi * 1.72 * phase,
      false,
      _stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandFramePainter old) =>
      old.progress != progress || old._stroke.color != _stroke.color;
}

/// A single light sweep over static skeletons; no shader mask or per-card clock.
class AppSkeletonSweep extends StatelessWidget {
  const AppSkeletonSweep({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (appReduceMotion(context)) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppMotionTimeline(
      duration: const Duration(milliseconds: 1400),
      repeat: true,
      builder: (context, progress) => RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: _SkeletonSweepPainter(
            progress,
            Colors.white.withValues(alpha: dark ? .035 : .32),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SkeletonSweepPainter extends CustomPainter {
  _SkeletonSweepPainter(this.progress, Color color)
    : _paint = (Paint()..color = color),
      super(repaint: progress);
  final Animation<double> progress;
  final Paint _paint;
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * .12;
    final x = (size.width + width) * progress.value - width;
    final left = x.clamp(0.0, size.width);
    final right = (x + width).clamp(0.0, size.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, 0, right, size.height),
        const Radius.circular(8),
      ),
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SkeletonSweepPainter old) =>
      old.progress != progress || old._paint.color != _paint.color;
}

/// Camera decoration only. It neither reads a code nor reports scan success.
class AppScanBeam extends StatelessWidget {
  const AppScanBeam({super.key, this.active = true, this.frameSize});
  final bool active;
  final Size? frameSize;
  @override
  Widget build(BuildContext context) {
    if (!active || appReduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AppMotionTimeline(
        duration: const Duration(milliseconds: 1800),
        repeat: true,
        builder: (context, progress) => RepaintBoundary(
          child: CustomPaint(painter: _ScanBeamPainter(progress, frameSize)),
        ),
      ),
    );
  }
}

class _ScanBeamPainter extends CustomPainter {
  _ScanBeamPainter(this.progress, this.frameSize) : super(repaint: progress);
  final Animation<double> progress;
  final Size? frameSize;
  final Paint _line = Paint()
    ..color = const Color(0xFFBE6F7C)
    ..strokeWidth = 2;
  @override
  void paint(Canvas canvas, Size size) {
    final width = frameSize?.width ?? size.width * .72;
    final height = frameSize?.height ?? width * .62;
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: height,
    ).deflate(12);
    final y =
        frame.top +
        frame.height * (.5 - .5 * math.cos(progress.value * math.pi * 2));
    canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), _line);
  }

  @override
  bool shouldRepaint(covariant _ScanBeamPainter old) =>
      old.progress != progress || old.frameSize != frameSize;
}
