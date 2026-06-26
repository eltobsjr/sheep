import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/database_provider.dart';
import '../../data/sources/source_registry.dart';
import '../../domain/models/manga.dart';
import 'browse_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _clear() {
    _ctrl.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final selectedSourceId = ref.watch(searchSourceIdProvider);
    final query = ref.watch(searchQueryProvider);
    final isAllSources = selectedSourceId == null;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search bar row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: const BoxDecoration(
                        color: wool,
                        borderRadius:
                            BorderRadius.all(Radius.circular(radiusPill)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          SvgPicture.string(
                            '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"'
                            ' stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round">'
                            '<circle cx="7" cy="7" r="5"/>'
                            '<path d="M11 11l3 3"/>'
                            '</svg>',
                            width: 16,
                            height: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              onChanged: _onChanged,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1,
                                color: ink,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search manga…',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  height: 1,
                                  color: slate,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (query.isNotEmpty) ...[
                            GestureDetector(
                              onTap: _clear,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0x260A0A0A),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: SvgPicture.string(
                                  '<svg width="10" height="10" viewBox="0 0 10 10" fill="none"'
                                  ' stroke="#0A0A0A" stroke-width="1.5" stroke-linecap="round">'
                                  '<path d="M1.5 1.5l7 7M8.5 1.5l-7 7"/>'
                                  '</svg>',
                                  width: 10,
                                  height: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1,
                        color: slate,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Source filter chips ─────────────────────────────────────────
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                children: [
                  GestureDetector(
                    onTap: () =>
                        ref.read(searchSourceIdProvider.notifier).state = null,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isAllSources ? ink : wool,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(radiusPill),
                        ),
                      ),
                      child: Text(
                        'All Sources',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          height: 1,
                          color: isAllSources ? paper : slate,
                        ),
                      ),
                    ),
                  ),
                  ...allSources.map((s) => GestureDetector(
                        onTap: () => ref
                            .read(searchSourceIdProvider.notifier)
                            .state = s.id,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selectedSourceId == s.id ? ink : wool,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(radiusPill),
                            ),
                          ),
                          child: Text(
                            s.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              height: 1,
                              color:
                                  selectedSourceId == s.id ? paper : slate,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),

            // ── Results ─────────────────────────────────────────────────────
            Expanded(
              child: query.isEmpty
                  ? const _EmptySearch()
                  : isAllSources
                      ? _AllSourcesResults(
                          onTap: (manga) => unawaited(
                              _onResultTap(context, ref, manga)),
                        )
                      : _SingleSourceResults(
                          onTap: (manga) => unawaited(
                              _onResultTap(context, ref, manga)),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onResultTap(
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
}

// ── All-sources results (grouped by source) ───────────────────────────────────

class _AllSourcesResults extends ConsumerWidget {
  const _AllSourcesResults({required this.onTap});

  final void Function(MangaSummary) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allSourcesResultsProvider);
    return async.when(
      loading: () => const Center(child: WoolLoading(size: 80)),
      error: (e, _) => Center(
        child: Text(
          e.toString().split('\n').first,
          style: const TextStyle(fontSize: 13, color: slate),
        ),
      ),
      data: (buckets) {
        final hasAny = buckets.any((b) => b.items.isNotEmpty);
        if (!hasAny && buckets.every((b) => !b.hasError)) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text(
              'No results found',
              style: TextStyle(fontSize: 14, height: 1.5, color: slate),
            ),
          );
        }
        return ListView.builder(
          itemCount: buckets.length,
          itemBuilder: (context, i) {
            final bucket = buckets[i];
            if (bucket.items.isEmpty && !bucket.hasError) {
              return const SizedBox.shrink();
            }
            return _SourceBucket(bucket: bucket, onTap: onTap);
          },
        );
      },
    );
  }
}

class _SourceBucket extends StatelessWidget {
  const _SourceBucket({required this.bucket, required this.onTap});

  final SourceSearchResult bucket;
  final void Function(MangaSummary) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            children: [
              Text(
                bucket.source.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  letterSpacing: 10 * 0.08,
                  fontWeight: FontWeight.w600,
                  color: slate,
                ),
              ),
              if (bucket.hasError) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x14CC2B2B),
                    borderRadius:
                        const BorderRadius.all(Radius.circular(radiusPill)),
                  ),
                  child: Text(
                    _errorLabel(bucket.error!),
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1,
                      color: Color(0xFFCC2B2B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Results or error explanation
        if (bucket.hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _errorDetail(bucket.error!),
              style: const TextStyle(fontSize: 12, height: 1.4, color: slate),
            ),
          )
        else
          ...bucket.items.map(
            (m) => _ResultRow(manga: m, onTap: () => onTap(m)),
          ),
      ],
    );
  }

  static String _errorLabel(Object e) {
    final msg = e.toString();
    if (msg.contains('403') || msg.contains('503')) return 'bloqueado';
    if (msg.contains('404')) return 'indisponível';
    if (msg.contains('timeout') || msg.contains('TimeoutException')) {
      return 'timeout';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'sem conexão';
    }
    return 'erro';
  }

  static String _errorDetail(Object e) {
    final msg = e.toString();
    if (msg.contains('403') || msg.contains('503')) {
      return 'Esta fonte requer verificação de segurança (Cloudflare). Acesse-a individualmente para resolver o desafio.';
    }
    if (msg.contains('404')) return 'Fonte não encontrada ou indisponível.';
    if (msg.contains('timeout') || msg.contains('TimeoutException')) {
      return 'Tempo limite excedido ao conectar à fonte.';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Sem conexão com a internet.';
    }
    return msg.split('\n').first;
  }
}

// ── Single-source results ─────────────────────────────────────────────────────

class _SingleSourceResults extends ConsumerWidget {
  const _SingleSourceResults({required this.onTap});

  final void Function(MangaSummary) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchResultsProvider);
    return async.when(
      loading: () => const Center(child: WoolLoading(size: 80)),
      error: (e, _) => Center(
        child: Text(
          'Erro: ${e.toString().split('\n').first}',
          style: const TextStyle(fontSize: 13, color: slate),
        ),
      ),
      data: (items) => _ResultsList(items: items, onTap: onTap),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        'Type to search manga across all sources',
        style: TextStyle(fontSize: 14, height: 1.5, color: slate),
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.items, required this.onTap});

  final List<MangaSummary> items;
  final void Function(MangaSummary) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Text(
          'No results found',
          style: TextStyle(fontSize: 14, height: 1.5, color: slate),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Text(
            '${items.length} results',
            style: const TextStyle(
              fontSize: 10,
              height: 1,
              letterSpacing: 10 * 0.08,
              color: slate,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => _ResultRow(
              manga: items[i],
              onTap: () => onTap(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.manga, required this.onTap});

  final MangaSummary manga;
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

  Color get _color => _colors[manga.id.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) {
    final sourceName =
        sourceById(manga.sourceId)?.name ?? manga.sourceId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x0F0A0A0A)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 70,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manga.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.2,
                      color: ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (manga.author.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      manga.author,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1,
                        color: slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _SmallChip(text: sourceName, mono: false),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.text, required this.mono});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: const BoxDecoration(
        color: wool,
        borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: mono ? fontMono : null,
          fontSize: 10,
          height: 1,
          color: slate,
        ),
      ),
    );
  }
}
