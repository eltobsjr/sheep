import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/tokens.dart';

// Full-screen WebView browser for a single manga source.
// Blocks all navigation outside the source domain and Cloudflare infrastructure.
// Has back / forward / reload controls so the user can browse naturally.
class SourceBrowserScreen extends StatefulWidget {
  const SourceBrowserScreen({
    super.key,
    required this.url,
    required this.sourceName,
  });

  final String url;
  final String sourceName;

  @override
  State<SourceBrowserScreen> createState() => _SourceBrowserScreenState();
}

class _SourceBrowserScreenState extends State<SourceBrowserScreen> {
  late final WebViewController _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _loading = true;

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
