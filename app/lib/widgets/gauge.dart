import 'package:flutter/material.dart';

import '../theme.dart';

void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
  const dash = 4.0;
  final len = (b - a).distance;
  final dir = (b - a) / len;
  for (var d = 0.0; d < len; d += dash * 2) {
    canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, len), p);
  }
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

/// Water level over a time window (whole hours around the data): gaps over 5 minutes break the line.
class DayChartPainter extends CustomPainter {
  DayChartPainter({
    required this.start,
    required this.end,
    required this.points,
    required this.max,
    required this.warn,
    required this.crit,
  });
  final DateTime start, end;
  final List<({DateTime time, double level})> points; // oldest first
  final double max, warn, crit;

  static const _labelH = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _labelH;
    final span = end.difference(start).inSeconds;
    double x(DateTime t) => size.width * (t.difference(start).inSeconds / span).clamp(0.0, 1.0);
    double y(double v) => h - (v / max).clamp(0.0, 1.0) * h;

    final grid = Paint()..color = AppColors.border;
    for (var i = 0; i <= 4; i++) {
      final gx = size.width * i / 4;
      final t = start.add(Duration(seconds: span * i ~/ 4));
      final hr = t.hour % 12 == 0 ? 12 : t.hour % 12;
      canvas.drawLine(Offset(gx, 0), Offset(gx, h), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: '$hr${t.minute == 0 ? '' : ':${t.minute.toString().padLeft(2, '0')}'} ${t.hour < 12 ? 'AM' : 'PM'}',
          style: const TextStyle(fontSize: 10, color: AppColors.slate),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((gx - tp.width / 2).clamp(0, size.width - tp.width), h + 4));
    }
    canvas.drawLine(Offset(0, h), Offset(size.width, h), grid);
    _dashedLine(canvas, Offset(0, y(warn)), Offset(size.width, y(warn)), Paint()..color = AppColors.warnFill);
    _dashedLine(canvas, Offset(0, y(crit)), Offset(size.width, y(crit)), Paint()..color = AppColors.crit);

    final line = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    DateTime? prev;
    for (final p in points) {
      final o = Offset(x(p.time), y(p.level));
      if (prev == null || p.time.difference(prev).inMinutes > 5) {
        path.moveTo(o.dx, o.dy);
        canvas.drawCircle(o, 1.5, Paint()..color = AppColors.blue);
      } else {
        path.lineTo(o.dx, o.dy);
      }
      prev = p.time;
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(DayChartPainter old) =>
      old.points != points ||
      old.start != start ||
      old.end != end ||
      old.warn != warn ||
      old.crit != crit ||
      old.max != max;
}
