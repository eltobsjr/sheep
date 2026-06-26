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
  int _currentPage = 0;
  bool _overlayVisible = true;
  Timer? _overlayTimer;
  final _pageViewerKey = GlobalKey<_PageViewerState>();

  @override
  void initState() {
    super.initState();
    _scheduleOverlayHide();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final keepOn = ref.read(settingsProvider).keepScreenOn;
    if (keepOn) WakelockPlus.enable();
  }

  @override
  void dispose() {
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

  void _showPagePicker(BuildContext context, int totalPages) {
    if (totalPages <= 1) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PagePickerSheet(
        currentPage: _currentPage,
        totalPages: totalPages,
        onSelect: (page) {
          Navigator.pop(ctx);
          _pageViewerKey.currentState?.jumpToPage(page);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isScroll = settings.readingMode == 'scroll';
    final isRtl = settings.direction == 'rtl';

    final chapterAsync = ref.watch(readerChapterProvider(widget.chapterId));
    final pagesAsync = ref.watch(readerPagesProvider(widget.chapterId));
    final initialPageAsync =
        ref.watch(readerInitialPageProvider(widget.chapterId));
    final mangaTitle = ref.watch(_mangaTitleProvider(widget.mangaId));
    final nextChapterId = ref.watch(
      nextChapterIdProvider((widget.mangaId, widget.chapterId)),
    );
    final needsJsAsync =
        ref.watch(readerSourceNeedsJsProvider(widget.chapterId));

    return PopScope(
      child: Scaffold(
        backgroundColor: charcoal,
        body: _buildBody(
          pagesAsync: pagesAsync,
          initialPageAsync: initialPageAsync,
          chapterAsync: chapterAsync,
          mangaTitle: mangaTitle,
          isScroll: isScroll,
          isRtl: isRtl,
          nextChapterId: nextChapterId,
          needsJs: needsJsAsync.valueOrNull ?? false,
        ),
      ),
    );
  }

  Widget _buildBody({
    required AsyncValue<List<PageImage>> pagesAsync,
    required AsyncValue<int> initialPageAsync,
    required AsyncValue<Chapter?> chapterAsync,
    required String? mangaTitle,
    required bool isScroll,
    required bool isRtl,
    String? nextChapterId,
    bool needsJs = false,
  }) {
    if (pagesAsync.isLoading || initialPageAsync.isLoading) {
      final loadingLabel =
          _chapterLabel(mangaTitle, chapterAsync.valueOrNull);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WoolLoading(),
            if (loadingLabel.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                loadingLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontFamily: fontMono,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (pagesAsync.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Erro ao carregar páginas',
              style: TextStyle(color: paper, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                pagesAsync.error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: slate, fontSize: 10),
              ),
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
      );
    }

    final pages = pagesAsync.valueOrNull ?? const [];
    final rawInitial = initialPageAsync.valueOrNull ?? 0;
    final initialPage =
        rawInitial.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
    final chapter = chapterAsync.valueOrNull;
    final chapterLabel = _chapterLabel(mangaTitle, chapter);

    // Sources that require JavaScript to render pages cannot be scraped
    // directly. Show a prompt to open the chapter in the in-app browser.
    if (needsJs && pages.isEmpty && chapter != null) {
      final sourceName = mangaTitle ?? 'esta fonte';
      final chapterUrl = chapter.url.startsWith('http')
          ? chapter.url
          : 'https://mangafire.to/${chapter.url}';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta fonte requer JavaScript',
                style: TextStyle(
                  color: paper,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'As páginas de $sourceName só podem ser carregadas pelo browser integrado.',
                style: const TextStyle(color: slate, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.push(
                  '/source-browser',
                  extra: {'url': chapterUrl, 'name': 'MangaFire'},
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: paper,
                    borderRadius: BorderRadius.circular(radiusPill),
                  ),
                  child: const Text(
                    'Abrir no browser integrado',
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Page viewer — tap on it toggles overlay
        GestureDetector(
          onTap: _toggleOverlay,
          behavior: HitTestBehavior.translucent,
          child: _PageViewer(
            key: _pageViewerKey,
            pages: pages,
            isScroll: isScroll,
            isRtl: isRtl,
            initialPage: initialPage,
            onPageChanged: (i) => _onPageChanged(i, pages.length),
          ),
        ),

        // Overlay — separate from the page viewer tap zone
        AnimatedOpacity(
          opacity: _overlayVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_overlayVisible,
            child: _Overlay(
              chapterLabel: chapterLabel,
              currentPage: _currentPage + 1,
              totalPages: pages.length,
              isScroll: isScroll,
              onBack: () => context.pop(),
              onZoomIn: () => _pageViewerKey.currentState?.zoomIn(),
              onZoomOut: () => _pageViewerKey.currentState?.zoomOut(),
              onPageTap: () => _showPagePicker(context, pages.length),
              onNextChapter: nextChapterId == null
                  ? null
                  : () => context.pushReplacement(
                        '/reader/${widget.mangaId}/$nextChapterId',
                      ),
            ),
          ),
        ),
      ],
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

class _PageViewer extends StatefulWidget {
  const _PageViewer({
    required this.pages,
    required this.isScroll,
    required this.isRtl,
    required this.initialPage,
    required this.onPageChanged,
    super.key,
  });

  final List<PageImage> pages;
  final bool isScroll;
  final bool isRtl;
  final int initialPage;
  final void Function(int) onPageChanged;

  @override
  State<_PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<_PageViewer> {
  late final ScrollController _scrollCtrl;
  late final ExtendedPageController _pageController;
  int _currentPage = 0;
  bool _scrollRestored = false;

  // Per-page GlobalKeys for controlling gesture state (zoom).
  final Map<int, GlobalKey<ExtendedImageGestureState>> _gestureKeys = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController =
        ExtendedPageController(initialPage: widget.initialPage);
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
    // Scroll mode: restore saved position once content has loaded
    // (maxScrollExtent is 0 on the first frame while images are loading).
    if (widget.isScroll && widget.initialPage > 0) {
      _scrollCtrl.addListener(_restoreScrollOnce);
    }
  }

  void _restoreScrollOnce() {
    if (_scrollRestored || !_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    _scrollRestored = true;
    _scrollCtrl.removeListener(_restoreScrollOnce);
    if (widget.pages.length > 1) {
      _scrollCtrl.jumpTo(
        (max * widget.initialPage / (widget.pages.length - 1))
            .clamp(0.0, max),
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.removeListener(_restoreScrollOnce);
    _scrollCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    final page =
        (_scrollCtrl.offset / max * (widget.pages.length - 1)).round()
            .clamp(0, widget.pages.length - 1);
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      widget.onPageChanged(page);
    }
  }

  GlobalKey<ExtendedImageGestureState> _gestureKeyFor(int index) =>
      _gestureKeys.putIfAbsent(
          index, () => GlobalKey<ExtendedImageGestureState>());

  // Zooms in on the current page (paged mode only).
  void zoomIn() {
    if (widget.isScroll) return;
    final state = _gestureKeys[_currentPage]?.currentState;
    if (state == null) return;
    final scale = state.gestureDetails?.totalScale ?? 1.0;
    if (scale < 1.5) state.handleDoubleTap();
  }

  // Zooms out on the current page (paged mode only).
  void zoomOut() {
    if (widget.isScroll) return;
    final state = _gestureKeys[_currentPage]?.currentState;
    if (state == null) return;
    final scale = state.gestureDetails?.totalScale ?? 1.0;
    if (scale >= 1.5) state.handleDoubleTap();
  }

  // Jumps to the given 0-based page index.
  void jumpToPage(int page) {
    final clamped = page.clamp(0, widget.pages.length - 1);
    if (widget.isScroll) {
      if (_scrollCtrl.hasClients) {
        final max = _scrollCtrl.position.maxScrollExtent;
        if (max > 0 && widget.pages.length > 1) {
          _scrollCtrl.animateTo(
            max * clamped / (widget.pages.length - 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } else {
      _pageController.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildImage(PageImage page, int index) {
    final key = widget.isScroll ? null : _gestureKeyFor(index);
    if (page is NetworkPageImage) {
      return ExtendedImage.network(
        page.url,
        key: key,
        fit: widget.isScroll ? BoxFit.fitWidth : BoxFit.contain,
        mode: widget.isScroll
            ? ExtendedImageMode.none
            : ExtendedImageMode.gesture,
        initGestureConfigHandler: widget.isScroll
            ? null
            : (_) => GestureConfig(
                  minScale: 0.9,
                  maxScale: 4.0,
                  inPageView: true,
                ),
      );
    }
    return ExtendedImage.file(
      (page as FilePageImage).file,
      key: key,
      fit: widget.isScroll ? BoxFit.fitWidth : BoxFit.contain,
      mode: widget.isScroll
          ? ExtendedImageMode.none
          : ExtendedImageMode.gesture,
      initGestureConfigHandler: widget.isScroll
          ? null
          : (_) => GestureConfig(
                minScale: 0.9,
                maxScale: 4.0,
                inPageView: true,
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isScroll) {
      return ListView.builder(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.pages.length,
        itemBuilder: (context, index) =>
            _buildImage(widget.pages[index], index),
      );
    }

    return ExtendedImageGesturePageView.builder(
      itemCount: widget.pages.length,
      controller: _pageController,
      reverse: widget.isRtl,
      onPageChanged: (i) {
        setState(() => _currentPage = i);
        widget.onPageChanged(i);
      },
      itemBuilder: (context, index) => _buildImage(widget.pages[index], index),
    );
  }
}

// ── Overlay ───────────────────────────────────────────────────────────────────

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.chapterLabel,
    required this.currentPage,
    required this.totalPages,
    required this.isScroll,
    required this.onBack,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onPageTap,
    this.onNextChapter,
  });

  final String chapterLabel;
  final int currentPage;
  final int totalPages;
  final bool isScroll;
  final VoidCallback onBack;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onPageTap;
  final VoidCallback? onNextChapter;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Back button (top left)
        Positioned(
          left: 8,
          top: topPad + 4,
          child: GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
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
        ),

        // Clock (top right)
        Positioned(
          right: 16,
          top: topPad + 18,
          child: const _ClockWidget(),
        ),

        // Chapter title chip (top center)
        Positioned(
          top: topPad + 10,
          left: 60,
          right: 60,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0x8C0A0A0A),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),

        // Zoom buttons (bottom left, paged mode only)
        if (!isScroll)
          Positioned(
            left: 16,
            bottom: bottomPad + 28,
            child: Row(
              children: [
                _OverlayRoundBtn(label: '−', onTap: onZoomOut),
                const SizedBox(width: 8),
                _OverlayRoundBtn(label: '+', onTap: onZoomIn),
              ],
            ),
          ),

        // Page counter pill (bottom center, tappable → page picker)
        Positioned(
          bottom: bottomPad + 28,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onPageTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xB80A0A0A),
                  borderRadius:
                      BorderRadius.all(Radius.circular(radiusPill)),
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
        ),

        // "Next chapter →" button (bottom right, on last page only)
        if (onNextChapter != null && currentPage == totalPages)
          Positioned(
            right: 16,
            bottom: bottomPad + 28,
            child: GestureDetector(
              onTap: onNextChapter,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xB80A0A0A),
                  borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
                ),
                child: const Text(
                  'Next →',
                  style: TextStyle(
                    fontFamily: fontMono,
                    fontSize: 13,
                    height: 1,
                    color: paper,
                  ),
                ),
              ),
            ),
          ),

        // Gesture bar
        Positioned(
          bottom: bottomPad + 4,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 130,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0x38FAFAFA),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Clock widget ──────────────────────────────────────────────────────────────

class _ClockWidget extends StatefulWidget {
  const _ClockWidget();

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return Text(
      '$h:$m',
      style: const TextStyle(
        fontFamily: fontMono,
        fontSize: 13,
        color: Color(0xCCFAFAFA),
        height: 1,
      ),
    );
  }
}

// ── Small circular overlay button ─────────────────────────────────────────────

class _OverlayRoundBtn extends StatelessWidget {
  const _OverlayRoundBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xB80A0A0A),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: paper,
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}

// ── Page picker bottom sheet ──────────────────────────────────────────────────

class _PagePickerSheet extends StatefulWidget {
  const _PagePickerSheet({
    required this.currentPage,
    required this.totalPages,
    required this.onSelect,
  });

  final int currentPage;
  final int totalPages;
  final void Function(int) onSelect;

  @override
  State<_PagePickerSheet> createState() => _PagePickerSheetState();
}

class _PagePickerSheetState extends State<_PagePickerSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = (widget.currentPage + 1).toDouble().clamp(
          1,
          widget.totalPages.toDouble(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalPages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x38FAFAFA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Page ${_value.round()} of $total',
            style: const TextStyle(
              fontFamily: fontMono,
              fontSize: 14,
              height: 1,
              color: paper,
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: paper,
              inactiveTrackColor: const Color(0x38FAFAFA),
              thumbColor: paper,
              overlayColor: const Color(0x22FAFAFA),
            ),
            child: Slider(
              value: _value,
              min: 1,
              max: total.toDouble(),
              divisions: total > 1 ? total - 1 : 1,
              onChanged: (v) => setState(() => _value = v),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => widget.onSelect(_value.round() - 1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(radiusPill),
              ),
              child: const Text(
                'Go',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1,
                  color: ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manga title provider ──────────────────────────────────────────────────────

final _watchMangaProvider =
    StreamProvider.autoDispose.family<Manga?, String>(
  (ref, id) => ref.watch(databaseProvider).watchManga(id),
);

final _mangaTitleProvider = Provider.autoDispose.family<String?, String>(
  (ref, mangaId) =>
      ref.watch(_watchMangaProvider(mangaId)).valueOrNull?.title,
);
