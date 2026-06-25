import 'dart:convert' as dart_convert;

import 'package:dio/dio.dart';

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';
import '../source_auth.dart';

// REST API at https://toonlivre.net/api
// Ported from keiyoushi/extensions-source src/pt/mangalivre
//
// Auth: optional — free content works without login; premium chapters need a JWT.
//   POST /api/auth/login  { email, password } → { token: "..." }
//   GET  /api/auth/me                          → 200 if valid, 401 if expired
class MangaLivreSource extends HttpMangaSource with SourceAuth {
  // JWT stored in-memory. Set by login() / restore(). Cleared on 401.
  String? _token;

  @override
  String get id => 'mangalivre';

  @override
  String get name => 'Manga Livre';

  @override
  String get baseUrl => 'https://toonlivre.net';

  @override
  String get iconAsset => 'assets/svg/sources/mangalivre.svg';

  @override
  Map<String, String> get defaultHeaders => {
    ...super.defaultHeaders,
    'Accept': 'application/json, */*',
  };

  // Inject Authorization header on every request when a token is available.
  @override
  void configureAuthInterceptors(Dio dio) {
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = _token;
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
        onError: (err, handler) {
          if (err.response?.statusCode == 401) _token = null;
          handler.next(err);
        },
      ),
    );
  }

  // ── SourceAuth ──────────────────────────────────────────────────────────────

  @override
  Future<void> login(Dio client, String username, String password) async {
    final response = await client.post<dynamic>(
      '/api/auth/login',
      data: {'email': username, 'password': password},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    final body = response.data;
    if (body is Map<String, dynamic>) {
      // Try common token key names in order of likelihood.
      _token = body['token'] as String?
          ?? body['access_token'] as String?
          ?? body['jwt'] as String?
          ?? (body['data'] as Map<String, dynamic>?)?['token'] as String?;
    }
    if (_token == null) throw Exception('Login failed: no token in response');
  }

  @override
  Future<bool> checkLogin(Dio client) async {
    if (_token == null) return false;
    try {
      await client.get<dynamic>('/api/auth/me');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) _token = null;
      return false;
    }
  }

  // On app start: load token from stored extraJson, then verify session.
  @override
  Future<bool> restore(
    Dio client, {
    required String? username,
    required String? password,
    required String? extraJson,
  }) async {
    if (extraJson != null) {
      try {
        final json =
            dart_convert.jsonDecode(extraJson) as Map<String, dynamic>;
        _token = json['token'] as String?;
      } catch (_) {}
    }
    return super.restore(client,
        username: username, password: password, extraJson: extraJson);
  }

  // Returns the current token serialized for DB storage.
  // Called by the credentials screen after a successful login.
  String? get tokenAsJson =>
      _token != null ? dart_convert.jsonEncode({'token': _token}) : null;

  // ── helpers ─────────────────────────────────────────────────────────────────

  MangaStatus _toStatus(String? raw) => switch (raw?.toLowerCase()) {
        'ongoing' => MangaStatus.ongoing,
        'completed' => MangaStatus.completed,
        _ => MangaStatus.unknown,
      };

  MangaSummary _toSummary(Map<String, dynamic> d) => MangaSummary(
        id: d['id'] as String,
        sourceId: id,
        title: d['title'] as String? ?? '',
        coverUrl: d['coverUrl'] as String? ?? '',
      );

  static String _encodeChapterUrl(String mangaId, String chapterId) =>
      '$mangaId:$chapterId';

  static (String, String) _decodeChapterUrl(String url) {
    final parts = url.split(':');
    return (parts[0], parts[1]);
  }

  // ── MangaSource ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    final response = await client.get<dynamic>(
      '/api/mangas/search',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': 24,
        'sortBy': 'popular',
        'sortOrder': 'desc',
      },
    );
    final body = response.data as Map<String, dynamic>;
    final mangas = body['mangas'] as List<dynamic>;
    return mangas.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    final response = await client.get<dynamic>(
      '/api/mangas/search',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': 24,
        'sortBy': 'updated',
        'sortOrder': 'desc',
      },
    );
    final body = response.data as Map<String, dynamic>;
    final mangas = body['mangas'] as List<dynamic>;
    return mangas.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    final response = await client.get<dynamic>(
      '/api/mangas/search',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': 24,
        'q': query,
        'sortBy': 'popular',
        'sortOrder': 'desc',
      },
    );
    final body = response.data as Map<String, dynamic>;
    final mangas = body['mangas'] as List<dynamic>;
    return mangas.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    final response = await client.get<dynamic>('/api/manga-by-slug/$mangaUrl');
    final d = response.data as Map<String, dynamic>;
    final authors = (d['authors'] as List<dynamic>?)
            ?.map((a) => a as String)
            .toList() ??
        [];
    return MangaDetails(
      id: d['id'] as String,
      title: d['title'] as String? ?? '',
      coverUrl: d['coverUrl'] as String? ?? '',
      synopsis: d['description'] as String? ?? '',
      status: _toStatus(d['status'] as String?),
      authors: authors,
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async {
    final response = await client.get<dynamic>('/api/manga-by-slug/$mangaUrl');
    final d = response.data as Map<String, dynamic>;
    final mangaId = d['id'] as String;
    final chapters = (d['chapters'] as List<dynamic>?) ?? [];
    return chapters.map((raw) {
      final ch = raw as Map<String, dynamic>;
      final chId = ch['id'] as String;
      final numStr = ch['number'] as String? ?? '0';
      final number = double.tryParse(numStr) ?? 0.0;
      return ChapterSummary(
        id: chId,
        title: 'Capítulo $numStr',
        number: number,
        url: _encodeChapterUrl(mangaId, chId),
      );
    }).toList();
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    final (mangaId, chapterId) = _decodeChapterUrl(chapterUrl);
    final response = await client.get<dynamic>(
      '/api/mangas/$mangaId/chapters/$chapterId',
    );
    final d = response.data as Map<String, dynamic>;
    final pages = d['pages'] as List<dynamic>;
    return pages.map((p) => p as String).toList();
  }
}
