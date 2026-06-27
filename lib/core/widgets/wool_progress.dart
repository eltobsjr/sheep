import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

// Wool mascot where filled puffs represent progress (0.0–1.0).
// The boundary puff (last filled) pulses to show active work.
class WoolProgress extends StatefulWidget {
  const WoolProgress({required this.progress, this.size = 44, super.key});

  final double progress;
  final double size;

  @override
  State<WoolProgress> createState() => _WoolProgressState();
}

class _WoolProgressState extends State<WoolProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size * 112 / 100),
        painter: _WoolProgressPainter(
          widget.progress.clamp(0.0, 1.0),
          _pulse.value,
        ),
      ),
    );
  }
}

class _WoolProgressPainter extends CustomPainter {
  _WoolProgressPainter(this.progress, this.pulse);

  final double progress;
  final double pulse; // 0.0–1.0 from reverse-repeating controller

  // Same puff order as WoolLoading (bottom-to-top = first to fill).
  static const _puffs = [
    (cx: 50.0, cy: 68.0, r: 20.0),
    (cx: 33.0, cy: 65.0, r: 15.0),
    (cx: 67.0, cy: 65.0, r: 15.0),
    (cx: 40.0, cy: 50.0, r: 11.0),
    (cx: 60.0, cy: 51.0, r: 13.0),
    (cx: 50.0, cy: 47.0, r: 12.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.scale(scale, scale);

    final filledCount = (progress * _puffs.length).round();
    final borderIdx = filledCount - 1; // last filled puff pulses

    final filledPaint = Paint()..color = ink;
    final fadedPaint = Paint()..color = ink.withAlpha(26);

    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      var r = p.r;
      // Pulse the last filled puff when partially complete
      if (i == borderIdx && progress > 0 && progress < 1.0) {
        r = p.r * (1.0 + sin(pulse * pi) * 0.12);
      }
      canvas.drawCircle(
        Offset(p.cx, p.cy),
        r,
        i < filledCount ? filledPaint : fadedPaint,
      );
    }

    // ── Head (bigger: 28×30, matching WoolLoading) ───────────────────────────
    final bodyPaint = Paint()..color = ink;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 27), width: 28, height: 30),
      bodyPaint,
    );

    // Ears
    canvas.save();
    canvas.translate(36, 15);
    canvas.rotate(-22 * pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 16),
      bodyPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(64, 15);
    canvas.rotate(22 * pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 16),
      bodyPaint,
    );
    canvas.restore();

    // Legs + paws (matching WoolLoading)
    for (final (x, y) in const [
      (28.0, 83.0),
      (40.0, 84.0),
      (51.0, 84.0),
      (63.0, 83.0),
    ]) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, y, x + 8, y + 17, const Radius.circular(4)),
        bodyPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 4, y + 19.5), width: 13, height: 6),
        bodyPaint,
      );
    }

    // Eyes
    final eyePaint = Paint()..color = paper;
    canvas.drawCircle(const Offset(44, 24), 2.5, eyePaint);
    canvas.drawCircle(const Offset(56, 24), 2.5, eyePaint);
  }

  @override
  bool shouldRepaint(_WoolProgressPainter old) =>
      old.progress != progress || old.pulse != pulse;
}
