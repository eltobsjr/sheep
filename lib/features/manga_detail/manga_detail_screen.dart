import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/app_database.dart';
import '../../data/download/download_provider.dart';
import 'manga_detail_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class MangaDetailScreen extends ConsumerStatefulWidget {
  const MangaDetailScreen({required this.mangaId, super.key});

  final String mangaId;

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  bool _synopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final mangaAsync = ref.watch(mangaWatchProvider(widget.mangaId));
    final chaptersAsync = ref.watch(chaptersWatchProvider(widget.mangaId));

    return Scaffold(
      backgroundColor: paper,
      body: mangaAsync.when(
        loading: () => const Center(child: WoolLoading()),
        error: (_, _) => const Center(child: Text('Erro ao carregar')),
        data: (manga) => _DetailBody(
          mangaId: widget.mangaId,
          manga: manga,
          chaptersAsync: chaptersAsync,
          synopsisExpanded: _synopsisExpanded,
          onToggleSynopsis: () =>
              setState(() => _synopsisExpanded = !_synopsisExpanded),
        ),
      ),
    );
  }
}

// ── Main body ────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.mangaId,
    required this.manga,
    required this.chaptersAsync,
    required this.synopsisExpanded,
    required this.onToggleSynopsis,
  });

  final String mangaId;
  final Manga? manga;
  final AsyncValue<List<Chapter>> chaptersAsync;
  final bool synopsisExpanded;
  final VoidCallback onToggleSynopsis;

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

  Color _heroColor(String id) =>
      _placeholderColors[id.hashCode.abs() % _placeholderColors.length];

  List<String> _genres(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroColor = _heroColor(mangaId);
    final title = manga?.title ?? '';
    final author = manga?.author ?? '';
    final synopsis = manga?.synopsis ?? '';
    final statusRaw = manga?.status ?? '';
    final genreList = _genres(manga?.genres);
    final inLibrary = manga?.inLibrary ?? false;
    final toggle = ref.read(toggleLibraryProvider(mangaId));

    final chapters = chaptersAsync.valueOrNull ?? const [];
    // Chapters are ordered latest first; first to read is the one with min number.
    final firstChapter = chapters.isNotEmpty
        ? chapters.reduce((a, b) => a.number < b.number ? a : b)
        : null;

    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // ── Dark hero section ────────────────────────────────────────────────
        ColoredBox(
          color: heroColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topPad),
              // Back nav row — 50px
              SizedBox(
                height: 50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: SvgPicture.string(
                          '<svg width="20" height="20" viewBox="0 0 20 20" fill="none"'
                          ' stroke="#FAFAFA" stroke-width="1.5" stroke-linecap="round"'
                          ' stroke-linejoin="round"><path d="M12 4L5 10l7 6"/></svg>',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Library',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1,
                          color: Color(0x99FAFAFA), // rgba(250,250,250,.6)
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Title + author
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 32,
                        height: 1.1,
                        color: paper,
                      ),
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        author,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1,
                          color: Color(0x8CFAFAFA), // rgba(250,250,250,.55)
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable content ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info chips ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (statusRaw.isNotEmpty)
                        _Chip(
                          text: _statusLabel(statusRaw),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1,
                            color: ink,
                          ),
                        ),
                      if (chapters.isNotEmpty)
                        _Chip(
                          text: '${chapters.length} ch',
                          textStyle: const TextStyle(
                            fontFamily: fontMono,
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            height: 1,
                            color: slate,
                          ),
                        ),
                      for (final g in genreList.take(2))
                        _Chip(
                          text: g,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: slate,
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Synopsis ────────────────────────────────────────────────
                if (synopsis.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          synopsisExpanded
                              ? synopsis
                              : _truncate(synopsis, 160),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.65,
                            color: ink,
                          ),
                        ),
                        if (synopsis.length > 160) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: onToggleSynopsis,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: const BoxDecoration(
                                color: wool,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(radiusPill),
                                ),
                              ),
                              child: Text(
                                synopsisExpanded ? 'Less' : 'More',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  height: 1,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // ── Action buttons ───────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0x0F0A0A0A)),
                    ),
                  ),
                  child: Row(
                    children: [
                      // "+ Library" / "✓ In Library"
                      Expanded(
                        child: GestureDetector(
                          onTap: () => toggle(!inLibrary),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: inLibrary
                                    ? ink
                                    : const Color(0x260A0A0A),
                                width: 1.5,
                              ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(radiusPill),
                              ),
                              color: inLibrary ? ink : Colors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              inLibrary ? '✓ In Library' : '+ Library',
                              style: TextStyle(
                                fontFamily: fontDisplay,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1,
                                color: inLibrary ? paper : ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // "▶ Read Ch. X"
                      Expanded(
                        child: GestureDetector(
                          onTap: firstChapter == null
                              ? null
                              : () => context.push(
                                    '/reader/$mangaId/${firstChapter.id}',
                                  ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.all(
                                Radius.circular(radiusPill),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              firstChapter != null
                                  ? '▶ Read Ch. ${_fmtNum(firstChapter.number)}'
                                  : '▶ Read',
                              style: const TextStyle(
                                fontFamily: fontDisplay,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1,
                                color: paper,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chapters header ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0x0F0A0A0A)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chapters.isEmpty
                            ? 'CHAPTERS'
                            : 'CHAPTERS · ${chapters.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          letterSpacing: 10 * 0.08,
                          color: slate,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Latest first',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              color: slate,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SvgPicture.string(
                            '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"'
                            ' stroke="#6B6B6B" stroke-width="1.3" stroke-linecap="round">'
                            '<path d="M4 5l2 2 2-2"/></svg>',
                            width: 12,
                            height: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Chapter list ─────────────────────────────────────────────
                if (chaptersAsync.isLoading && chapters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: WoolLoading(size: 60)),
                  )
                else
                  ...chapters.map((ch) => _ChapterRow(
                    chapter: ch,
                    onDownload: ch.isDownloaded
                        ? null
                        : () => ref
                            .read(downloadServiceProvider)
                            .queue(ch.id),
                  )),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(String raw) => switch (raw) {
    'ongoing' => 'Ongoing',
    'completed' => 'Complete',
    'hiatus' => 'Hiatus',
    'cancelled' => 'Cancelled',
    _ => raw[0].toUpperCase() + raw.substring(1),
  };

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max).trimRight()}…';

  String _fmtNum(double n) =>
      n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
}

// ── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.textStyle});

  final String text;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        color: wool,
        borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
      ),
      child: Text(text, style: textStyle),
    );
  }
}

// ── Chapter row ───────────────────────────────────────────────────────────────

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.chapter, this.onDownload});

  final Chapter chapter;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final numStr = chapter.number == chapter.number.truncateToDouble()
        ? chapter.number.toInt().toString()
        : chapter.number.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x0D0A0A0A)),
        ),
      ),
      child: Row(
        children: [
          // Chapter number
          SizedBox(
            width: 26,
            child: Text(
              numStr,
              style: const TextStyle(
                fontFamily: fontMono,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1,
                color: slate,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.2,
                    color: ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (chapter.uploadedAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _relativeTime(chapter.uploadedAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: slate,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action button
          GestureDetector(
            onTap: onDownload,
            child: _ChapterActionButton(chapter: chapter),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'just now';
  }
}

// ── Chapter action button (read ✓ or download ↓) ─────────────────────────────

class _ChapterActionButton extends StatelessWidget {
  const _ChapterActionButton({required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final isRead = chapter.isDownloaded;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isRead ? ink : wool,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: isRead
          ? SvgPicture.string(
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
              ' stroke="#FAFAFA" stroke-width="1.5" stroke-linecap="round"'
              ' stroke-linejoin="round"><path d="M2.5 7l3 3 6-5"/></svg>',
              width: 14,
              height: 14,
            )
          : SvgPicture.string(
              '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"'
              ' stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round"'
              ' stroke-linejoin="round">'
              '<line x1="7" y1="2" x2="7" y2="10"/>'
              '<polyline points="4,7 7,10 10,7"/>'
              '<line x1="2" y1="13" x2="12" y2="13"/>'
              '</svg>',
              width: 14,
              height: 14,
            ),
    );
  }
}

// ── Cover thumbnail (local file or colored placeholder) ───────────────────────

// ignore: unused_element
class _CoverThumbnail extends StatelessWidget {
  const _CoverThumbnail({
    required this.coverPath,
    required this.color,
    required this.width,
    required this.height,
  });

  final String coverPath;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final file = coverPath.isNotEmpty ? File(coverPath) : null;
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: color),
      );
    }
    return ColoredBox(color: color);
  }
}
