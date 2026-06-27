import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../data/db/database_provider.dart';
import '../../data/sources/http_manga_source.dart';
import '../../data/sources/source_registry.dart';

// Full-screen WebView browser for a single manga source.
// Blocks all navigation outside the source domain and Cloudflare infrastructure.
// Has back / forward / reload controls so the user can browse naturally.
//
// When mangaId + chapterId are provided (opening a specific chapter), a
// "Marcar como lido" button appears in the toolbar to track reading progress.
class SourceBrowserScreen extends ConsumerStatefulWidget {
  const SourceBrowserScreen({
    required this.url,
    required this.sourceName,
    required this.sourceId,
    this.mangaId,
    this.chapterId,
    super.key,
  });

  final String url;
  final String sourceName;
  final String sourceId;
  final String? mangaId;
  final String? chapterId;

  @override
  ConsumerState<SourceBrowserScreen> createState() =>
      _SourceBrowserScreenState();
}

class _SourceBrowserScreenState extends ConsumerState<SourceBrowserScreen> {
  late final WebViewController _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _loading = true;
  bool _markedRead = false;

  bool get _hasChapter =>
      widget.mangaId != null && widget.chapterId != null;

  @override
  void initState() {
    super.initState();
    final sourceHost = Uri.tryParse(widget.url)?.host.toLowerCase() ?? '';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => _onPageFinished(),
        onNavigationRequest: (r) => _allow(r.url, sourceHost),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  // Reads cookies for [url] from Android's native WebView cookie store.
  static const _cookieChannel = MethodChannel('sheep/cookies');

  Future<void> _onPageFinished() async {
    final back = await _controller.canGoBack();
    final fwd = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _loading = false;
        _canGoBack = back;
        _canGoForward = fwd;
      });
    }
    // Sync WebView cookies → source Dio CookieJar so API calls work after CF
    // is solved naturally in the browser (e.g., ToonLivre chapters endpoint).
    await _syncCookies();
  }

  Future<void> _syncCookies() async {
    if (!io.Platform.isAndroid) return;
    final source = sourceById(widget.sourceId);
    if (source is! HttpMangaSource) return;
    try {
      final currentUrl = await _controller.currentUrl() ?? widget.url;
      final cookieStr = await _cookieChannel.invokeMethod<String>(
        'getCookies',
        {'url': currentUrl},
      );
      if (cookieStr == null || cookieStr.isEmpty) return;
      final uri = Uri.parse(currentUrl);
      final cookies = <io.Cookie>[];
      for (final part in cookieStr.split('; ')) {
        final eqIdx = part.indexOf('=');
        if (eqIdx <= 0) continue;
        final name = part.substring(0, eqIdx).trim();
        final value = part.substring(eqIdx + 1).trim();
        cookies.add(
          io.Cookie(name, value)
            ..domain = uri.host
            ..path = '/',
        );
      }
      if (cookies.isNotEmpty) {
        await source.cookieJar.saveFromResponse(uri, cookies);
      }
    } catch (_) {}
  }

  NavigationDecision _allow(String url, String sourceHost) {
    final uri = Uri.tryParse(url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return NavigationDecision.prevent;
    }
    final host = uri.host.toLowerCase();
    if (host == sourceHost || host.endsWith('.$sourceHost')) {
      return NavigationDecision.navigate;
    }
    const cfHosts = {
      'challenges.cloudflare.com',
      'cloudflare.com',
    };
    if (cfHosts.any((cf) => host == cf || host.endsWith('.$cf'))) {
      return NavigationDecision.navigate;
    }
    return NavigationDecision.prevent;
  }

  Future<void> _markRead() async {
    final chapterId = widget.chapterId;
    if (chapterId == null) return;
    await ref.read(databaseProvider).markChapterRead(chapterId, isRead: true);
    if (mounted) setState(() => _markedRead = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Navigation bar ──────────────────────────────────────────────
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: paper,
                border: Border(bottom: BorderSide(color: wool)),
              ),
              child: Row(
                children: [
                  // Close
                  _NavButton(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  // Source name label
                  Expanded(
                    child: Text(
                      widget.sourceName,
                      style: const TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1,
                        color: ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Loading indicator
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: slate,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Mark as read — only when opening a specific chapter
                  if (_hasChapter)
                    GestureDetector(
                      onTap: _markedRead ? null : _markRead,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _markedRead ? ink : wool,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(radiusPill)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.string(
                              _markedRead
                                  ? '<svg width="11" height="11" viewBox="0 0 11 11" fill="none"'
                                      ' stroke="#FAFAFA" stroke-width="1.5" stroke-linecap="round"'
                                      ' stroke-linejoin="round"><path d="M1.5 5.5l3 3 5-5"/></svg>'
                                  : '<svg width="11" height="11" viewBox="0 0 11 11" fill="none"'
                                      ' stroke="#6B6B6B" stroke-width="1.5" stroke-linecap="round"'
                                      ' stroke-linejoin="round"><circle cx="5.5" cy="5.5" r="4"/>'
                                      '<path d="M3.5 5.5l1.5 1.5 3-3"/></svg>',
                              width: 11,
                              height: 11,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _markedRead ? 'Lido' : 'Marcar lido',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                height: 1,
                                color: _markedRead ? paper : slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Back
                  _NavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    enabled: _canGoBack,
                    onTap: () => _controller.goBack(),
                  ),
                  // Forward
                  _NavButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    enabled: _canGoForward,
                    onTap: () => _controller.goForward(),
                  ),
                  // Reload
                  _NavButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => _controller.reload(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // ── WebView ─────────────────────────────────────────────────────
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? ink : wool,
        ),
      ),
    );
  }
}
