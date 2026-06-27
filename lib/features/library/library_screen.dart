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
import '../../data/sources/source_registry.dart';
import 'library_providers.dart';


// ── Entry point ──────────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SheepColors.of(context);
    final mangasAsync = ref.watch(libraryMangasProvider);
    final recentlyReadAsync = ref.watch(recentlyReadProvider);
    final progressAsync = ref.watch(libraryProgressProvider);

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: mangasAsync.when(
          loading: () => const Center(child: WoolLoading()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Erro ao carregar a biblioteca.',
                    style: TextStyle(
                        color: c.ink, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verifique sua conexão e tente novamente.',
                    style: TextStyle(color: c.slate, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => ref.invalidate(libraryMangasProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.ink,
                        borderRadius:
                            BorderRadius.circular(radiusPill),
                      ),
                      child: Text(
                        'Tentar novamente',
                        style: TextStyle(
                            color: c.paper,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (mangas) {
            if (mangas.isEmpty) {
              return _EmptyState(
                  onBrowse: () => context.go('/browse'), c: c);
            }
            return _FilledState(
              mangas: mangas,
              totalCount: mangas.length,
              recentlyRead:
                  _searching ? const [] : (recentlyReadAsync.valueOrNull ?? const []),
              progress: progressAsync.valueOrNull ?? const {},
              searching: _searching,
              searchCtrl: _searchCtrl,
              onSearchToggle: _toggleSearch,
              onMangaTap: (id) => context.push('/manga/$id'),
              onReadTap: (mangaId, chapterId) =>
                  context.push('/reader/$mangaId/$chapterId'),
              onReorder: (ids) =>
                  ref.read(databaseProvider).updateSortOrders(ids),
              c: c,
            );
          },
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBrowse, required this.c});

  final VoidCallback onBrowse;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            'Library',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              height: 1.1,
              color: c.ink,
            ),
          ),
        ),
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
                  colorFilter: ColorFilter.mode(c.ink, BlendMode.srcIn),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your library is empty',
                  textAlign: TextAlign.center,
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
                  'Browse sources to find manga and add your first series',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: c.slate,
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
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(radiusPill)),
                    ),
                    child: Text(
                      'Browse manga',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1,
                        color: c.paper,
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

// ── Filled state ──────────────────────────────────────────────────────────────

class _FilledState extends StatefulWidget {
  const _FilledState({
    required this.mangas,
    required this.totalCount,
    required this.recentlyRead,
    required this.progress,
    required this.searching,
    required this.searchCtrl,
    required this.onSearchToggle,
    required this.onMangaTap,
    required this.onReadTap,
    required this.onReorder,
    required this.c,
  });

  final List<Manga> mangas;
  final int totalCount;
  final List<LastReadEntry> recentlyRead;
  final Map<String, MangaProgressEntry> progress;
  final bool searching;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchToggle;
  final void Function(String mangaId) onMangaTap;
  final void Function(String mangaId, String chapterId) onReadTap;
  final void Function(List<String> ids) onReorder;
  final SheepColors c;

  @override
  State<_FilledState> createState() => _FilledStateState();
}

class _FilledStateState extends State<_FilledState> {
  bool _reordering = false;
  String? _filterSourceId;

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearch);
  }

  void _onSearch() => setState(() {});

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearch);
    super.dispose();
  }

  void _toggleReorder() => setState(() => _reordering = !_reordering);

  void _showFilterSheet(BuildContext context, List<Manga> allMangas) {
    final c = widget.c;
    final sourceIds = allMangas.map((m) => m.sourceId).toSet().toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.wool,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Filtrar por fonte',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Todas',
                    selected: _filterSourceId == null,
                    c: c,
                    onTap: () {
                      setState(() => _filterSourceId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final sid in sourceIds)
                    _FilterChip(
                      label: sourceById(sid)?.name ?? sid,
                      selected: _filterSourceId == sid,
                      c: c,
                      onTap: () {
                        setState(() => _filterSourceId = sid);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final searching = widget.searching;
    final searchCtrl = widget.searchCtrl;
    final query = searchCtrl.text.trim().toLowerCase();
    final mangas = (() {
      var list = widget.mangas;
      if (_filterSourceId != null) {
        list = list.where((m) => m.sourceId == _filterSourceId).toList();
      }
      if (query.isNotEmpty) {
        list = list.where((m) => m.title.toLowerCase().contains(query)).toList();
      }
      return list;
    })();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              children: [
                if (searching) ...[
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        color: c.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search library…',
                        hintStyle:
                            TextStyle(fontSize: 18, color: c.slate),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onSearchToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.wool,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.string(
                          '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"'
                          ' stroke="#0A0A0A" stroke-width="1.5" stroke-linecap="round">'
                          '<line x1="2" y1="2" x2="10" y2="10"/>'
                          '<line x1="10" y1="2" x2="2" y2="10"/>'
                          '</svg>',
                          width: 12,
                          height: 12,
                          colorFilter:
                              ColorFilter.mode(c.ink, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Text(
                      'Library',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.1,
                        color: c.ink,
                      ),
                    ),
                  ),
                  // History button
                  GestureDetector(
                    onTap: () => context.push('/history'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.wool,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.history, size: 18, color: c.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Filter toggle
                  GestureDetector(
                    onTap: () => _showFilterSheet(context, widget.mangas),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _filterSourceId != null ? c.ink : c.wool,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: _filterSourceId != null ? c.paper : c.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Reorder toggle
                  GestureDetector(
                    onTap: _toggleReorder,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _reordering ? c.ink : c.wool,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.sort,
                          size: 18,
                          color: _reordering ? c.paper : c.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onSearchToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.wool,
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
                          colorFilter:
                              ColorFilter.mode(c.ink, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Continue Reading carousel ────────────────────────────────────
          if (widget.recentlyRead.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'CONTINUE READING',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  letterSpacing: 10 * 0.08,
                  color: c.slate,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 116,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                itemCount: widget.recentlyRead.length,
                itemBuilder: (context, i) {
                  final entry = widget.recentlyRead[i];
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < widget.recentlyRead.length - 1 ? 12 : 0),
                    child: SizedBox(
                      width: widget.recentlyRead.length == 1
                          ? MediaQuery.of(context).size.width - 40
                          : MediaQuery.of(context).size.width * 0.82,
                      child: _ContinueReadingCard(
                        entry: entry,
                        onRead: () => widget.onReadTap(entry.mangaId, entry.chapterId),
                        c: c,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── All section header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  searching && mangas.length < widget.totalCount
                      ? '${mangas.length} of ${widget.totalCount}'
                      : _filterSourceId != null
                          ? '${sourceById(_filterSourceId!)?.name ?? _filterSourceId} · ${mangas.length}'
                          : 'ALL · ${widget.totalCount}',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    letterSpacing: 10 * 0.08,
                    color: c.slate,
                  ),
                ),
              ],
            ),
          ),

          // ── Grid or reorder list ─────────────────────────────────────────
          if (_reordering)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                height: mangas.length * 72.0,
                child: ReorderableListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mangas.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = [...mangas];
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    widget.onReorder(reordered.map((m) => m.id).toList());
                  },
                  itemBuilder: (context, i) => _ReorderRow(
                    key: ValueKey(mangas[i].id),
                    manga: mangas[i],
                    c: c,
                    onTap: () => widget.onMangaTap(mangas[i].id),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 2;
                  const crossAxisSpacing = 12.0;
                  const belowCoverHeight = 42.0;
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
                      onTap: () => widget.onMangaTap(mangas[i].id),
                      child: _MangaCard(
                        manga: mangas[i],
                        progress: widget.progress[mangas[i].id],
                        c: c,
                      ),
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
  const _ContinueReadingCard({
    required this.entry,
    required this.onRead,
    required this.c,
  });

  final LastReadEntry entry;
  final VoidCallback onRead;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.wool,
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
              coverPath: entry.coverPath,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.2,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.chapterTitle} · Page ${entry.lastPage}'
                  '${entry.pageCount != null ? ' of ${entry.pageCount}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: c.slate,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: entry.progress,
                    backgroundColor: Color.lerp(c.ink, Colors.transparent, 0.88),
                    valueColor: AlwaysStoppedAnimation<Color>(c.ink),
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${entry.progressPercent}%',
                  style: TextStyle(
                    fontFamily: fontMono,
                    fontSize: 10,
                    height: 1,
                    color: c.slate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // "Read" button
          SizedBox(
            height: 70,
            child: Center(
              child: GestureDetector(
                onTap: onRead,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(radiusPill)),
                  ),
                  child: Text(
                    'Read',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1,
                      color: c.paper,
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

// ── Reorder list row ──────────────────────────────────────────────────────────

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({
    required this.manga,
    required this.c,
    required this.onTap,
    super.key,
  });

  final Manga manga;
  final SheepColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: c.wool,
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _CoverThumbnail(
                coverPath: manga.coverPath,
                mangaId: manga.id,
                title: manga.title,
                width: 36,
                height: 48,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                manga.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: c.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.drag_handle, color: c.slate, size: 20),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.c,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final SheepColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.wool,
          borderRadius: BorderRadius.circular(radiusPill),
          border: Border.all(color: selected ? c.ink : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: fontMono,
            fontSize: 13,
            height: 1,
            color: selected ? c.paper : c.ink,
          ),
        ),
      ),
    );
  }
}

// ── Grid card ─────────────────────────────────────────────────────────────────

class _MangaCard extends StatelessWidget {
  const _MangaCard({
    required this.manga,
    required this.c,
    this.progress,
  });

  final Manga manga;
  final SheepColors c;
  final MangaProgressEntry? progress;

  @override
  Widget build(BuildContext context) {
    final sourceName = sourceById(manga.sourceId)?.name ?? manga.sourceId;
    final hasProgress =
        progress != null && progress!.totalCount > 0 && progress!.readCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.2,
            color: c.ink,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        if (hasProgress) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: progress!.ratio,
              backgroundColor: c.wool,
              valueColor: AlwaysStoppedAnimation<Color>(c.ink),
              minHeight: 2,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Text(
          hasProgress
              ? '${progress!.readCount}/${progress!.totalCount} ch · $sourceName'
              : sourceName,
          style: TextStyle(
            fontSize: 10,
            height: 1,
            color: c.slate,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Cover thumbnail ───────────────────────────────────────────────────────────

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
    if (coverPath.isNotEmpty) {
      return Image.file(
        File(coverPath),
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
          color: Color(0x66FAFAFA),
          letterSpacing: 8 * 0.04,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

