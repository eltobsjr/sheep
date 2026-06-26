import 'package:dio/dio.dart';

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// REST JSON scraper for https://toonlivre.net (PT-BR)
//
// API base: /api  (same-origin, requires Sec-Fetch-* headers)
// Manga list:   GET /api/mangas/releases?limit={n}&offset={n}
// Search:       GET /api/mangas/search?q={query}&limit={n}&offset={n}
// Detail:       GET /api/mangas/{mangaId}
// Chapters:     GET /api/mangas/{mangaId}/chapters
// Pages:        GET /api/mangas/{mangaId}/chapters/{chapterId}
//
// chapter.url stores "{mangaId}/{chapterId}" so getPages can split it.
class ToonLivreSource extends HttpMangaSource {
  @override
  String get id => 'toonlivre';

  @override
  String get name => 'ToonLivre';

  @override
  String get baseUrl => 'https://toonlivre.net';

  @override
  String get language => 'pt-br';

  @override
  String get iconAsset => 'assets/svg/sources/toonlivre.svg';

  // Sec-Fetch-* headers are required for the Cloudflare-protected API
  // to accept same-origin CORS requests instead of issuing a 302 redirect.
  @override
  Map<String, String> get defaultHeaders => {
        ...super.defaultHeaders,
        'Referer': '$baseUrl/',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Dest': 'empty',
        'Accept': 'application/json, text/plain, */*',
      };

  static const int _pageSize = 24;

  Options get _jsonOptions => Options(
        headers: {'Accept': 'application/json, text/plain, */*'},
        responseType: ResponseType.json,
      );

  MangaStatus _toStatus(String? raw) => switch (raw?.toLowerCase().trim()) {
        'ongoing' || 'em andamento' => MangaStatus.ongoing,
        'completed' || 'completo' || 'finalizado' => MangaStatus.completed,
        'hiatus' || 'hiato' => MangaStatus.hiatus,
        'cancelled' || 'cancelado' => MangaStatus.cancelled,
        _ => MangaStatus.unknown,
      };

  List<MangaSummary> _parseSummaries(dynamic data) {
    final List<dynamic> list;
    if (data is List<dynamic>) {
      list = data;
    } else if (data is Map) {
      list = data['mangas'] as List<dynamic>? ?? <dynamic>[];
    } else {
      list = <dynamic>[];
    }
    return list
        .map<MangaSummary?>((m) {
          final id = m['id'] as String? ?? m['uploadSlug'] as String? ?? '';
          if (id.isEmpty) return null;
          return MangaSummary(
            id: id,
            sourceId: this.id,
            title: m['title'] as String? ?? '',
            coverUrl: m['coverUrl'] as String? ?? '',
          );
        })
        .whereType<MangaSummary>()
        .toList();
  }

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    final offset = (page - 1) * _pageSize;
    final response = await client.get<dynamic>(
      '/api/mangas/releases',
      queryParameters: {'limit': _pageSize, 'offset': offset},
      options: _jsonOptions,
    );
    return _parseSummaries(response.data);
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    final offset = (page - 1) * _pageSize;
    final response = await client.get<dynamic>(
      '/api/mangas/releases',
      queryParameters: {'limit': _pageSize, 'offset': offset, 'sort': 'recent'},
      options: _jsonOptions,
    );
    return _parseSummaries(response.data);
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    final offset = (page - 1) * _pageSize;
    final response = await client.get<dynamic>(
      '/api/mangas/search',
      queryParameters: {'q': query, 'limit': _pageSize, 'offset': offset},
      options: _jsonOptions,
    );
    return _parseSummaries(response.data);
  }

  @override
  Future<MangaDetails> getDetails(String mangaId) async {
    final response = await client.get<dynamic>(
      '/api/mangas/$mangaId',
      options: _jsonOptions,
    );
    final m = response.data as Map<String, dynamic>;

    final rawAuthors = m['authors'] ?? m['author'];
    final authors = rawAuthors is List
        ? rawAuthors.map((a) => a.toString()).toList()
        : rawAuthors != null
            ? [rawAuthors.toString()]
            : <String>[];

    final rawGenres = m['genres'] ?? m['tags'];
    final genres = rawGenres is List
        ? rawGenres.map((g) => (g is Map ? g['name'] ?? g : g).toString()).toList()
        : <String>[];

    return MangaDetails(
      id: mangaId,
      title: m['title'] as String? ?? '',
      coverUrl: m['coverUrl'] as String? ?? '',
      synopsis: m['synopsis'] as String? ?? m['description'] as String? ?? '',
      status: _toStatus(m['status'] as String?),
      authors: authors,
      genres: genres,
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaId) async {
    final response = await client.get<dynamic>(
      '/api/mangas/$mangaId/chapters-paginated',
      queryParameters: {'page': 1, 'limit': 200, 'sort': 'asc'},
      options: _jsonOptions,
    );

    final data = response.data;
    final List<dynamic> list;
    if (data is List<dynamic>) {
      list = data;
    } else if (data is Map) {
      list = data['chapters'] as List<dynamic>? ?? <dynamic>[];
    } else {
      list = <dynamic>[];
    }

    final chapters = <ChapterSummary>[];
    for (final ch in list) {
      final chId = ch['id'] as String? ?? '';
      if (chId.isEmpty) continue;
      final numStr = ch['number']?.toString() ?? '';
      final number = double.tryParse(numStr) ?? 0.0;
      final title = ch['title'] as String? ?? 'Capítulo $numStr';

      DateTime? uploadedAt;
      final ts = ch['timestamp'] ?? ch['releaseDate'];
      if (ts is int) {
        uploadedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      }

      chapters.add(ChapterSummary(
        id: chId,
        title: title.isNotEmpty ? title : 'Capítulo $numStr',
        number: number,
        url: '$mangaId/$chId',
        uploadedAt: uploadedAt,
      ));
    }

    // API may return newest-first — sort ascending by number
    chapters.sort((a, b) => a.number.compareTo(b.number));
    return chapters;
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    // chapterUrl = "{mangaId}/{chapterId}"
    final parts = chapterUrl.split('/');
    if (parts.length < 2) return const [];
    final mangaId = parts.first;
    final chapterId = parts.sublist(1).join('/');

    final response = await client.get<dynamic>(
      '/api/mangas/$mangaId/chapters/$chapterId',
      options: _jsonOptions,
    );

    final data = response.data;
    if (data == null) return const [];
    final body = data is Map ? data : <String, dynamic>{};

    // Try common page array keys
    List<dynamic>? pages;
    for (final key in ['pages', 'images', 'pageUrls', 'urls', 'content']) {
      if (body[key] is List) {
        pages = body[key] as List;
        break;
      }
    }
    if (pages == null) return const [];

    return pages
        .map<String>((p) {
          if (p is String) return _resolveUrl(p);
          if (p is Map) {
            final url = p['url'] ?? p['src'] ?? p['imageUrl'] ?? '';
            return _resolveUrl(url.toString());
          }
          return '';
        })
        .where((u) => u.isNotEmpty)
        .toList();
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$baseUrl$url';
    return url;
  }
}
