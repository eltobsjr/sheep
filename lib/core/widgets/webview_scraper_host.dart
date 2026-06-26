import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/sources/webview_page_scraper.dart';

// Invisible 1×1 WebView placed offstage by SheepApp.
// Loads a manga reader URL, injects an XHR/fetch interceptor before page
// scripts run, and posts captured image URLs back via SheepScraper channel.
// Calls onDone() when complete (success or timeout) so the overlay entry
// can be removed.
class WebViewScraperHost extends StatefulWidget {
  const WebViewScraperHost({
    super.key,
    required this.request,
    required this.onDone,
  });

  final ScrapeRequest request;
  final VoidCallback onDone;

  @override
  State<WebViewScraperHost> createState() => _WebViewScraperHostState();
}

class _WebViewScraperHostState extends State<WebViewScraperHost> {
  late final WebViewController _controller;
  bool _resolved = false;

  // Injected on onPageStarted so it runs before the page's own scripts.
  // Intercepts XHR and fetch calls to /ajax/read/ and extracts the image array.
  static const _js = r'''
(function() {
  if (window.__sheepInjected) return;
  window.__sheepInjected = true;

  function tryExtract(text) {
    try {
      var d = JSON.parse(text);
      var imgs = d && d.result && d.result.images;
      if (imgs && imgs.length > 0) {
        var urls = imgs.map(function(img) {
          if (Array.isArray(img)) return img[0];
          return img.url || img.src || String(img);
        }).filter(function(u) { return typeof u === 'string' && u.length > 4; });
        if (urls.length > 0) SheepScraper.postMessage(JSON.stringify(urls));
      }
    } catch(e) {}
  }

  var origOpen = XMLHttpRequest.prototype.open;
  var origSend = XMLHttpRequest.prototype.send;

  XMLHttpRequest.prototype.open = function() {
    this.__url = arguments[1];
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    if (this.__url && this.__url.indexOf('/ajax/read/') !== -1) {
      var self = this;
      this.addEventListener('load', function() { tryExtract(self.responseText); });
    }
    return origSend.apply(this, arguments);
  };

  var origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function(url, opts) {
      var p = origFetch.apply(this, arguments);
      if (typeof url === 'string' && url.indexOf('/ajax/read/') !== -1) {
        p.then(function(r) { r.clone().text().then(tryExtract); }).catch(function(){});
      }
      return p;
    };
  }
})();
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('SheepScraper', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _controller.runJavaScript(_js),
        onPageFinished: (_) => _scheduleTimeout(),
      ))
      ..loadRequest(Uri.parse(widget.request.url));
  }

  void _onMessage(JavaScriptMessage msg) {
    if (_resolved) return;
    try {
      final raw = jsonDecode(msg.message) as List<dynamic>;
      final urls = raw
          .map((e) => e.toString())
          .where((u) => u.startsWith('http'))
          .toList();
      if (urls.isNotEmpty) {
        _resolve(urls);
      }
    } catch (_) {}
  }

  void _scheduleTimeout() {
    if (_resolved) return;
    Future.delayed(const Duration(seconds: 6), () {
      if (_resolved || !mounted) return;
      _resolve(const []);
    });
  }

  void _resolve(List<String> urls) {
    if (_resolved) return;
    _resolved = true;
    if (!widget.request.completer.isCompleted) {
      widget.request.completer.complete(urls);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: _controller),
    );
  }
}
