import 'package:flutter/material.dart';

class SheepColors extends ThemeExtension<SheepColors> {
  const SheepColors({
    required this.ink,
    required this.paper,
    required this.charcoal,
    required this.wool,
    required this.slate,
    required this.border,
  });

  final Color ink;
  final Color paper;
  final Color charcoal;
  final Color wool;
  final Color slate;
  final Color border;

  static const light = SheepColors(
    ink: Color(0xFF0A0A0A),
    paper: Color(0xFFFAFAFA),
    charcoal: Color(0xFF1C1C1C),
    wool: Color(0xFFE8E8E8),
    slate: Color(0xFF6B6B6B),
    border: Color(0x0F0A0A0A),
  );

  static const dark = SheepColors(
    ink: Color(0xFFFAFAFA),
    paper: Color(0xFF0A0A0A),
    charcoal: Color(0xFF1C1C1C),
    wool: Color(0xFF2A2A2A),
    slate: Color(0xFF9B9B9B),
    border: Color(0x0FFAFAFA),
  );

  static SheepColors of(BuildContext context) =>
      Theme.of(context).extension<SheepColors>() ?? light;

  @override
  SheepColors copyWith({
    Color? ink,
    Color? paper,
    Color? charcoal,
    Color? wool,
    Color? slate,
    Color? border,
  }) =>
      SheepColors(
        ink: ink ?? this.ink,
        paper: paper ?? this.paper,
        charcoal: charcoal ?? this.charcoal,
        wool: wool ?? this.wool,
        slate: slate ?? this.slate,
        border: border ?? this.border,
      );

  @override
  SheepColors lerp(ThemeExtension<SheepColors>? other, double t) {
    if (other is! SheepColors) return this;
    return SheepColors(
      ink: Color.lerp(ink, other.ink, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      charcoal: Color.lerp(charcoal, other.charcoal, t)!,
      wool: Color.lerp(wool, other.wool, t)!,
      slate: Color.lerp(slate, other.slate, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
