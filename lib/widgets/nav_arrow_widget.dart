import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/bluetooth_service.dart';
import '../utils/app_theme.dart';

class NavArrowWidget extends StatelessWidget {
  final NavDirection direction;
  final double size;
  final Color? color;

  const NavArrowWidget({
    super.key,
    required this.direction,
    this.size = 64,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (direction == NavDirection.arrive ? AppColors.green : AppColors.blue);
    return SizedBox(
      width: size,
      height: size,
      child:
          CustomPaint(painter: _ArrowPainter(direction: direction, color: c)),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final NavDirection direction;
  final Color color;

  const _ArrowPainter({required this.direction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (direction) {
      case NavDirection.straight:
        _drawStraight(canvas, size, paint);
        break;
      case NavDirection.left:
        _drawLeft(canvas, size, paint);
        break;
      case NavDirection.right:
        _drawRight(canvas, size, paint);
        break;
      case NavDirection.uTurn:
        _drawUTurn(canvas, size, paint);
        break;
      case NavDirection.arrive:
        _drawArrive(canvas, size, paint);
        break;
      case NavDirection.roundabout:
        _drawRoundabout(canvas, size, paint);
        break;
    }
  }

  void _drawStraight(Canvas canvas, Size s, Paint p) {
    canvas.drawLine(Offset(s.width * 0.5, s.height * 0.85),
        Offset(s.width * 0.5, s.height * 0.2), p);
    _drawArrowHead(canvas, s, Offset(s.width * 0.5, s.height * 0.15), -90, p);
  }

  void _drawLeft(Canvas canvas, Size s, Paint p) {
    final path = Path()
      ..moveTo(s.width * 0.65, s.height * 0.82)
      ..lineTo(s.width * 0.65, s.height * 0.42)
      ..quadraticBezierTo(
          s.width * 0.65, s.height * 0.2, s.width * 0.36, s.height * 0.2)
      ..lineTo(s.width * 0.2, s.height * 0.2);
    canvas.drawPath(path, p);
    _drawArrowHead(canvas, s, Offset(s.width * 0.15, s.height * 0.2), 180, p);
  }

  void _drawRight(Canvas canvas, Size s, Paint p) {
    final path = Path()
      ..moveTo(s.width * 0.35, s.height * 0.82)
      ..lineTo(s.width * 0.35, s.height * 0.42)
      ..quadraticBezierTo(
          s.width * 0.35, s.height * 0.2, s.width * 0.64, s.height * 0.2)
      ..lineTo(s.width * 0.8, s.height * 0.2);
    canvas.drawPath(path, p);
    _drawArrowHead(canvas, s, Offset(s.width * 0.85, s.height * 0.2), 0, p);
  }

  void _drawUTurn(Canvas canvas, Size s, Paint p) {
    final rect = Rect.fromLTWH(
        s.width * 0.25, s.height * 0.18, s.width * 0.5, s.height * 0.5);
    canvas.drawArc(rect, math.pi, math.pi, false, p);
    canvas.drawLine(Offset(s.width * 0.25, s.height * 0.43),
        Offset(s.width * 0.25, s.height * 0.82), p);
    _drawArrowHead(canvas, s, Offset(s.width * 0.75, s.height * 0.43), 90, p);
  }

  void _drawArrive(Canvas canvas, Size s, Paint p) {
    final fill = Paint()
      ..color = p.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(s.width * 0.5, s.height * 0.36), s.width * 0.22, fill);
    canvas.drawCircle(Offset(s.width * 0.5, s.height * 0.36), s.width * 0.09,
        Paint()..color = AppColors.background);
    final tail = Path()
      ..moveTo(s.width * 0.38, s.height * 0.52)
      ..lineTo(s.width * 0.5, s.height * 0.82)
      ..lineTo(s.width * 0.62, s.height * 0.52)
      ..close();
    canvas.drawPath(tail, fill);
  }

  void _drawRoundabout(Canvas canvas, Size s, Paint p) {
    canvas.drawCircle(Offset(s.width * 0.5, s.height * 0.5), s.width * 0.28, p);
    canvas.drawLine(Offset(s.width * 0.74, s.height * 0.78),
        Offset(s.width * 0.64, s.height * 0.66), p);
    _drawArrowHead(canvas, s, Offset(s.width * 0.7, s.height * 0.24), -60, p);
  }

  void _drawArrowHead(
      Canvas canvas, Size s, Offset tip, double angleDeg, Paint p) {
    final angle = angleDeg * math.pi / 180;
    final len = s.width * 0.18;
    const spread = 0.55;
    final left = Offset(tip.dx + len * math.cos(angle + spread),
        tip.dy + len * math.sin(angle + spread));
    final right = Offset(tip.dx + len * math.cos(angle - spread),
        tip.dy + len * math.sin(angle - spread));
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}
