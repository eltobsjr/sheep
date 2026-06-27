import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

// Wool loading animation — phases:
//   0.00–0.15  grow in      (elasticOut scale from center)
//   0.15–0.30  idle breath  (body pulse, tail sways)
//   0.30–0.82  puff shedding (anticipation up → fall with fade)
//   0.82–0.90  blink
//   0.90–1.00  fade out
class WoolLoading extends StatefulWidget {
  const WoolLoading({super.key, this.size = 120});

  final double size;

  @override
  State<WoolLoading> createState() => _WoolLoadingState();
}

class _WoolLoadingState extends State<WoolLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size * 112 / 100),
        painter: _WoolPainter(_ctrl.value),
      ),
    );
  }
}

class _WoolPainter extends CustomPainter {
  _WoolPainter(this.t);

  final double t;

  // 6 puff definitions (normalized to 100×112 viewBox).
  // Ordered bottom-to-top so lower puffs shed first (like real shearing).
  static const _puffs = [
    (cx: 50.0, cy: 68.0, r: 20.0), // body center — sheds 1st
    (cx: 33.0, cy: 65.0, r: 15.0), // body left   — sheds 2nd
    (cx: 67.0, cy: 65.0, r: 15.0), // body right  — sheds 3rd
    (cx: 40.0, cy: 50.0, r: 11.0), // puff L      — sheds 4th
    (cx: 60.0, cy: 51.0, r: 13.0), // puff R      — sheds 5th
    (cx: 50.0, cy: 47.0, r: 12.0), // puff top    — sheds 6th
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.scale(scale, scale);

    // ── Grow-in (0.00–0.15) ──────────────────────────────────────────────────
    final growT = (t / 0.15).clamp(0.0, 1.0);
    var bodyScale = Curves.elasticOut.transform(growT);

    // ── Breathing pulse (0.15–0.30) ──────────────────────────────────────────
    if (t >= 0.15 && t < 0.30) {
      final breathT = ((t - 0.15) / 0.15).clamp(0.0, 1.0);
      bodyScale *= 1.0 + sin(breathT * pi) * 0.035;
    }

    // ── Global fade-out (0.90–1.00) ──────────────────────────────────────────
    final fadeT = ((t - 0.90) / 0.10).clamp(0.0, 1.0);
    final globalOpacity = (1.0 - Curves.easeIn.transform(fadeT)).clamp(0.0, 1.0);
    final inkA = (globalOpacity * 255).round();

    // Scale the whole mascot from body center
    const pivot = Offset(50, 62);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(bodyScale);
    canvas.translate(-pivot.dx, -pivot.dy);

    // ── Tail (drawn before puffs so puffs initially cover it) ────────────────
    // Peeks out from behind the right body puff; revealed as puffs fall.
    final tailAngle = sin(t * 2 * pi * 3) * 0.22;
    canvas.save();
    canvas.translate(76, 67);
    canvas.rotate(tailAngle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 7),
      Paint()..color = ink.withAlpha(inkA),
    );
    canvas.restore();

    // ── Puff shedding (0.30–0.82) ────────────────────────────────────────────
    final shearedFraction = ((t - 0.30) / 0.52).clamp(0.0, 1.0);

    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      final puffShedAt = i / _puffs.length;
      final puffT =
          ((shearedFraction - puffShedAt) / (1.0 / _puffs.length))
              .clamp(0.0, 1.0);

      // Anticipation: puff jiggles up before falling
      final anticipateT = (puffT / 0.25).clamp(0.0, 1.0);
      final fallT = ((puffT - 0.25) / 0.75).clamp(0.0, 1.0);
      final upY = -sin(anticipateT * pi) * 5.0;
      final downY = Curves.easeIn.transform(fallT) * 44.0;

      final puffOpacity =
          (1.0 - Curves.easeIn.transform(fallT)) * globalOpacity;
      final puffScale = 1.0 - fallT * 0.3;

      canvas.save();
      canvas.translate(p.cx, p.cy + upY + downY);
      canvas.scale(puffScale);
      canvas.drawCircle(
        Offset.zero,
        p.r,
        Paint()..color = ink.withAlpha((puffOpacity * 255).round()),
      );
      canvas.restore();
    }

    // ── Head (bigger: 28×30) ──────────────────────────────────────────────────
    final bodyPaint = Paint()..color = ink.withAlpha(inkA);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 27), width: 28, height: 30),
      bodyPaint,
    );

    // ── Ears ──────────────────────────────────────────────────────────────────
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

    // ── Legs + paws ───────────────────────────────────────────────────────────
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
      // Wider oval at bottom = hoof/paw shape
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + 4, y + 19.5),
          width: 13,
          height: 6,
        ),
        bodyPaint,
      );
    }

    // ── Eyes (blink at 0.82–0.90) ────────────────────────────────────────────
    final blinkT = ((t - 0.82) / 0.08).clamp(0.0, 1.0);
    final eyeH = (2.8 * (1.0 - sin(blinkT * pi))).clamp(0.1, 2.8);
    final eyePaint = Paint()
      ..color = paper.withAlpha((globalOpacity * 255).round());

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(44, 24), width: 5.6, height: eyeH * 2),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(56, 24), width: 5.6, height: eyeH * 2),
      eyePaint,
    );

    // ── Eyebrows ──────────────────────────────────────────────────────────────
    // Relaxed during idle; determined (angled inward) during shedding.
    final shedding = t > 0.30 && t < 0.82;
    final browPaint = Paint()
      ..color = paper.withAlpha((globalOpacity * 178).round())
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(40, shedding ? 20.5 : 20.0),
      Offset(47, shedding ? 19.5 : 20.0),
      browPaint,
    );
    canvas.drawLine(
      Offset(53, shedding ? 19.5 : 20.0),
      Offset(60, shedding ? 20.5 : 20.0),
      browPaint,
    );

    // ── Mouth ────────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 32), width: 8, height: 5),
      Paint()..color = paper.withAlpha((globalOpacity * 140).round()),
    );

    canvas.restore(); // undo global body scale
  }

  @override
  bool shouldRepaint(_WoolPainter old) => old.t != t;
}
