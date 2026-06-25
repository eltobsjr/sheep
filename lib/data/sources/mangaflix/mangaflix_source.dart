import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// REST API at https://api.mangaflix.net/v1
// Ported from keiyoushi/extensions-source src/pt/mangaflix
class MangaFlixSource extends HttpMangaSource {
  @override
  String get id => 'mangaflix';

  @override
  String get name => 'MangaFlix';

  @override
  String get baseUrl => 'https://api.mangaflix.net/v1';

  @override
  String get iconAsset => 'assets/svg/sources/mangaflix.svg';

  // ── helpers ────────────────────────────────────────────────────────────────

  MangaSummary _toSummary(Map<String, dynamic> d) => MangaSummary(
    id: d['_id'] as String,
    sourceId: id,
    title: d['name'] as String? ?? '',
    coverUrl: (d['poster'] as Map<String, dynamic>?)?['default_url'] as String? ?? '',
  );

  // ── MangaSource ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    if (page > 1) return [];
    final response = await client.get<dynamic>('/browse');
    final body = response.data as Map<String, dynamic>;
    final sections = body['data'] as List<dynamic>;
    for (final s in sections) {
      final section = s as Map<String, dynamic>;
      final key = section['key'] as String?;
      if (key == 'most-read') {
        final items = section['items'] as List<dynamic>?;
        return items?.map((d) => _toSummary(d as Map<String, dynamic>)).toList() ?? [];
      }
    }
    return [];
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    if (page > 1) return [];
    final response = await client.get<dynamic>(
      '/latest-releases',
      queryParameters: <String, dynamic>{'selected_language': 'pt-br'},
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    final response = await client.get<dynamic>(
      '/search/mangas',
      queryParameters: <String, dynamic>{
        'query': query,
        'selected_language': 'pt-br',
      },
    );
    final body = response.data as Map<String, dynamic>;
    final dataWrapper = body['data'] as Map<String, dynamic>;
    final works = dataWrapper['works'] as List<dynamic>;
    return works.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    final response = await client.get<dynamic>('/mangas/$mangaUrl');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final genres = (data['genres'] as List<dynamic>?)
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String? ?? '')
            .where((g) => g.isNotEmpty)
            .toList() ??
        [];

    return MangaDetails(
      id: data['_id'] as String,
      title: data['name'] as String? ?? '',
      coverUrl: (data['poster'] as Map<String, dynamic>?)?['default_url'] as String? ?? '',
      synopsis: data['description'] as String? ?? '',
      status: MangaStatus.unknown,
      authors: genres, // MangaFlix doesn't expose authors in this endpoint
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async {
    final response = await client.get<dynamic>('/mangas/$mangaUrl');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final chapters = (data['chapters'] as List<dynamic>?) ?? [];

    return chapters.map((raw) {
      final ch = raw as Map<String, dynamic>;
      final chId = ch['_id'] as String;
      final numStr = ch['number'] as String? ?? '0';
      final number = double.tryParse(numStr) ?? 0.0;
      final chName = ch['name'] as String?;
      final title = (chName != null && chName.isNotEmpty) ? chName : 'Cap. $numStr';
      return ChapterSummary(id: chId, title: title, number: number, url: chId);
    }).toList();
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    final response = await client.get<dynamic>(
      '/chapters/$chapterUrl',
      queryParameters: <String, dynamic>{'selected_language': 'pt-br'},
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final images = data['images'] as List<dynamic>;
    return images
        .map((img) => (img as Map<String, dynamic>)['default_url'] as String)
        .toList();
  }
}
