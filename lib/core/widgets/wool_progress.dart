import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

// Static wool mascot where filled puffs represent progress (0.0–1.0).
// 6 puffs total; filled = (progress * 6).round().
class WoolProgress extends StatelessWidget {
  const WoolProgress({required this.progress, this.size = 44, super.key});

  final double progress; // 0.0–1.0
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 112 / 100),
      painter: _WoolProgressPainter(progress.clamp(0.0, 1.0)),
    );
  }
}

class _WoolProgressPainter extends CustomPainter {
  _WoolProgressPainter(this.progress);

  final double progress;

  // Same puff order as the SVG mascot (bottom-to-top = first to fill).
  static const _puffs = [
    (cx: 50.0, cy: 68.0, r: 20.0),
    (cx: 33.0, cy: 65.0, r: 15.0),
    (cx: 67.0, cy: 65.0, r: 15.0),
    (cx: 60.0, cy: 51.0, r: 13.0),
    (cx: 40.0, cy: 50.0, r: 11.0),
    (cx: 50.0, cy: 47.0, r: 12.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.scale(scale, scale);

    final filledCount = (progress * _puffs.length).round();
    final filledPaint = Paint()..color = ink;
    final fadedPaint = Paint()..color = ink.withAlpha(26); // opacity .1

    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      canvas.drawCircle(Offset(p.cx, p.cy), p.r,
          i < filledCount ? filledPaint : fadedPaint);
    }

    // Fixed elements
    final bodyPaint = Paint()..color = ink;
    final eyePaint = Paint()..color = paper;

    // Head
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 29), width: 24, height: 26),
      bodyPaint,
    );
    // Ears
    canvas.save();
    canvas.translate(38, 19);
    canvas.rotate(-22 * pi / 180);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 12, height: 16), bodyPaint);
    canvas.restore();
    canvas.save();
    canvas.translate(62, 19);
    canvas.rotate(22 * pi / 180);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 12, height: 16), bodyPaint);
    canvas.restore();
    // Legs
    for (final (x, y) in const [
      (28.0, 85.0),
      (40.0, 86.0),
      (51.0, 86.0),
      (63.0, 85.0),
    ]) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + 9, y + 22, const Radius.circular(4.5)),
        bodyPaint,
      );
    }
    // Eyes
    canvas.drawCircle(const Offset(45, 26), 2.2, eyePaint);
    canvas.drawCircle(const Offset(55, 26), 2.2, eyePaint);
  }

  @override
  bool shouldRepaint(_WoolProgressPainter old) => old.progress != progress;
}
