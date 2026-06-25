import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// REST API at https://toonlivre.net/api
// Ported from keiyoushi/extensions-source src/pt/mangalivre
class MangaLivreSource extends HttpMangaSource {
  @override
  String get id => 'mangalivre';

  @override
  String get name => 'Manga Livre';

  @override
  String get baseUrl => 'https://toonlivre.net';

  @override
  String get iconAsset => 'assets/svg/sources/mangalivre.svg';

  @override
  Map<String, String> get defaultHeaders => const {
    'User-Agent': 'SheepReader/1.0 (Android)',
    'Accept': '*/*',
    'Accept-Language': 'pt-BR,en-US;q=0.9,en;q=0.8',
  };

  // ── helpers ────────────────────────────────────────────────────────────────

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

  // Encode chapter reference so getPages can reconstruct mangaId + chapterId.
  // Format: "{mangaId}:{chapterId}"
  static String _encodeChapterUrl(String mangaId, String chapterId) =>
      '$mangaId:$chapterId';

  static (String, String) _decodeChapterUrl(String url) {
    final parts = url.split(':');
    return (parts[0], parts[1]);
  }

  // ── MangaSource ────────────────────────────────────────────────────────────

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
