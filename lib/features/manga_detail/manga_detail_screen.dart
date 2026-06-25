import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/sheep_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/download/download_provider.dart';
import '../../data/settings/settings_repository.dart';
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
    final c = SheepColors.of(context);
    final mangaAsync = ref.watch(mangaWatchProvider(widget.mangaId));
    final chaptersAsync = ref.watch(chaptersWatchProvider(widget.mangaId));
    // Trigger fetch from source — loads chapters and cover on first open
    final fetchAsync = ref.watch(fetchMangaDetailProvider(widget.mangaId));

    return Scaffold(
      backgroundColor: c.paper,
      body: mangaAsync.when(
        loading: () => const Center(child: WoolLoading()),
        error: (_, _) => const Center(child: Text('Erro ao carregar')),
        data: (manga) => _DetailBody(
          mangaId: widget.mangaId,
          manga: manga,
          chaptersAsync: chaptersAsync,
          fetchAsync: fetchAsync,
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
    required this.fetchAsync,
    required this.synopsisExpanded,
    required this.onToggleSynopsis,
  });

  final String mangaId;
  final Manga? manga;
  final AsyncValue<List<Chapter>> chaptersAsync;
  final AsyncValue<void> fetchAsync;
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
    final c = SheepColors.of(context);
    final heroColor = _heroColor(mangaId);
    final title = manga?.title ?? '';
    final author = manga?.author ?? '';
    final synopsis = manga?.synopsis ?? '';
    final statusRaw = manga?.status ?? '';
    final genreList = _genres(manga?.genres);
    final inLibrary = manga?.inLibrary ?? false;
    final toggle = ref.read(toggleLibraryProvider(mangaId));
    final coverPath = manga?.coverPath ?? '';
    final chapterSort = ref.watch(settingsProvider).chapterSort;

    final chapters = chaptersAsync.valueOrNull ?? const [];
    // Always sort ascending by number to find first/continue chapter correctly.
    final sortedAsc = [...chapters]..sort((a, b) => a.number.compareTo(b.number));
    final firstChapter = sortedAsc.isNotEmpty ? sortedAsc.first : null;

    // Determine the chapter to start/continue reading.
    final readMap =
        ref.watch(chapterReadMapProvider(mangaId)).valueOrNull ?? const {};
    final lastReadNum = chapters.fold<double>(
      -1,
      (mx, ch) => (readMap[ch.id] == true && ch.number > mx) ? ch.number : mx,
    );
    final hasReadProgress = lastReadNum >= 0;
    final continueChapter = hasReadProgress
        ? sortedAsc.firstWhere(
            (ch) => ch.number > lastReadNum && (readMap[ch.id] != true),
            orElse: () => firstChapter!,
          )
        : firstChapter;

    final topPad = MediaQuery.of(context).padding.top;
    final isLoading = fetchAsync.isLoading && chapters.isEmpty;
    final hasError = fetchAsync.hasError && chapters.isEmpty;

    return Column(
      children: [
        // ── Dark hero section ────────────────────────────────────────────────
        Stack(
          children: [
            // Cover image or colored background
            _HeroCover(
              coverPath: coverPath,
              heroColor: heroColor,
            ),
            // Gradient overlay for text readability
            if (coverPath.isNotEmpty)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99000000),
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: topPad),
                // Back nav row
                SizedBox(
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
                            child: SvgPicture.string(
                              '<svg width="20" height="20" viewBox="0 0 20 20" fill="none"'
                              ' stroke="#FAFAFA" stroke-width="1.5" stroke-linecap="round"'
                              ' stroke-linejoin="round"><path d="M12 4L5 10l7 6"/></svg>',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                        const Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1,
                            color: Color(0x99FAFAFA),
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
                          color: Color(0xFFFAFAFA),
                        ),
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          author,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1,
                            color: Color(0x8CFAFAFA),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
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
                          textStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1,
                            color: c.ink,
                          ),
                          bgColor: c.wool,
                        ),
                      if (chapters.isNotEmpty)
                        _Chip(
                          text: '${chapters.length} ch',
                          textStyle: TextStyle(
                            fontFamily: fontMono,
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            height: 1,
                            color: c.slate,
                          ),
                          bgColor: c.wool,
                        ),
                      for (final g in genreList.take(2))
                        _Chip(
                          text: g,
                          textStyle: TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: c.slate,
                          ),
                          bgColor: c.wool,
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
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.65,
                            color: c.ink,
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
                              decoration: BoxDecoration(
                                color: c.wool,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(radiusPill),
                                ),
                              ),
                              child: Text(
                                synopsisExpanded ? 'Less' : 'More',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  height: 1,
                                  color: c.ink,
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
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: c.border),
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
                                color: inLibrary ? c.ink : c.border,
                                width: 1.5,
                              ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(radiusPill),
                              ),
                              color: inLibrary ? c.ink : Colors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              inLibrary ? '✓ In Library' : '+ Library',
                              style: TextStyle(
                                fontFamily: fontDisplay,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1,
                                color: inLibrary ? c.paper : c.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // "▶ Read Ch. X" / "▶ Continue Ch. X"
                      Expanded(
                        child: GestureDetector(
                          onTap: continueChapter == null
                              ? null
                              : () => context.push(
                                    '/reader/$mangaId/${continueChapter.id}',
                                  ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: c.ink,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(radiusPill),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              continueChapter != null
                                  ? hasReadProgress
                                      ? '▶ Continue Ch. ${_fmtNum(continueChapter.number)}'
                                      : '▶ Read Ch. ${_fmtNum(continueChapter.number)}'
                                  : '▶ Read',
                              style: TextStyle(
                                fontFamily: fontDisplay,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1,
                                color: c.paper,
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
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: c.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chapters.isEmpty
                            ? 'CHAPTERS'
                            : 'CHAPTERS · ${chapters.length}',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          letterSpacing: 10 * 0.08,
                          color: c.slate,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final n = ref.read(settingsProvider.notifier);
                          n.setChapterSort(
                              chapterSort == 'desc' ? 'asc' : 'desc');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
                          child: Row(
                            children: [
                              Text(
                                chapterSort == 'asc'
                                    ? 'Oldest first'
                                    : 'Latest first',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1,
                                  color: c.slate,
                                ),
                              ),
                              const SizedBox(width: 4),
                              SvgPicture.string(
                                chapterSort == 'asc'
                                    ? '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"'
                                        ' stroke="#6B6B6B" stroke-width="1.3" stroke-linecap="round">'
                                        '<path d="M4 7l2-2 2 2"/></svg>'
                                    : '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"'
                                        ' stroke="#6B6B6B" stroke-width="1.3" stroke-linecap="round">'
                                        '<path d="M4 5l2 2 2-2"/></svg>',
                                width: 12,
                                height: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chapter list or loading/error ─────────────────────────────
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: WoolLoading(size: 60)),
                  )
                else if (hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Erro ao buscar capítulos.\nVerifique sua conexão.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: c.slate,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fetchAsync.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.4,
                              color: c.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...chapters.map((ch) => _ChapterRow(
                        chapter: ch,
                        isRead: readMap[ch.id] ?? false,
                        onTap: () => context.push('/reader/$mangaId/${ch.id}'),
                        onDownload: ch.isDownloaded
                            ? null
                            : () => ref
                                .read(downloadServiceProvider)
                                .queue(ch.id),
                        onMarkRead: (isRead) => ref
                            .read(databaseProvider)
                            .markChapterRead(ch.id, isRead: isRead),
                        onMarkAllPreviousRead: () {
                          final db = ref.read(databaseProvider);
                          for (final c in chapters) {
                            if (c.number <= ch.number) {
                              db.markChapterRead(c.id, isRead: true);
                            }
                          }
                        },
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

// ── Hero cover ────────────────────────────────────────────────────────────────

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.coverPath, required this.heroColor});

  final String coverPath;
  final Color heroColor;

  @override
  Widget build(BuildContext context) {
    if (coverPath.isNotEmpty) {
      final file = File(coverPath);
      if (file.existsSync()) {
        return SizedBox(
          width: double.infinity,
          height: 220,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: heroColor,
              child: const SizedBox(height: 220),
            ),
          ),
        );
      }
    }
    return ColoredBox(
      color: heroColor,
      child: const SizedBox(width: double.infinity, height: 220),
    );
  }
}

// ── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.textStyle,
    required this.bgColor,
  });

  final String text;
  final TextStyle textStyle;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.all(Radius.circular(radiusPill)),
      ),
      child: Text(text, style: textStyle),
    );
  }
}

// ── Chapter row ───────────────────────────────────────────────────────────────

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.isRead,
    required this.onTap,
    this.onDownload,
    this.onMarkRead,
    this.onMarkAllPreviousRead,
  });

  final Chapter chapter;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final void Function(bool)? onMarkRead;
  final VoidCallback? onMarkAllPreviousRead;

  void _showActions(BuildContext context) {
    final c = SheepColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.wool,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                isRead
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
                color: c.ink,
              ),
              title: Text(
                isRead ? 'Mark as unread' : 'Mark as read',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: c.ink,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onMarkRead?.call(!isRead);
              },
            ),
            if (onMarkAllPreviousRead != null)
              ListTile(
                leading: Icon(Icons.done_all, color: c.ink),
                title: Text(
                  'Mark Ch. 1 – ${_numStr(chapter.number)} as read',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: c.ink,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onMarkAllPreviousRead!();
                },
              ),
            SizedBox(height: bottomPad + 8),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SheepColors.of(context);
    final numStr = chapter.number == chapter.number.truncateToDouble()
        ? chapter.number.toInt().toString()
        : chapter.number.toString();
    final textColor = isRead ? c.slate : c.ink;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            // Read indicator dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRead
                    ? Colors.transparent
                    : c.ink,
                border: Border.all(
                  color: isRead ? c.slate.withValues(alpha: 0.4) : c.ink,
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Chapter number
            SizedBox(
              width: 26,
              child: Text(
                numStr,
                style: TextStyle(
                  fontFamily: fontMono,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1,
                  color: c.slate,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.2,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chapter.uploadedAt != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _relativeTime(chapter.uploadedAt!),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: c.slate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Download / checkmark button — área de toque 44×44
            GestureDetector(
              onTap: onDownload,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _ChapterActionButton(chapter: chapter, c: c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _numStr(double n) =>
      n == n.truncateToDouble() ? n.toInt().toString() : n.toString();

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

// ── Chapter action button ─────────────────────────────────────────────────────

class _ChapterActionButton extends StatelessWidget {
  const _ChapterActionButton({required this.chapter, required this.c});

  final Chapter chapter;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: chapter.isDownloaded ? c.ink : c.wool,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: chapter.isDownloaded
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
