import 'package:flutter/material.dart';

import '../theme.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 52, height: 52, child: CustomPaint(painter: _LogoPainter())),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Flood Alert System',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.river, height: 1),
              ),
              SizedBox(height: 4),
              Text('Live water levels from your station', style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 52;
    canvas.scale(s);
    canvas.drawRRect(RRect.fromLTRBR(0, 0, 52, 52, const Radius.circular(12)), Paint()..color = AppColors.river);
    canvas.drawRRect(RRect.fromLTRBR(21, 8, 31, 44, const Radius.circular(2)), Paint()..color = Colors.white);
    final tick = Paint()
      ..color = AppColors.river
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final y = 14.0 + i * 6;
      canvas.drawLine(Offset(21, y), Offset(i.isEven ? 26 : 28, y), tick);
    }
    final wave = Path()..moveTo(6, 34);
    for (var x = 6.0; x < 46; x += 8) {
      wave.cubicTo(x + 2, 34, x + 2, 31, x + 4, 31);
      wave.cubicTo(x + 6, 31, x + 6, 34, x + 8, 34);
    }
    wave
      ..lineTo(46, 49)
      ..lineTo(6, 49)
      ..close();
    canvas.save();
    canvas.clipRRect(RRect.fromLTRBR(0, 0, 52, 52, const Radius.circular(12)));
    canvas.drawPath(wave, Paint()..color = AppColors.water);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
