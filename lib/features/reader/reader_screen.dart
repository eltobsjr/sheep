import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/wool_loading.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/settings/settings_repository.dart';
import '../../domain/models/page_image.dart';
import 'reader_providers.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    required this.mangaId,
    required this.chapterId,
    super.key,
  });

  final String mangaId;
  final String chapterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late PageController _pageCtrl;
  int _currentPage = 0;
  bool _overlayVisible = true;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _scheduleOverlayHide();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final keepOn = ref.read(settingsProvider).keepScreenOn;
    if (keepOn) WakelockPlus.enable();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _overlayTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) _scheduleOverlayHide();
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  void _onPageChanged(int page, int total) {
    setState(() => _currentPage = page);
    unawaited(
      ref.read(databaseProvider).saveReadingProgress(
            chapterId: widget.chapterId,
            lastPage: page + 1,
            pageCount: total,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(readerChapterProvider(widget.chapterId));
    final pagesAsync = ref.watch(readerPagesProvider(widget.chapterId));
    final mangaAsync = ref.watch(
      // Re-use the existing manga provider from manga_detail_providers.
      // Here we just need the title — watch it simply.
      _mangaTitleProvider(widget.mangaId),
    );

    return Scaffold(
      backgroundColor: charcoal,
      body: pagesAsync.when(
        loading: () => const Center(child: WoolLoading()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Erro ao carregar páginas',
                style: TextStyle(color: paper, fontSize: 14),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.pop(),
                child: const Text(
                  '← Voltar',
                  style: TextStyle(color: slate, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        data: (pages) {
          final chapter = chapterAsync.valueOrNull;
          final mangaTitle = mangaAsync;
          final chapterLabel = _chapterLabel(mangaTitle, chapter);

          return GestureDetector(
            onTap: _toggleOverlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Page viewer ────────────────────────────────────────────
                _PageViewer(
                  pages: pages,
                  controller: _pageCtrl,
                  onPageChanged: (i) => _onPageChanged(i, pages.length),
                ),

                // ── Overlay ─────────────────────────────────────────────────
                AnimatedOpacity(
                  opacity: _overlayVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_overlayVisible,
                    child: _Overlay(
                      chapterLabel: chapterLabel,
                      currentPage: _currentPage + 1,
                      totalPages: pages.length,
                      onBack: () => context.pop(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _chapterLabel(String? mangaTitle, Chapter? chapter) {
    final parts = <String>[];
    if (mangaTitle != null && mangaTitle.isNotEmpty) parts.add(mangaTitle);
    if (chapter != null) {
      final num = chapter.number == chapter.number.truncateToDouble()
          ? 'Ch. ${chapter.number.toInt()}'
          : 'Ch. ${chapter.number}';
      parts.add(num);
    }
    return parts.join(' · ');
  }
}

// ── Page viewer ───────────────────────────────────────────────────────────────

class _PageViewer extends StatelessWidget {
  const _PageViewer({
    required this.pages,
    required this.controller,
    required this.onPageChanged,
  });

  final List<PageImage> pages;
  final PageController controller;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return ExtendedImageGesturePageView.builder(
      itemCount: pages.length,
      controller: ExtendedPageController(),
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final page = pages[index];
        return page is NetworkPageImage
            ? ExtendedImage.network(
                page.url,
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (_) => GestureConfig(
                  minScale: 0.9,
                  maxScale: 4.0,
                  inPageView: true,
                ),
              )
            : ExtendedImage.file(
                (page as FilePageImage).file,
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (_) => GestureConfig(
                  minScale: 0.9,
                  maxScale: 4.0,
                  inPageView: true,
                ),
              );
      },
    );
  }
}

// ── Overlay (chapter chip + page counter + back button) ───────────────────────

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.chapterLabel,
    required this.currentPage,
    required this.totalPages,
    required this.onBack,
  });

  final String chapterLabel;
  final int currentPage;
  final int totalPages;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Back button (top left)
        Positioned(
          left: 16,
          top: topPad + 10,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0x8C0A0A0A),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.string(
                '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"'
                ' stroke="#FAFAFA" stroke-width="1.5" stroke-linecap="round"'
                ' stroke-linejoin="round"><path d="M11 4L5 9l6 5"/></svg>',
                width: 18,
                height: 18,
              ),
            ),
          ),
        ),

        // Chapter title chip (top center)
        Positioned(
          top: topPad + 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0x8C0A0A0A), // rgba(10,10,10,.55)
                borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
              ),
              child: Text(
                chapterLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1,
                  color: paper,
                ),
              ),
            ),
          ),
        ),

        // Page counter pill (bottom center)
        Positioned(
          bottom: bottomPad + 34,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xB80A0A0A), // rgba(10,10,10,.72)
                borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
              ),
              child: Text(
                '$currentPage / $totalPages',
                style: const TextStyle(
                  fontFamily: fontMono,
                  fontSize: 14,
                  height: 1,
                  color: paper,
                ),
              ),
            ),
          ),
        ),

        // Gesture bar
        Positioned(
          bottom: bottomPad + 9,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 130,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0x38FAFAFA), // rgba(250,250,250,.22)
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Reads manga title from DB for the reader overlay.
final _mangaTitleProvider = Provider.autoDispose.family<String?, String>(
  (ref, mangaId) {
    final mangaAsync = ref.watch(
      StreamProvider.autoDispose.family<Manga?, String>((ref, id) =>
          ref.watch(databaseProvider).watchManga(id))(mangaId),
    );
    return mangaAsync.valueOrNull?.title;
  },
);
