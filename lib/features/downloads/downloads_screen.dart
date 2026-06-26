import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/sheep_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../core/widgets/wool_progress.dart';
import '../../data/db/app_database.dart';
import '../../data/download/download_provider.dart';
import 'downloads_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SheepColors.of(context);
    final activeAsync = ref.watch(activeDownloadsProvider);
    final completedAsync = ref.watch(completedDownloadsProvider);
    final isPaused = ref.watch(downloadPausedProvider);

    final active = activeAsync.valueOrNull ?? const [];
    final completed = completedAsync.valueOrNull ?? const [];
    final totalChapters =
        active.length + completed.fold(0, (s, e) => s + e.chapterCount);
    final diskAsync = ref.watch(downloadsDiskUsageProvider);
    final diskStr = diskAsync.when(
      data: (bytes) {
        if (bytes == 0) return '—';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      },
      loading: () => '…',
      error: (_, __) => '—',
    );

    void togglePause() {
      final ds = ref.read(downloadServiceProvider);
      if (isPaused) {
        ref.read(downloadPausedProvider.notifier).state = false;
        ds.resume();
      } else {
        ref.read(downloadPausedProvider.notifier).state = true;
        ds.pause();
      }
    }

    void cancelDownload(String chapterId) {
      ref.read(downloadServiceProvider).cancel(chapterId);
    }

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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Downloads',
                            style: TextStyle(
                              fontFamily: fontDisplay,
                              fontWeight: FontWeight.w700,
                              fontSize: 28,
                              height: 1.1,
                              color: c.ink,
                            ),
                          ),
                          if (active.isNotEmpty)
                            GestureDetector(
                              onTap: togglePause,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.wool,
                                    borderRadius: BorderRadius.circular(
                                      radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    isPaused ? 'Resume' : 'Pause',
                                    style: TextStyle(
                                      fontFamily: fontDisplay,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      height: 1,
                                      color: c.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                                if (isPaused)
                                  Text(
                                    'Paused',
                                    style: TextStyle(
                                      fontFamily: fontMono,
                                      fontSize: 12,
                                      height: 1,
                                      color: c.slate,
                                    ),
                                  )
                                else
                                  Text(
                                    diskStr,
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
                          isPaused
                              ? 'QUEUED · ${active.length}'
                              : 'DOWNLOADING · ${active.length}',
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
                        (context, i) => _ActiveDownloadItem(
                          entry: active[i],
                          isPaused: isPaused,
                          onCancel: () => cancelDownload(active[i].chapterId),
                          c: c,
                        ),
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
  const _ActiveDownloadItem({
    required this.entry,
    required this.isPaused,
    required this.onCancel,
    required this.c,
  });

  final ActiveDownloadEntry entry;
  final bool isPaused;
  final VoidCallback onCancel;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    final pct = entry.progress.clamp(0, 100);
    final isDownloading = entry.status == 'downloading' && !isPaused;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          WoolProgress(progress: isDownloading ? pct / 100 : 0),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.mangaTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2,
                          color: c.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPaused
                          ? 'Queued'
                          : isDownloading
                              ? '$pct%'
                              : 'Waiting',
                      style: TextStyle(
                        fontFamily: fontMono,
                        fontSize: 12,
                        height: 1,
                        color: isPaused ? c.slate : c.ink,
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
                    value: isDownloading ? pct / 100 : null,
                    backgroundColor: Color.lerp(c.ink, Colors.transparent, 0.9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPaused ? c.slate : c.ink,
                    ),
                    minHeight: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Cancel button
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.wool,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: SvgPicture.string(
                  '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"'
                  ' stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round">'
                  '<line x1="2" y1="2" x2="10" y2="10"/>'
                  '<line x1="10" y1="2" x2="2" y2="10"/>'
                  '</svg>',
                  width: 12,
                  height: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completed item ────────────────────────────────────────────────────────────

class _CompletedItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final coverPath = ref
        .watch(downloadMangaCoverProvider(entry.mangaId))
        .valueOrNull ?? '';
    final coverFile = coverPath.isNotEmpty ? File(coverPath) : null;
    final hasCover = coverFile != null && coverFile.existsSync();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: hasCover
                  ? Image.file(
                      coverFile,
                      width: 36,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _coverPlaceholder,
                    )
                  : _coverPlaceholder,
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

  Widget get _coverPlaceholder => Container(
        width: 36,
        height: 48,
        color: _color,
      );
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
          SvgPicture.asset(
            'assets/svg/wool_mascot.svg',
            width: 88,
            height: 88,
          ),
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
