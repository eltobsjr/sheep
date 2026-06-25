import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'cloudflare_bypass.dart';
import 'manga_source.dart';

abstract class HttpMangaSource extends MangaSource {
  // In-memory cookie jar — persists cookies across requests within one session.
  // Cloudflare clearance cookies (cf_clearance) obtained via WebView bypass
  // are injected here by CloudflareBypassService.
  final DefaultCookieJar cookieJar = DefaultCookieJar();

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
      ..add(CloudflareInterceptor(id));
    return dio;
  }

  Map<String, String> get defaultHeaders => const {
    // Real Chrome UA — helps bypass basic bot-detection before Cloudflare JS.
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
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
