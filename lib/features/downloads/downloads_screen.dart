import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final activeAsync = ref.watch(activeDownloadsProvider);
    final completedAsync = ref.watch(completedDownloadsProvider);

    final active = activeAsync.valueOrNull ?? const [];
    final completed = completedAsync.valueOrNull ?? const [];
    final totalChapters = active.length + completed.fold(0, (s, e) => s + e.chapterCount);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: completedAsync.isLoading && activeAsync.isLoading
            ? const Center(child: WoolLoading())
            : CustomScrollView(
                slivers: [
                  // ── Header ─────────────────────────────────────────────────
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text(
                        'Downloads',
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          height: 1.1,
                          color: ink,
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
                            decoration: const BoxDecoration(
                              color: wool,
                              borderRadius: BorderRadius.all(
                                Radius.circular(radiusPill),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '—',
                                  style: TextStyle(
                                    fontFamily: fontMono,
                                    fontSize: 12,
                                    height: 1,
                                    color: ink,
                                  ),
                                ),
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: slate,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '$totalChapters chapters',
                                  style: const TextStyle(
                                    fontFamily: fontMono,
                                    fontSize: 12,
                                    height: 1,
                                    color: slate,
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
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 10 * 0.08,
                            color: slate,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _ActiveDownloadItem(entry: active[i]),
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
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 10 * 0.08,
                            color: slate,
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
                        ),
                        childCount: completed.length,
                      ),
                    ),
                  ],

                  // ── Empty state ─────────────────────────────────────────────
                  if (active.isEmpty && completed.isEmpty)
                    const SliverFillRemaining(
                      child: _EmptyDownloads(),
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
  const _ActiveDownloadItem({required this.entry});

  final ActiveDownloadEntry entry;

  @override
  Widget build(BuildContext context) {
    final pct = entry.progress.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0F0A0A0A))),
      ),
      child: Row(
        children: [
          // Wool progress mascot: 44×50
          WoolProgress(progress: pct / 100),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.mangaTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.2,
                        color: ink,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontFamily: fontMono,
                        fontSize: 13,
                        height: 1,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.chapterTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1,
                    color: slate,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: const Color(0x1A0A0A0A),
                    valueColor: const AlwaysStoppedAnimation<Color>(ink),
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
  const _CompletedItem({required this.entry, required this.onTap});

  final CompletedDownloadEntry entry;
  final VoidCallback onTap;

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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x0F0A0A0A))),
        ),
        child: Row(
          children: [
            // Mini cover: 36×48
            Container(
              width: 36,
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.mangaTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.2,
                      color: ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.chapterCount} ch',
                    style: const TextStyle(
                      fontFamily: fontMono,
                      fontSize: 11,
                      height: 1,
                      color: slate,
                    ),
                  ),
                ],
              ),
            ),
            // Checkmark circle
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: wool,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check,
                size: 12,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          WoolLoading(size: 88),
          SizedBox(height: 20),
          Text(
            'No downloads yet',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.2,
              color: ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Download chapters to read them offline',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.6, color: slate),
          ),
        ],
      ),
    );
  }
}
