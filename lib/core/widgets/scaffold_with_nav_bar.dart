import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../theme/tokens.dart';

// SVG icons extracted directly from the Sheep.dc.html prototype

const _iconLibraryActive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="7" height="16" rx="1.5" fill="#0A0A0A"/><rect x="11" y="2" width="7" height="16" rx="1.5" fill="#0A0A0A"/></svg>''';

const _iconLibraryInactive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="7" height="16" rx="1.5" stroke="#6B6B6B" stroke-width="1.5"/><rect x="11" y="2" width="7" height="16" rx="1.5" stroke="#6B6B6B" stroke-width="1.5"/></svg>''';

const _iconBrowseActive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="8" stroke="#0A0A0A" stroke-width="1.5"/><path d="M13 7l-2.5 3.5-3.5 2.5 2.5-3.5L13 7z" fill="#0A0A0A"/></svg>''';

const _iconBrowseInactive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="8" stroke="#6B6B6B" stroke-width="1.5"/><path d="M13 7l-2.5 3.5-3.5 2.5 2.5-3.5L13 7z" fill="#6B6B6B"/></svg>''';

const _iconDownloadsActive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" stroke="#0A0A0A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="10" y1="3" x2="10" y2="13"/><polyline points="6,9 10,13 14,9"/><line x1="3" y1="17" x2="17" y2="17"/></svg>''';

const _iconDownloadsInactive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="10" y1="3" x2="10" y2="13"/><polyline points="6,9 10,13 14,9"/><line x1="3" y1="17" x2="17" y2="17"/></svg>''';

const _iconSettingsActive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" stroke="#0A0A0A" stroke-width="1.5" stroke-linecap="round"><circle cx="10" cy="10" r="3"/><path d="M10 2v1.5M10 16.5V18M2 10h1.5M16.5 10H18M4.1 4.1l1 1M14.9 14.9l1 1M4.1 15.9l1-1M14.9 5.1l1-1"/></svg>''';

const _iconSettingsInactive = '''<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round"><circle cx="10" cy="10" r="3"/><path d="M10 2v1.5M10 16.5V18M2 10h1.5M16.5 10H18M4.1 4.1l1 1M14.9 14.9l1 1M4.1 15.9l1-1M14.9 5.1l1-1"/></svg>''';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _labels = ['Library', 'Browse', 'Downloads', 'Settings'];
  static const _activeIcons = [
    _iconLibraryActive,
    _iconBrowseActive,
    _iconDownloadsActive,
    _iconSettingsActive,
  ];
  static const _inactiveIcons = [
    _iconLibraryInactive,
    _iconBrowseInactive,
    _iconDownloadsInactive,
    _iconSettingsInactive,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0x0F000000), width: 1)),
          ),
          child: Row(
            children: List.generate(
              ScaffoldWithNavBar._labels.length,
              (i) => _NavItem(
                label: ScaffoldWithNavBar._labels[i],
                activeSvg: ScaffoldWithNavBar._activeIcons[i],
                inactiveSvg: ScaffoldWithNavBar._inactiveIcons[i],
                selected: currentIndex == i,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ),
        Container(
          height: 22,
          color: Colors.white,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 9),
          child: Container(
            width: 130,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x260A0A0A),
              borderRadius: BorderRadius.circular(radiusPill),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.activeSvg,
    required this.inactiveSvg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String activeSvg;
  final String inactiveSvg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.string(selected ? activeSvg : inactiveSvg),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 9,
                color: selected ? ink : slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
