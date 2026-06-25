import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/tokens.dart';
import '../../data/sources/cloudflare_bypass.dart';

// Bottom sheet that opens a full-screen WebView so the user can solve a
// Cloudflare challenge. When cf_clearance is detected in the cookie store,
// the cookies are injected into the source's CookieJar and the sheet closes.
//
// Cookie extraction uses a MethodChannel to read Android's WebView cookie store
// (HttpOnly cookies are invisible to JS, so we read them natively).
class WebViewBypassSheet extends StatefulWidget {
  const WebViewBypassSheet({
    super.key,
    required this.url,
    required this.sourceId,
    required this.cookieJar,
  });

  final String url;
  final String sourceId;
  final CookieJar cookieJar;

  @override
  State<WebViewBypassSheet> createState() => _WebViewBypassSheetState();
}

class _WebViewBypassSheetState extends State<WebViewBypassSheet> {
  // MethodChannel declared in MainActivity.kt — exposes Android's CookieManager.
  static const _cookieChannel = MethodChannel('sheep/cookies');

  late final WebViewController _controller;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: _onPageFinished,
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _onPageFinished(String pageUrl) async {
    if (_solved) return;
    final cookieStr = await _readNativeCookies(pageUrl);
    if (cookieStr != null && cookieStr.contains('cf_clearance=')) {
      _solved = true;
      await _injectCookies(pageUrl, cookieStr);
      CloudflareBypassService.instance.resolveBypass(widget.url);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // Reads the full cookie string for [url] from Android's CookieManager.
  // Returns null on iOS or if the MethodChannel is not available.
  Future<String?> _readNativeCookies(String url) async {
    if (!io.Platform.isAndroid) return null;
    try {
      return await _cookieChannel.invokeMethod<String>('getCookies', {
        'url': url,
      });
    } catch (_) {
      return null;
    }
  }

  // Parses a "name=value; name2=value2" cookie string and saves the cookies
  // into the source's CookieJar so Dio picks them up on the next request.
  Future<void> _injectCookies(String pageUrl, String cookieStr) async {
    final uri = Uri.parse(pageUrl);
    final cookies = <io.Cookie>[];
    for (final part in cookieStr.split('; ')) {
      final eqIdx = part.indexOf('=');
      if (eqIdx <= 0) continue;
      final name = part.substring(0, eqIdx).trim();
      final value = part.substring(eqIdx + 1).trim();
      final cookie = io.Cookie(name, value)
        ..domain = uri.host
        ..path = '/'
        ..httpOnly = name == 'cf_clearance';
      cookies.add(cookie);
    }
    if (cookies.isNotEmpty) {
      await widget.cookieJar.saveFromResponse(uri, cookies);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: wool,
              borderRadius: BorderRadius.all(Radius.circular(radiusPill)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security check',
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Complete the challenge to continue',
                        style: TextStyle(
                          fontFamily: fontMono,
                          fontSize: 12,
                          color: slate,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: wool,
                      borderRadius: BorderRadius.circular(radiusCard),
                    ),
                    child: const Icon(Icons.close, color: slate, size: 16),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1, color: wool),
          // WebView
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(radiusCard),
                bottomRight: Radius.circular(radiusCard),
              ),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}
