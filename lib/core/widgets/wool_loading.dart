import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

// Wool loading animation: sheep grows in → wool puffs shed one by one,
// each falling with gravity → repeats. Matches the Sheep brand mascot exactly.
class WoolLoading extends StatefulWidget {
  const WoolLoading({super.key, this.size = 120});

  final double size;

  @override
  State<WoolLoading> createState() => _WoolLoadingState();
}

class _WoolLoadingState extends State<WoolLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Phase 0.0–0.2  → sheep grows in (scale 0→1)
  // Phase 0.2–0.8  → puffs shed in sequence (6 puffs fall)
  // Phase 0.8–1.0  → fade out, restart

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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

  final double t; // 0.0 → 1.0 animation progress

  // 6 puff definitions from the SVG (normalized to 100×112 viewBox)
  // Ordered bottom-to-top so bottom puffs shed first (like real shearing).
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

    // ── Phase: grow in ────────────────────────────────────────────────────
    final growT = (t / 0.2).clamp(0.0, 1.0);
    final globalScale = Curves.elasticOut.transform(growT);
    const pivot = Offset(50, 56); // center of the sheep body
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(globalScale);
    canvas.translate(-pivot.dx, -pivot.dy);

    // ── Paint each puff ───────────────────────────────────────────────────
    // Shearing starts at t=0.2, each puff takes 0.1 of the timeline.
    final shearedFraction = ((t - 0.2) / 0.6).clamp(0.0, 1.0);

    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      final puffShedAt = i / _puffs.length; // 0, 0.167, 0.333 …
      final puffT = ((shearedFraction - puffShedAt) / (1 / _puffs.length))
          .clamp(0.0, 1.0);

      // Before shedding: solid ink puff
      // While shedding: opacity drops, puff falls downward
      final opacity = (1.0 - puffT).clamp(0.0, 1.0);
      final fallY = puffT * puffT * 40.0; // gravity-like fall

      final paint = Paint()..color = ink.withAlpha((opacity * 255).round());
      canvas.drawCircle(Offset(p.cx, p.cy + fallY), p.r, paint);
    }

    // ── Fixed elements (always visible) ───────────────────────────────────
    final bodyPaint = Paint()..color = ink;
    final eyePaint = Paint()..color = paper;
    final mouthPaint = Paint()
      ..color = paper.withAlpha((0.55 * 255).round());

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
      Rect.fromCenter(center: Offset.zero, width: 12, height: 16),
      bodyPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(62, 19);
    canvas.rotate(22 * pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 16),
      bodyPaint,
    );
    canvas.restore();

    // Legs
    final legPaint = Paint()..color = ink;
    final legRRect = RRect.fromRectAndRadius(
      Rect.zero,
      const Radius.circular(4.5),
    );
    for (final (x, y) in const [
      (28.0, 85.0),
      (40.0, 86.0),
      (51.0, 86.0),
      (63.0, 85.0),
    ]) {
      canvas.drawRRect(
        legRRect.shift(Offset(x, y)).inflate(0).copyWith(
          top: y,
          left: x,
          right: x + 9,
          bottom: y + 22,
        ),
        legPaint,
      );
    }

    // Eyes
    canvas.drawCircle(const Offset(45, 26), 2.5, eyePaint);
    canvas.drawCircle(const Offset(55, 26), 2.5, eyePaint);

    // Mouth
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 33), width: 7, height: 5),
      mouthPaint,
    );

    canvas.restore(); // undo grow transform
  }

  @override
  bool shouldRepaint(_WoolPainter old) => old.t != t;
}

extension on RRect {
  RRect copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return RRect.fromLTRBR(
      left ?? this.left,
      top ?? this.top,
      right ?? this.right,
      bottom ?? this.bottom,
      tlRadius,
    );
  }
}
