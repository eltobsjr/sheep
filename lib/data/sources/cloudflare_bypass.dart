import 'dart:async';

import 'package:dio/dio.dart';

// Thrown when a source returns a Cloudflare challenge (403/503 with JS wall).
// SheepApp listens to CloudflareBypassService.instance.challenges and opens
// a WebViewBypassSheet to let the user solve the challenge.
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
//   2. SheepApp listens to .challenges, opens WebViewBypassSheet(url, sourceId)
//   3. WebView loads the URL, Cloudflare JS runs, challenge is solved
//   4. Sheet extracts cookies via MethodChannel, injects into source's CookieJar
//   5. Sheet calls resolveBypass(url) → the pending Completer completes
//   6. CloudflareInterceptor retries the original request (with fresh cookies)
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

  // Called by the WebViewBypassSheet after cookies have been injected.
  void resolveBypass(String url) => _completers.remove(url)?.complete();
}

// Dio interceptor added to every HttpMangaSource client.
// Detects Cloudflare challenges, routes them through CloudflareBypassService,
// and retries the original request after the user solves the challenge.
class CloudflareInterceptor extends Interceptor {
  CloudflareInterceptor(this.sourceId, this._dio);

  final String sourceId;
  final Dio _dio;

  static const _retryKey = '_cf_retried';

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    // Prevent infinite retry loop.
    if (err.requestOptions.extra[_retryKey] == true) {
      handler.next(err);
      return;
    }

    final status = err.response?.statusCode;
    if (status == 403 || status == 503) {
      final body = err.response?.data?.toString() ?? '';
      if (_isCloudflarePage(body)) {
        final url = err.requestOptions.uri.toString();
        CloudflareBypassService.instance._emit(
          CloudflareException(url: url, sourceId: sourceId),
        );
        try {
          await CloudflareBypassService.instance.waitForBypass(url);
          // Mark as retried so we don't loop if CF still blocks.
          err.requestOptions.extra[_retryKey] = true;
          final response = await _dio.fetch<dynamic>(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (_) {
          // Timeout or other error — fall through to normal error handling.
        }
      }
    }
    handler.next(err);
  }

  bool _isCloudflarePage(String body) =>
      body.contains('cf-browser-verification') ||
      body.contains('cf_clearance') ||
      body.contains('Just a moment') ||
      body.contains('Checking your browser') ||
      body.contains('cf-turnstile') ||
      body.contains('challenges.cloudflare.com');
}
