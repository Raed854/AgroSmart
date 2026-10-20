import 'package:flutter/material.dart';

import '../main.dart';

class FarmIllustration extends StatelessWidget {
  const FarmIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE5F1DF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E8D0)),
      ),
      child: const CustomPaint(painter: _FarmPainter()),
    );
  }
}

class _FarmPainter extends CustomPainter {
  const _FarmPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF6E5),
    );
    canvas.drawCircle(
      Offset(size.width * .82, 36),
      17,
      Paint()..color = const Color(0xFFFFD66B).withValues(alpha: .8),
    );

    final backField = Paint()..color = const Color(0xFFB7DDAE);
    final field = Path()
      ..moveTo(0, size.height * .63)
      ..quadraticBezierTo(
        size.width * .27,
        size.height * .48,
        size.width * .53,
        size.height * .62,
      )
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .75,
        size.width,
        size.height * .57,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(field, backField);

    final nearField = Paint()..color = const Color(0xFF72B95B);
    final near = Path()
      ..moveTo(0, size.height * .77)
      ..quadraticBezierTo(
        size.width * .28,
        size.height * .6,
        size.width * .55,
        size.height * .77,
      )
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .91,
        size.width,
        size.height * .68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, nearField);

    final rows = Paint()
      ..color = const Color(0xFFB5D98E)
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (.78 + i * .07);
      canvas.drawLine(
        Offset(size.width * .08, y),
        Offset(size.width * .92, y - 14),
        rows,
      );
    }

    final stem = Paint()
      ..color = forestGreen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = freshGreen;
    for (final x in [38.0, 73.0, 108.0, 144.0]) {
      final base = Offset(x, size.height * .79);
      canvas.drawLine(base, base.translate(0, -27), stem);
      canvas.drawOval(
        Rect.fromCenter(
          center: base.translate(-6, -25),
          width: 13,
          height: 7,
        ),
        leaf,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: base.translate(6, -18),
          width: 13,
          height: 7,
        ),
        leaf,
      );
    }

    final drone = Paint()..color = Colors.white;
    final droneLine = Paint()
      ..color = forestGreen
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final droneCenter = Offset(size.width * .68, 52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: droneCenter, width: 46, height: 15),
        const Radius.circular(8),
      ),
      drone,
    );
    canvas.drawLine(
      droneCenter.translate(-19, -5),
      droneCenter.translate(-30, -14),
      droneLine,
    );
    canvas.drawLine(
      droneCenter.translate(19, -5),
      droneCenter.translate(30, -14),
      droneLine,
    );
    canvas.drawCircle(droneCenter.translate(-32, -15), 5, droneLine);
    canvas.drawCircle(droneCenter.translate(32, -15), 5, droneLine);
    canvas.drawLine(
      droneCenter.translate(-10, 7),
      droneCenter.translate(-13, 16),
      droneLine,
    );
    canvas.drawLine(
      droneCenter.translate(10, 7),
      droneCenter.translate(13, 16),
      droneLine,
    );

    final tech = Paint()
      ..color = forestGreen.withValues(alpha: .28)
      ..strokeWidth = 1;
    final center = Offset(size.width * .87, 104);
    canvas.drawCircle(center, 23, tech);
    canvas.drawCircle(center, 12, tech);
    canvas.drawLine(center.translate(0, -23), center.translate(0, 23), tech);
    canvas.drawLine(center.translate(-13, 0), center.translate(13, 0), tech);
    canvas.drawCircle(center, 3, Paint()..color = forestGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
