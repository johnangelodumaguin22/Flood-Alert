import 'package:flutter/material.dart';

import '../theme.dart';

class StaffGauge extends StatelessWidget {
  const StaffGauge({
    super.key,
    required this.level,
    required this.max,
    required this.warn,
    required this.crit,
    required this.fill,
  });

  final double level, max, warn, crit;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 76,
        height: 260,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (level / max).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, frac, _) => CustomPaint(
            painter: _GaugePainter(frac: frac, max: max, warn: warn, crit: crit, fill: fill),
          ),
        ),
      ),
    );
  }
}

void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
  const dash = 4.0;
  final len = (b - a).distance;
  final dir = (b - a) / len;
  for (var d = 0.0; d < len; d += dash * 2) {
    canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, len), p);
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.frac, required this.max, required this.warn, required this.crit, required this.fill});
  final double frac, max, warn, crit;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const scaleW = 28.0;
    final tube = Rect.fromLTWH(scaleW + 4, 0, size.width - scaleW - 4, size.height);
    final rr = RRect.fromRectAndRadius(tube, const Radius.circular(8));
    double yFor(double v) => tube.bottom - (v / max).clamp(0.0, 1.0) * tube.height;

    for (var v = 0; v <= max; v += 20) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$v',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(scaleW - tp.width, (yFor(v.toDouble()) - tp.height / 2).clamp(0, size.height - tp.height)),
      );
    }

    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(tube, Paint()..color = AppColors.silt);
    final tick = Paint()..color = AppColors.line;
    for (var i = 1; i < 10; i++) {
      final y = tube.bottom - tube.height * i / 10;
      canvas.drawLine(Offset(tube.left, y), Offset(tube.right, y), tick);
    }
    canvas.drawRect(
      Rect.fromLTRB(tube.left, tube.bottom - tube.height * frac, tube.right, tube.bottom),
      Paint()..color = fill,
    );
    final dashW = Paint()
      ..color = AppColors.warnFill
      ..strokeWidth = 2;
    final dashC = Paint()
      ..color = AppColors.crit
      ..strokeWidth = 2;
    _dashedLine(canvas, Offset(tube.left, yFor(warn)), Offset(tube.right, yFor(warn)), dashW);
    _dashedLine(canvas, Offset(tube.left, yFor(crit)), Offset(tube.right, yFor(crit)), dashC);
    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.line,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.frac != frac || old.fill != fill || old.warn != warn || old.crit != crit || old.max != max;
}

class SparklinePainter extends CustomPainter {
  SparklinePainter({
    required this.points,
    required this.max,
    required this.warn,
    required this.crit,
    required this.color,
  });
  final List<double> points; // oldest first
  final double max, warn, crit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double v) => size.height - (v / max).clamp(0.0, 1.0) * size.height;
    _dashedLine(canvas, Offset(0, y(warn)), Offset(size.width, y(warn)), Paint()..color = AppColors.warnFill);
    _dashedLine(canvas, Offset(0, y(crit)), Offset(size.width, y(crit)), Paint()..color = AppColors.crit);

    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (points.length == 1) {
      canvas.drawCircle(Offset(size.width, y(points.first)), 3, line..style = PaintingStyle.fill);
      return;
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(size.width * i / (points.length - 1), y(points[i]));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(SparklinePainter old) => old.points != points || old.color != color;
}
