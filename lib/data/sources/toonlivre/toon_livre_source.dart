import 'package:dio/dio.dart';

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// REST JSON scraper for https://toonlivre.net (PT-BR)
//
// API base: /api  (same-origin, requires Sec-Fetch-* headers)
// Manga list:   GET /api/mangas/releases?limit={n}&offset={n}
// Search:       GET /api/mangas/search?q={query}&limit={n}&offset={n}
// Detail:       GET /api/mangas/{numericId}
// Chapters:     GET /api/mangas/{numericId}/chapters-paginated?page=1&limit=200&sort=asc
//
// MangaSummary.url stores "{numericId}/{urlSlug}" (compound key).
//   getDetails / getChapters split on "/" to get each part.
//
// Chapter URL = "{urlSlug}/{chapterNumber}"  (e.g. "guerra-dos-corpos/63")
//   chapterBrowserUrl builds: https://toonlivre.net/guerra-dos-corpos/63
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

  @override
  bool get requiresJavaScript => true;

  @override
  String chapterBrowserUrl(String chapterUrl) =>
      chapterUrl.startsWith('http') ? chapterUrl : '$baseUrl/$chapterUrl';

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
          final numId = m['id']?.toString() ?? '';
          if (numId.isEmpty) return null;
          final slug =
              m['uploadSlug'] as String? ?? m['slug'] as String? ?? numId;
          return MangaSummary(
            id: numId,
            sourceId: id,
            title: m['title'] as String? ?? '',
            coverUrl: m['coverUrl'] as String? ?? '',
            url: '$numId/$slug',
          );
        })
        .whereType<MangaSummary>()
        .toList();
  }

  (String, String) _splitUrl(String mangaUrl) {
    final idx = mangaUrl.indexOf('/');
    if (idx < 0) return (mangaUrl, mangaUrl);
    return (mangaUrl.substring(0, idx), mangaUrl.substring(idx + 1));
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
      queryParameters: {
        'limit': _pageSize,
        'offset': offset,
        'sort': 'recent',
      },
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
  Future<MangaDetails> getDetails(String mangaUrl) async {
    final (numericId, _) = _splitUrl(mangaUrl);
    final response = await client.get<dynamic>(
      '/api/mangas/$numericId',
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
        ? rawGenres
            .map((g) => (g is Map ? g['name'] ?? g : g).toString())
            .toList()
        : <String>[];

    return MangaDetails(
      id: numericId,
      title: m['title'] as String? ?? '',
      coverUrl: m['coverUrl'] as String? ?? '',
      synopsis: m['synopsis'] as String? ?? m['description'] as String? ?? '',
      status: _toStatus(m['status'] as String?),
      authors: authors,
      genres: genres,
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl,
      {String? lang}) async {
    final (numericId, slug) = _splitUrl(mangaUrl);
    final response = await client.get<dynamic>(
      '/api/mangas/$numericId/chapters-paginated',
      queryParameters: {'page': 1, 'limit': 500, 'sort': 'asc'},
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
      if (ch is! Map) continue;
      final chId = ch['id']?.toString() ?? '';
      if (chId.isEmpty) continue;
      final number = double.tryParse(ch['number']?.toString() ?? '') ?? 0.0;
      final title = ch['title'] as String? ?? '';
      final numForUrl = number == number.truncateToDouble()
          ? number.toInt().toString()
          : number.toString();

      DateTime? uploadedAt;
      final ts = ch['timestamp'] ?? ch['releaseDate'];
      if (ts is int) {
        uploadedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      }

      chapters.add(ChapterSummary(
        id: chId,
        title: title.isNotEmpty ? title : 'Capítulo $numForUrl',
        number: number,
        url: '$slug/$numForUrl',
        uploadedAt: uploadedAt,
      ));
    }

    chapters.sort((a, b) => a.number.compareTo(b.number));
    return chapters;
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async =>
      const [];
}
