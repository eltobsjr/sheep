import 'dart:async';

// A pending request from a source to scrape chapter page URLs via WebView JS.
class ScrapeRequest {
  const ScrapeRequest({
    required this.url,
    required this.sourceId,
    required this.completer,
  });

  final String url;
  final String sourceId;
  final Completer<List<String>> completer;
}

// Singleton bus between the network layer and the UI layer.
// Sources call scrape() → SheepApp creates a hidden WebView → image URLs returned.
//
// Flow:
//   1. Source calls scrape(readerUrl, sourceId) → emits ScrapeRequest
//   2. SheepApp._onScrapeRequest creates an Offstage WebViewScraperHost
//   3. WebView loads the reader page and injects an XHR/fetch interceptor
//   4. Interceptor captures the /ajax/read/ response, posts image URLs
//   5. WebViewScraperHost calls completer.complete(urls) → scrape() returns
class WebViewPageScraper {
  WebViewPageScraper._();
  static final instance = WebViewPageScraper._();

  final _controller = StreamController<ScrapeRequest>.broadcast();
  Stream<ScrapeRequest> get requests => _controller.stream;

  Future<List<String>> scrape(String url, String sourceId) {
    final completer = Completer<List<String>>();
    _controller.add(ScrapeRequest(url: url, sourceId: sourceId, completer: completer));
    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => const [],
    );
  }
}
