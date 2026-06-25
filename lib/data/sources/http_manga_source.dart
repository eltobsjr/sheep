import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'auth_service.dart';
import 'cloudflare_bypass.dart';
import 'manga_source.dart';
import 'source_auth.dart';

abstract class HttpMangaSource extends MangaSource {
  // Set by main() before runApp — enables persistent cookie storage on disk.
  // When null, falls back to in-memory DefaultCookieJar (session-only).
  static String? cookieBaseDir;

  // Built lazily on first access.
  late final CookieJar cookieJar = _buildCookieJar();

  CookieJar _buildCookieJar() {
    final base = cookieBaseDir;
    if (base != null) {
      final dir = io.Directory('$base/$id')..createSync(recursive: true);
      return PersistCookieJar(storage: FileStorage('${dir.path}/'));
    }
    return DefaultCookieJar();
  }

  Dio? _client;
  Dio get client => _client ??= _buildClient();

  Dio _buildClient() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: defaultHeaders,
    ));
    dio.interceptors
      ..add(CookieManager(cookieJar))
      ..add(_RateLimitInterceptor())
      ..add(CloudflareInterceptor(id, dio));
    if (this is SourceAuth) {
      // 401 detection — notifies AuthService so the UI can prompt re-login.
      dio.interceptors.add(AuthInterceptor(sourceId: id, sourceName: name));
      // Source-specific interceptors (e.g., Bearer token injection).
      (this as SourceAuth).configureAuthInterceptors(dio);
    }
    return dio;
  }

  Map<String, String> get defaultHeaders => const {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.9',
    'Accept-Language': 'pt-BR,en-US;q=0.9,en;q=0.8',
  };

  Future<String> fetchHtml(String url, {Map<String, dynamic>? params}) async {
    final response = await client.get<String>(
      url,
      queryParameters: params,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }
}

// Enforces a minimum 500 ms gap between requests to the same host.
// Helps avoid triggering bot-detection rate limits before CF kicks in.
class _RateLimitInterceptor extends Interceptor {
  static final _lastRequest = <String, DateTime>{};
  static const _minInterval = Duration(milliseconds: 500);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final host = options.uri.host;
    final last = _lastRequest[host];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minInterval) {
        await Future<void>.delayed(_minInterval - elapsed);
      }
    }
    _lastRequest[host] = DateTime.now();
    handler.next(options);
  }
}
