import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/sheep_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/app_database.dart';
import 'library_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SheepColors.of(context);
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_back, color: c.ink, size: 22),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'History',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      height: 1.1,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Body
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: WoolLoading()),
                error: (_, _) => Center(
                  child: Text(
                    'Erro ao carregar histórico',
                    style: TextStyle(color: c.slate, fontSize: 14),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 48, color: c.wool),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum capítulo lido ainda',
                            style: TextStyle(color: c.slate, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryCard(
                        entry: entries[i],
                        onRead: () => context.push(
                          '/reader/${entries[i].mangaId}/${entries[i].chapterId}',
                        ),
                        onMangaTap: () =>
                            context.push('/manga/${entries[i].mangaId}'),
                        c: c,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.onRead,
    required this.onMangaTap,
    required this.c,
  });

  final LastReadEntry entry;
  final VoidCallback onRead;
  final VoidCallback onMangaTap;
  final SheepColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onMangaTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.wool,
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _CoverThumb(
                coverPath: entry.coverPath,
                mangaId: entry.mangaId,
                title: entry.mangaTitle,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.2,
                      color: c.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.chapterTitle} · Pág. ${entry.lastPage}'
                    '${entry.pageCount != null ? ' de ${entry.pageCount}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: c.slate,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: entry.progress,
                      backgroundColor:
                          Color.lerp(c.ink, Colors.transparent, 0.88),
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
            // Read button
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
                      'Ler',
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
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.coverPath,
    required this.mangaId,
    required this.title,
  });

  final String coverPath;
  final String mangaId;
  final String title;

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

  Color get _color => _colors[mangaId.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) {
    if (coverPath.isNotEmpty) {
      return Image.file(
        File(coverPath),
        width: 50,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder,
      );
    }
    return _placeholder;
  }

  Widget get _placeholder => Container(
        width: 50,
        height: 70,
        color: _color,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(6),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: fontMono,
            fontSize: 7,
            height: 1.3,
            color: Color(0x66FAFAFA),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
