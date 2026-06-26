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

  // Sources silenced temporarily (e.g. during global search) won't open the bypass sheet.
  final _silenced = <String>{};

  void silenceSource(String sourceId, {Duration duration = const Duration(seconds: 15)}) {
    _silenced.add(sourceId);
    Future<void>.delayed(duration, () => _silenced.remove(sourceId));
  }

  bool isSourceSilenced(String sourceId) => _silenced.contains(sourceId);

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
//
// Uses baseUrl (not the AJAX endpoint) when opening the WebView so the user
// sees an HTML page with the Turnstile widget, not a raw JSON 403 response.
class CloudflareInterceptor extends Interceptor {
  CloudflareInterceptor(this.sourceId, this.baseUrl, this._dio);

  final String sourceId;
  final String baseUrl;
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
      if (_isCloudflarePage(body, err)) {
        if (CloudflareBypassService.instance.isSourceSilenced(sourceId)) {
          handler.next(err); return;
        }
        CloudflareBypassService.instance._emit(
          CloudflareException(url: baseUrl, sourceId: sourceId),
        );
        try {
          await CloudflareBypassService.instance.waitForBypass(baseUrl);
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

  bool _isCloudflarePage(String body, DioException err) {
    // Detect CF HTML challenge pages.
    if (body.contains('cf-browser-verification') ||
        body.contains('cf_clearance') ||
        body.contains('Just a moment') ||
        body.contains('Checking your browser') ||
        body.contains('cf-turnstile') ||
        body.contains('challenges.cloudflare.com')) return true;
    // Detect CF-protected API endpoints: body is JSON/empty but CF-Ray header
    // is always present on any response routed through Cloudflare.
    final cfRay = err.response?.headers.value('cf-ray') ?? '';
    return cfRay.isNotEmpty;
  }
}
