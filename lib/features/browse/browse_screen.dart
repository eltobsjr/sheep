import 'dart:async' show unawaited;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:palette_generator/palette_generator.dart';

import '../../core/theme/sheep_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/database_provider.dart';
import '../../data/sources/source_registry.dart';
import '../../domain/models/manga.dart';
import 'browse_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SheepColors.of(context);
    final selectedId = ref.watch(selectedSourceIdProvider);
    final orderedIds = ref.watch(sourceOrderProvider);
    final selectedLang = ref.watch(selectedLanguageProvider);
    final popularAsync = ref.watch(popularProvider);
    final latestAsync = ref.watch(latestProvider);

    // Filter source IDs by selected language
    final filteredIds = selectedLang == 'all'
        ? orderedIds
        : orderedIds.where((id) {
            final source = sourceById(id);
            return source?.language == selectedLang;
          }).toList();

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Browse',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.1,
                        color: c.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/browse/search'),
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
                          colorFilter: ColorFilter.mode(c.ink, BlendMode.srcIn),
                        ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Language dropdown ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _LanguageDropdown(
                  selected: selectedLang,
                  onChanged: (lang) {
                    ref.read(selectedLanguageProvider.notifier).state = lang;
                    final first = lang == 'all'
                        ? orderedIds.firstOrNull
                        : orderedIds.firstWhere(
                            (id) => sourceById(id)?.language == lang,
                            orElse: () => orderedIds.firstOrNull ?? '',
                          );
                    if (first != null && first.isNotEmpty) {
                      ref.read(selectedSourceIdProvider.notifier).state = first;
                    }
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Source chips (long-press to reorder when All is selected) ───────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                  onReorder: selectedLang == 'all'
                      ? (oldIndex, newIndex) => ref
                          .read(sourceOrderProvider.notifier)
                          .reorder(oldIndex, newIndex)
                      : (_, __) {},
                  itemCount: filteredIds.length,
                  itemBuilder: (context, i) {
                    final sourceId = filteredIds[i];
                    final source = sourceById(sourceId);
                    if (source == null) {
                      return SizedBox.shrink(key: ValueKey(sourceId));
                    }
                    final active = sourceId == selectedId;
                    final canDrag = selectedLang == 'all';
                    final chip = GestureDetector(
                      onTap: () => ref
                          .read(selectedSourceIdProvider.notifier)
                          .state = sourceId,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: active ? c.ink : c.wool,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(radiusPill),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (active) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: c.paper,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              source.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1,
                                color: active ? c.paper : c.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    return Padding(
                      key: ValueKey(sourceId),
                      padding: const EdgeInsets.only(right: 8),
                      child: canDrag
                          ? ReorderableDelayedDragStartListener(
                              index: i,
                              child: chip,
                            )
                          : chip,
                    );
                  },
                ),
              ),
            ),

            // ── "Visit source" link ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: GestureDetector(
                  onTap: () {
                    final source = sourceById(selectedId);
                    if (source == null) return;
                    context.push('/source-browser', extra: {
                      'url': source.baseUrl,
                      'name': source.name,
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_browser_rounded,
                        size: 12,
                        color: c.slate,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Visitar ${sourceById(selectedId)?.name ?? ''} no browser integrado',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          color: c.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Featured card ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: popularAsync.when(
                loading: () => const SizedBox(
                  height: 158,
                  child: Center(child: WoolLoading(size: 60)),
                ),
                error: (_, _) => const SizedBox(height: 8),
                data: (items) {
                  if (items.isEmpty) return const SizedBox(height: 8);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _FeaturedCard(
                      manga: items.first,
                      sourceName: sourceById(items.first.sourceId)?.name ??
                          items.first.sourceId,
                      onTap: () =>
                          unawaited(_onMangaTap(context, ref, items.first)),
                    ),
                  );
                },
              ),
            ),

            // ── Popular section ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'POPULAR THIS WEEK',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    letterSpacing: 10 * 0.08,
                    color: c.slate,
                  ),
                ),
              ),
            ),

            popularAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: WoolLoading(size: 60)),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sourceError(e),
                        style: TextStyle(fontSize: 13, color: c.slate),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => ref.invalidate(popularProvider),
                            child: Text(
                              'Tentar novamente',
                              style: TextStyle(
                                color: c.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              final source = sourceById(selectedId);
                              if (source == null) return;
                              context.push('/source-browser', extra: {
                                'url': source.baseUrl,
                                'name': source.name,
                              });
                            },
                            child: Text(
                              'Abrir site da fonte',
                              style: TextStyle(
                                color: c.slate,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _MangaListItem(
                    manga: items[i],
                    sourceName: sourceById(items[i].sourceId)?.name ??
                        items[i].sourceId,
                    showChip: true,
                    onTap: () => unawaited(_onMangaTap(context, ref, items[i])),
                    c: c,
                  ),
                  childCount: items.length,
                ),
              ),
            ),

            // ── Recently updated section ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'RECENTLY UPDATED',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    letterSpacing: 10 * 0.08,
                    color: c.slate,
                  ),
                ),
              ),
            ),

            latestAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(height: 8),
              ),
              error: (_, _) => const SliverToBoxAdapter(child: SizedBox()),
              data: (items) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _MangaListItem(
                    manga: items[i],
                    sourceName: sourceById(items[i].sourceId)?.name ??
                        items[i].sourceId,
                    showChip: false,
                    onTap: () =>
                        unawaited(_onMangaTap(context, ref, items[i])),
                    c: c,
                  ),
                  childCount: items.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

String _sourceError(Object e) {
  final msg = e.toString();
  if (msg.contains('404')) return 'Fonte indisponível (página não encontrada).';
  if (msg.contains('403')) return 'Acesso negado pela fonte. Tente em outro momento.';
  if (msg.contains('429')) return 'Limite de requisições atingido. Aguarde um momento.';
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Sem conexão com a internet.';
  }
  if (msg.contains('timeout') || msg.contains('TimeoutException')) {
    return 'Tempo limite excedido. Verifique sua conexão.';
  }
  return 'Erro ao carregar a fonte. Tente novamente.';
}

Future<void> _onMangaTap(
  BuildContext context,
  WidgetRef ref,
  MangaSummary manga,
) async {
  await ref.read(databaseProvider).saveSummary(
        id: manga.id,
        sourceId: manga.sourceId,
        title: manga.title,
        url: manga.url,
      );
  if (context.mounted) unawaited(context.push('/manga/${manga.id}'));
}

// ── Featured card ─────────────────────────────────────────────────────────────

class _FeaturedCard extends StatefulWidget {
  const _FeaturedCard({
    required this.manga,
    required this.sourceName,
    required this.onTap,
  });

  final MangaSummary manga;
  final String sourceName;
  final VoidCallback onTap;

  @override
  State<_FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<_FeaturedCard> {
  static const _fallbackColors = [
    Color(0xFF1A1A2E), Color(0xFF5C3B1E), Color(0xFFCC2B2B), Color(0xFF1B2A4A),
    Color(0xFF8B1A1A), Color(0xFF2D6A4F), Color(0xFF6B3FA0), Color(0xFF2A3F5A),
  ];

  Color? _dominantColor;

  Color get _fallback =>
      _fallbackColors[widget.manga.id.hashCode.abs() % _fallbackColors.length];

  @override
  void initState() {
    super.initState();
    if (widget.manga.coverUrl.isNotEmpty) _extractColor();
  }

  @override
  void didUpdateWidget(_FeaturedCard old) {
    super.didUpdateWidget(old);
    if (old.manga.coverUrl != widget.manga.coverUrl) {
      setState(() => _dominantColor = null);
      if (widget.manga.coverUrl.isNotEmpty) _extractColor();
    }
  }

  Future<void> _extractColor() async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(widget.manga.coverUrl),
        size: const Size(80, 120),
        maximumColorCount: 8,
      );
      if (!mounted) return;
      setState(() =>
          _dominantColor = generator.darkMutedColor?.color ??
              generator.dominantColor?.color);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bg = _dominantColor ?? _fallback;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusCard),
        child: SizedBox(
          height: 158,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dominant color background (animates in once extracted)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                color: bg,
              ),
              // Cover image
              if (widget.manga.coverUrl.isNotEmpty)
                _RemoteCover(
                  url: widget.manga.coverUrl,
                  fallbackColor: bg,
                  width: double.infinity,
                  height: 158,
                ),
              // Dark gradient overlay for text readability
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55000000), Color(0xDD000000)],
                  ),
                ),
              ),
              // Watermark title (always shown at 8% opacity)
              Positioned(
                right: -6,
                bottom: -18,
                child: Text(
                  widget.manga.title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 72,
                    height: 1,
                    letterSpacing: 72 * -0.02,
                    color: Color(0x14FAFAFA),
                  ),
                ),
              ),
              // Content overlay
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: const BoxDecoration(
                            color: Color(0x38000000),
                            borderRadius:
                                BorderRadius.all(Radius.circular(radiusPill)),
                          ),
                          child: const Text(
                            'Ch. ∞',
                            style: TextStyle(
                              fontFamily: fontMono,
                              fontSize: 11,
                              height: 1,
                              color: Color(0xFFFAFAFA),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: const BoxDecoration(
                            color: Color(0x38000000),
                            borderRadius:
                                BorderRadius.all(Radius.circular(radiusPill)),
                          ),
                          child: Text(
                            widget.sourceName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              height: 1,
                              color: Color(0xFFFAFAFA),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.manga.title,
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            height: 1.1,
                            color: Color(0xFFFAFAFA),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.manga.author.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${widget.manga.author} · Ongoing',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1,
                              color: Color(0xA6FAFAFA),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Manga list item ───────────────────────────────────────────────────────────

class _MangaListItem extends StatelessWidget {
  const _MangaListItem({
    required this.manga,
    required this.sourceName,
    required this.showChip,
    required this.onTap,
    required this.c,
  });

  final MangaSummary manga;
  final String sourceName;
  final bool showChip;
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

  Color get _color => _colors[manga.id.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _RemoteCover(
                url: manga.coverUrl,
                fallbackColor: _color,
                width: 46,
                height: 62,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.2,
                      color: c.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    manga.author.isNotEmpty ? manga.author : sourceName,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: c.slate,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showChip) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.wool,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(radiusPill)),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontFamily: fontMono,
                    fontSize: 10,
                    height: 1,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Remote cover image with fallback ─────────────────────────────────────────

class _RemoteCover extends StatelessWidget {
  const _RemoteCover({
    required this.url,
    required this.fallbackColor,
    required this.width,
    required this.height,
  });

  final String url;
  final Color fallbackColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: ColoredBox(color: fallbackColor),
      );
    }
    return ExtendedImage.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState != LoadState.completed) {
          return SizedBox(
            width: width,
            height: height,
            child: ColoredBox(color: fallbackColor),
          );
        }
        return null;
      },
    );
  }
}

// ── Language dropdown ─────────────────────────────────────────────────────────

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final void Function(String) onChanged;

  static const _options = [
    ('all', 'All'),
    ('pt-br', 'PT-BR'),
    ('en', 'EN'),
  ];

  String get _label =>
      _options.firstWhere((o) => o.$1 == selected, orElse: () => ('all', 'All')).$2;

  @override
  Widget build(BuildContext context) {
    final c = SheepColors.of(context);
    return GestureDetector(
      onTap: () async {
        final RenderBox box = context.findRenderObject()! as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final chosen = await showMenu<String>(
          context: context,
          color: c.paper,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            side: BorderSide(color: c.wool, width: 1),
          ),
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + box.size.height + 4,
            offset.dx + box.size.width,
            0,
          ),
          items: [
            for (final (lang, label) in _options)
              PopupMenuItem<String>(
                value: lang,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: lang == selected ? c.ink : c.slate,
                        ),
                      ),
                    ),
                    if (lang == selected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
        if (chosen != null) onChanged(chosen);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.wool,
          borderRadius: const BorderRadius.all(Radius.circular(radiusPill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1,
                color: c.slate,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: c.slate),
          ],
        ),
      ),
    );
  }
}
