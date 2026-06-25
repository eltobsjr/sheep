import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/sheep_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/settings/settings_repository.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SheepColors.of(context);
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 1.1,
                    color: c.ink,
                  ),
                ),
              ),
            ),

            // ── Reading ───────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _SectionLabel('Reading', c: c)),

            SliverToBoxAdapter(
              child: _SegmentedRow(
                label: 'Default mode',
                options: const ['Paginated', 'Scroll'],
                values: const ['paginated', 'scroll'],
                selected: s.readingMode,
                onChanged: n.setReadingMode,
                c: c,
              ),
            ),

            SliverToBoxAdapter(
              child: _SegmentedRow(
                label: 'Direction',
                options: const ['→ L to R', 'R to L ←'],
                values: const ['ltr', 'rtl'],
                selected: s.direction,
                onChanged: n.setDirection,
                c: c,
              ),
            ),

            SliverToBoxAdapter(
              child: _ToggleRow(
                label: 'Keep screen on',
                value: s.keepScreenOn,
                onChanged: n.setKeepScreenOn,
                c: c,
              ),
            ),

            // ── Downloads ─────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _SectionLabel('Downloads', c: c)),

            SliverToBoxAdapter(
              child: _ToggleRow(
                label: 'Wi-Fi only',
                subtitle: 'Skip mobile data',
                value: s.wifiOnly,
                onChanged: n.setWifiOnly,
                c: c,
              ),
            ),

            SliverToBoxAdapter(
              child: _ChevronRow(label: 'Image quality', value: 'High', c: c),
            ),

            // ── Appearance ───────────────────────────────────────────────────
            SliverToBoxAdapter(child: _SectionLabel('Appearance', c: c)),

            SliverToBoxAdapter(
              child: _SegmentedRow(
                label: 'Theme',
                options: const ['Light', 'Dark'],
                values: const ['light', 'dark'],
                selected: s.theme,
                onChanged: n.setTheme,
                c: c,
              ),
            ),

            // ── About ────────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _SectionLabel('About', c: c)),

            SliverToBoxAdapter(child: _AboutRow(c: c)),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.c});

  final String label;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          height: 1,
          letterSpacing: 10 * 0.08,
          color: c.slate,
        ),
      ),
    );
  }
}

// ── Segmented pill control ────────────────────────────────────────────────────

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.options,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.c,
  });

  final String label;
  final List<String> options;
  final List<String> values;
  final String selected;
  final void Function(String) onChanged;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, height: 1.2, color: c.ink),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.wool,
              borderRadius: const BorderRadius.all(Radius.circular(radiusPill)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(options.length, (i) {
                final isActive = values[i] == selected;
                return GestureDetector(
                  onTap: () => onChanged(values[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? c.ink : Colors.transparent,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(radiusPill),
                      ),
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1,
                        color: isActive ? c.paper : c.slate,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.c,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: c.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: c.slate,
                    ),
                  ),
                ],
              ],
            ),
            _Toggle(value: value, c: c),
          ],
        ),
      ),
    );
  }
}

// ── Toggle widget ─────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.c});

  final bool value;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 44,
      height: 24,
      decoration: BoxDecoration(
        color: value ? c.ink : c.wool,
        borderRadius: const BorderRadius.all(Radius.circular(radiusPill)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            right: value ? 3 : null,
            left: value ? null : 3,
            top: 3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: c.paper,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chevron row ───────────────────────────────────────────────────────────────

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.label,
    required this.value,
    required this.c,
  });

  final String label;
  final String value;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, height: 1.2, color: c.ink),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 13, height: 1, color: c.slate),
              ),
              const SizedBox(width: 4),
              SvgPicture.string(
                '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
                ' stroke="#6B6B6B" stroke-width="1.3" stroke-linecap="round">'
                '<path d="M5 3l4 4-4 4"/></svg>',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(c.slate, BlendMode.srcIn),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── About row ─────────────────────────────────────────────────────────────────

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.c});

  final SheepColors c;

  static const _woolSvg = '''
<svg width="36" height="40" viewBox="0 0 100 112" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="68" r="20" fill="#0A0A0A"/>
  <circle cx="33" cy="65" r="15" fill="#0A0A0A"/>
  <circle cx="67" cy="65" r="15" fill="#0A0A0A"/>
  <circle cx="40" cy="50" r="11" fill="#0A0A0A"/>
  <circle cx="60" cy="51" r="13" fill="#0A0A0A"/>
  <circle cx="50" cy="47" r="12" fill="#0A0A0A"/>
  <ellipse cx="50" cy="29" rx="12" ry="13" fill="#0A0A0A"/>
  <ellipse cx="38" cy="19" rx="6" ry="8" fill="#0A0A0A" transform="rotate(-22 38 19)"/>
  <ellipse cx="62" cy="19" rx="6" ry="8" fill="#0A0A0A" transform="rotate(22 62 19)"/>
  <rect x="28" y="85" width="9" height="22" rx="4.5" fill="#0A0A0A"/>
  <rect x="40" y="86" width="9" height="22" rx="4.5" fill="#0A0A0A"/>
  <rect x="51" y="86" width="9" height="22" rx="4.5" fill="#0A0A0A"/>
  <rect x="63" y="85" width="9" height="22" rx="4.5" fill="#0A0A0A"/>
  <circle cx="45" cy="26" r="2.2" fill="#FAFAFA"/>
  <circle cx="55" cy="26" r="2.2" fill="#FAFAFA"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          SvgPicture.string(
            _woolSvg,
            width: 36,
            height: 40,
            colorFilter: ColorFilter.mode(c.ink, BlendMode.srcIn),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sheep',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'v0.1.0 · offline-first',
                  style: TextStyle(
                    fontFamily: fontMono,
                    fontSize: 11,
                    height: 1,
                    color: c.slate,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: c.wool,
              borderRadius: const BorderRadius.all(Radius.circular(radiusPill)),
            ),
            child: Text(
              'Source ↗',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
