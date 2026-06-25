import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/sheep_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../core/widgets/wool_progress.dart';
import '../../data/db/app_database.dart';
import 'downloads_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SheepColors.of(context);
    final activeAsync = ref.watch(activeDownloadsProvider);
    final completedAsync = ref.watch(completedDownloadsProvider);

    final active = activeAsync.valueOrNull ?? const [];
    final completed = completedAsync.valueOrNull ?? const [];
    final totalChapters =
        active.length + completed.fold(0, (s, e) => s + e.chapterCount);

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: completedAsync.isLoading && activeAsync.isLoading
            ? const Center(child: WoolLoading())
            : CustomScrollView(
                slivers: [
                  // ── Header ─────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text(
                        'Downloads',
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

                  // ── Disk usage pill ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: c.wool,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(radiusPill),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '—',
                                  style: TextStyle(
                                    fontFamily: fontMono,
                                    fontSize: 12,
                                    height: 1,
                                    color: c.ink,
                                  ),
                                ),
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.slate,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '$totalChapters chapters',
                                  style: TextStyle(
                                    fontFamily: fontMono,
                                    fontSize: 12,
                                    height: 1,
                                    color: c.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Active downloads ────────────────────────────────────────
                  if (active.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          'DOWNLOADING · ${active.length}',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 10 * 0.08,
                            color: c.slate,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _ActiveDownloadItem(entry: active[i], c: c),
                        childCount: active.length,
                      ),
                    ),
                  ],

                  // ── Completed ───────────────────────────────────────────────
                  if (completed.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Text(
                          'COMPLETED · ${completed.fold(0, (s, e) => s + e.chapterCount)}',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 10 * 0.08,
                            color: c.slate,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _CompletedItem(
                          entry: completed[i],
                          onTap: () =>
                              context.push('/manga/${completed[i].mangaId}'),
                          c: c,
                        ),
                        childCount: completed.length,
                      ),
                    ),
                  ],

                  // ── Empty state ─────────────────────────────────────────────
                  if (active.isEmpty && completed.isEmpty)
                    SliverFillRemaining(
                      child: _EmptyDownloads(c: c),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
      ),
    );
  }
}

// ── Active download item ───────────────────────────────────────────────────────

class _ActiveDownloadItem extends StatelessWidget {
  const _ActiveDownloadItem({required this.entry, required this.c});

  final ActiveDownloadEntry entry;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    final pct = entry.progress.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          WoolProgress(progress: pct / 100),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.mangaTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.2,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontFamily: fontMono,
                        fontSize: 13,
                        height: 1,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.chapterTitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    color: c.slate,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor:
                        Color.lerp(c.ink, Colors.transparent, 0.9),
                    valueColor: AlwaysStoppedAnimation<Color>(c.ink),
                    minHeight: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completed item ────────────────────────────────────────────────────────────

class _CompletedItem extends StatelessWidget {
  const _CompletedItem({
    required this.entry,
    required this.onTap,
    required this.c,
  });

  final CompletedDownloadEntry entry;
  final VoidCallback onTap;
  final SheepColors c;

  static const _colors = [
    Color(0xFF1A1A2E),
    Color(0xFF5C3B1E),
    Color(0xFFCC2B2B),
    Color(0xFF1B2A4A),
    Color(0xFF8B1A1A),
    Color(0xFF2D6A4F),
    Color(0xFF6B3FA0),
    Color(0xFF2A3F5A),
  ];

  Color get _color =>
      _colors[entry.mangaId.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.mangaTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.2,
                      color: c.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.chapterCount} ch',
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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: c.wool,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.check, size: 12, color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.c});

  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const WoolLoading(size: 88),
          const SizedBox(height: 20),
          Text(
            'No downloads yet',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.2,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download chapters to read them offline',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.6, color: c.slate),
          ),
        ],
      ),
    );
  }
}
