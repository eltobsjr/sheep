import 'dart:async';

import 'package:dio/dio.dart';

// Thrown when a source returns a Cloudflare challenge (403/503 with JS wall).
// The BrowseScreen listens to CloudflareBypassService.instance.challenges
// and opens a WebView to let the user (or headless JS) solve the challenge.
class CloudflareException implements Exception {
  const CloudflareException({required this.url, required this.sourceId});

  final String url;
  final String sourceId;

  @override
  String toString() => 'Cloudflare challenge: $sourceId at $url';
}

// Singleton bus between the network layer and the UI layer.
//
// Flow:
//   1. CloudflareInterceptor detects a 403/503 → emits CloudflareException
//   2. UI listens to .challenges, opens WebViewBypassSheet(url, sourceId)
//   3. WebView loads the URL, Cloudflare JS runs, challenge is solved
//   4. UI extracts cookies from WebViewController and calls injectCookies()
//   5. UI calls resolveBypass(url) → the pending Completer completes
//   6. The interceptor retries the original request (with fresh cookies)
class CloudflareBypassService {
  CloudflareBypassService._();

  static final CloudflareBypassService instance = CloudflareBypassService._();

  final _controller = StreamController<CloudflareException>.broadcast();

  Stream<CloudflareException> get challenges => _controller.stream;

  final _completers = <String, Completer<void>>{};

  void _emit(CloudflareException ex) => _controller.add(ex);

  // Returns a Future that completes when the UI resolves the bypass for [url].
  Future<void> waitForBypass(String url) {
    final c = Completer<void>();
    _completers[url] = c;
    return c.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => _completers.remove(url),
    );
  }

  // Called by the UI after the WebView has solved the challenge.
  void resolveBypass(String url) => _completers.remove(url)?.complete();
}

// Dio interceptor added to every HttpMangaSource client.
// Detects Cloudflare challenges and routes them through CloudflareBypassService.
class CloudflareInterceptor extends Interceptor {
  const CloudflareInterceptor(this.sourceId);

  final String sourceId;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    if (status == 403 || status == 503) {
      final body = err.response?.data?.toString() ?? '';
      if (_isCloudflarePage(body)) {
        final url = err.requestOptions.uri.toString();
        final ex = CloudflareException(url: url, sourceId: sourceId);
        CloudflareBypassService.instance._emit(ex);
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: ex,
        ));
        return;
      }
    }
    handler.next(err);
  }

  bool _isCloudflarePage(String body) =>
      body.contains('cf-browser-verification') ||
      body.contains('cf_clearance') ||
      body.contains('Just a moment') ||
      body.contains('Checking your browser');
}
