import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/app_database.dart';
import '../../data/sources/source_registry.dart';
import 'library_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangasAsync = ref.watch(libraryMangasProvider);
    final lastReadAsync = ref.watch(lastReadProvider);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: mangasAsync.when(
          loading: () => const Center(child: WoolLoading()),
          error: (e, _) => const _LibraryHeader(showSearch: false),
          data: (mangas) => mangas.isEmpty
              ? _EmptyState(onBrowse: () => context.go('/browse'))
              : _FilledState(
                  mangas: mangas,
                  lastRead: lastReadAsync.valueOrNull,
                  onMangaTap: (id) => context.go('/manga/$id'),
                  onReadTap: (mangaId, chapterId) =>
                      context.go('/reader/$mangaId/$chapterId'),
                  onSearchTap: () => context.go('/browse/search'),
                ),
        ),
      ),
    );
  }
}

// ── Empty state (Frame 8) ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — no search button in empty state
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            'Library',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              height: 1.1,
              color: ink,
            ),
          ),
        ),
        // Centered content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/svg/wool_mascot.svg',
                  width: 88,
                  height: 100,
                  colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your library is empty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1.2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browse sources to find manga and add your first series',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: slate,
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: onBrowse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 13,
                    ),
                    decoration: const BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
                    ),
                    child: const Text(
                      'Browse manga',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1,
                        color: paper,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filled state (Frame 1) ────────────────────────────────────────────────────

class _FilledState extends StatelessWidget {
  const _FilledState({
    required this.mangas,
    required this.lastRead,
    required this.onMangaTap,
    required this.onReadTap,
    required this.onSearchTap,
  });

  final List<Manga> mangas;
  final LastReadEntry? lastRead;
  final void Function(String mangaId) onMangaTap;
  final void Function(String mangaId, String chapterId) onReadTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Library',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 1.1,
                    color: ink,
                  ),
                ),
                GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: wool,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.string(
                      '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"'
                      ' stroke="#0A0A0A" stroke-width="1.5" stroke-linecap="round">'
                      '<circle cx="7" cy="7" r="5"/>'
                      '<path d="M11 11l3 3"/>'
                      '</svg>',
                      width: 16,
                      height: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Continue Reading ─────────────────────────────────────────────
          if (lastRead != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTINUE READING',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      letterSpacing: 10 * 0.08,
                      color: slate,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ContinueReadingCard(
                    entry: lastRead!,
                    onRead: () => onReadTap(lastRead!.mangaId, lastRead!.chapterId),
                  ),
                ],
              ),
            ),
          ],

          // ── All section header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ALL · ${mangas.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1,
                    letterSpacing: 10 * 0.08,
                    color: slate,
                  ),
                ),
                SvgPicture.string(
                  '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
                  ' stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round">'
                  '<line x1="2" y1="4" x2="12" y2="4"/>'
                  '<line x1="4" y1="7" x2="10" y2="7"/>'
                  '<line x1="6" y1="10" x2="8" y2="10"/>'
                  '</svg>',
                  width: 14,
                  height: 14,
                ),
              ],
            ),
          ),

          // ── 2-column grid ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 2;
                const crossAxisSpacing = 12.0;
                const belowCoverHeight = 33.0; // 7 gap + ~14.4 title + 2 gap + ~10 source
                final cellWidth =
                    (constraints.maxWidth - crossAxisSpacing * (crossAxisCount - 1)) /
                    crossAxisCount;
                final coverHeight = cellWidth * 4 / 3;
                final cellHeight = coverHeight + belowCoverHeight;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 12,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemCount: mangas.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => onMangaTap(mangas[i].id),
                    child: _MangaCard(manga: mangas[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continue Reading card ─────────────────────────────────────────────────────

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.entry, required this.onRead});

  final LastReadEntry entry;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: wool,
        borderRadius: BorderRadius.circular(radiusCard),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover: 50×70
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _CoverThumbnail(
              coverPath: '',
              mangaId: entry.mangaId,
              title: entry.mangaTitle,
              width: 50,
              height: 70,
            ),
          ),
          const SizedBox(width: 12),

          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.mangaTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.chapterTitle} · Page ${entry.lastPage}'
                  '${entry.pageCount != null ? ' of ${entry.pageCount}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: slate,
                  ),
                ),
                const SizedBox(height: 10),
                // Progress bar: 2px height
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: entry.progress,
                    backgroundColor: const Color(0x1F0A0A0A),
                    valueColor: const AlwaysStoppedAnimation<Color>(ink),
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${entry.progressPercent}%',
                  style: const TextStyle(
                    fontFamily: fontMono,
                    fontSize: 10,
                    height: 1,
                    color: slate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // "Read" button — centered against the 70px cover height
          SizedBox(
            height: 70,
            child: Center(
              child: GestureDetector(
                onTap: onRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
                  ),
                  child: const Text(
                    'Read',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1,
                      color: paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid card ─────────────────────────────────────────────────────────────────

class _MangaCard extends StatelessWidget {
  const _MangaCard({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final sourceName = sourceById(manga.sourceId)?.name ?? manga.sourceId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover with 3:4 aspect ratio
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _CoverThumbnail(
              coverPath: manga.coverPath,
              mangaId: manga.id,
              title: manga.title,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          manga.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.2,
            color: ink,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          sourceName,
          style: const TextStyle(
            fontSize: 10,
            height: 1,
            color: slate,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Cover thumbnail (local file or colored placeholder) ───────────────────────

class _CoverThumbnail extends StatelessWidget {
  const _CoverThumbnail({
    required this.coverPath,
    required this.mangaId,
    required this.title,
    required this.width,
    required this.height,
  });

  final String coverPath;
  final String mangaId;
  final String title;
  final double width;
  final double height;

  static const _placeholderColors = [
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
      _placeholderColors[mangaId.hashCode.abs() % _placeholderColors.length];

  @override
  Widget build(BuildContext context) {
    final file = coverPath.isNotEmpty ? File(coverPath) : null;
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Placeholder(color: _color, title: title),
      );
    }
    return _Placeholder(color: _color, title: title);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color, required this.title});

  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: fontMono,
          fontSize: 8,
          height: 1.3,
          color: Color(0x66FAFAFA), // rgba(250,250,250,.4)
          letterSpacing: 8 * 0.04,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Shared header widget (used during loading) ────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.showSearch});

  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Library',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              height: 1.1,
              color: ink,
            ),
          ),
          if (showSearch)
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: wool, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
