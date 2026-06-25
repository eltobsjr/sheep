import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// HTML scraper + AJAX for https://mangafire.to (EN)
// Ported from keiyoushi/extensions-source src/en/mangafire
//
// Chapter list:  GET /ajax/manga/{mangaId}/chapter/en
//   Response:    JSON { "result": "<li data-id='...'><a href='/read/...'>" }
// Chapter pages: GET /ajax/read/{chapterId}
//   Response:    JSON { "result": { "images": [["url", pageNum, ""], ...] } }
class MangaFireSource extends HttpMangaSource {
  @override
  String get id => 'mangafire';

  @override
  String get name => 'MangaFire';

  @override
  String get baseUrl => 'https://mangafire.to';

  @override
  String get iconAsset => 'assets/svg/sources/mangafire.svg';

  @override
  Map<String, String> get defaultHeaders => const {
    'User-Agent': 'SheepReader/1.0 (Android)',
    'Referer': 'https://mangafire.to/',
  };

  // ── helpers ────────────────────────────────────────────────────────────────

  MangaStatus _toStatus(String? raw) => switch (raw?.toLowerCase().trim()) {
    'releasing' || 'ongoing' => MangaStatus.ongoing,
    'completed' => MangaStatus.completed,
    'on_hiatus' || 'hiatus' => MangaStatus.hiatus,
    'discontinued' || 'cancelled' => MangaStatus.cancelled,
    _ => MangaStatus.unknown,
  };

  // MangaFire filter page has .unit.inner cards with a cover img and .name text.
  List<MangaSummary> _parseCards(String html) {
    final doc = html_parser.parse(html);
    final results = <MangaSummary>[];
    for (final card in doc.querySelectorAll('.unit .inner')) {
      final a = card.querySelector('a') ??
          card.querySelector('[href]');
      final href = a?.attributes['href'] ?? '';
      if (href.isEmpty || !href.contains('/manga/')) continue;
      final path = Uri.tryParse(href)?.path ?? href;
      final img = card.querySelector('img');
      final cover = img?.attributes['src'] ??
          img?.attributes['data-src'] ?? '';
      final title = card.querySelector('.name')?.text.trim() ??
          card.querySelector('b')?.text.trim() ??
          a?.text.trim() ?? '';
      if (title.isEmpty) continue;
      results.add(MangaSummary(
          id: path, sourceId: id, title: title, coverUrl: cover));
    }
    return results;
  }

  // ── MangaSource ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) => fetchHtml(
        '$baseUrl/filter',
        params: <String, dynamic>{
          'sort': 'trending_7d',
          'language[]': 'en',
          'page': page,
        },
      ).then(_parseCards);

  @override
  Future<List<MangaSummary>> getLatest(int page) => fetchHtml(
        '$baseUrl/filter',
        params: <String, dynamic>{
          'sort': 'recently_updated',
          'language[]': 'en',
          'page': page,
        },
      ).then(_parseCards);

  @override
  Future<List<MangaSummary>> search(String query, int page) => fetchHtml(
        '$baseUrl/filter',
        params: <String, dynamic>{
          'keyword': query,
          'language[]': 'en',
          'page': page,
        },
      ).then(_parseCards);

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    final html = await fetchHtml('$baseUrl$mangaUrl');
    final doc = html_parser.parse(html);

    final title = doc.querySelector('.manga-name')?.text.trim() ??
        doc.querySelector('h1')?.text.trim() ?? '';
    final cover =
        doc.querySelector('.manga-poster img')?.attributes['src'] ??
            doc.querySelector('.poster img')?.attributes['src'] ?? '';
    final synopsis = doc.querySelector('.synopsis p')?.text.trim() ??
        doc
            .querySelector('[class*="description"] p')
            ?.text
            .trim() ?? '';
    final statusEl = doc.querySelector('.manga-status .label') ??
        doc.querySelector('[class*="status"]');
    final status = _toStatus(statusEl?.text);
    final authors = doc
        .querySelectorAll('.manga-author a, [class*="author"] a')
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return MangaDetails(
      id: mangaUrl,
      title: title,
      coverUrl: cover,
      synopsis: synopsis,
      status: status,
      authors: authors,
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async {
    // mangaUrl = /manga/one-piece.lp7ke → extract slug for AJAX
    final mangaId =
        mangaUrl.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => '');

    final response =
        await client.get<dynamic>('/ajax/manga/$mangaId/chapter/en');
    final data = response.data;
    final String html;
    if (data is Map<String, dynamic>) {
      // { "result": "<html>" }
      html = data['result'] as String? ??
          data['html'] as String? ?? '';
    } else {
      html = data as String? ?? '';
    }

    final doc = html_parser.parse(html);
    final chapters = <ChapterSummary>[];

    for (final li in doc.querySelectorAll('li[data-id], li')) {
      final chId = li.attributes['data-id'];
      final a = li.querySelector('a');
      final href = a?.attributes['href'] ?? '';
      if (chId == null && href.isEmpty) continue;
      final id = chId ?? href.split('/').last;
      if (id.isEmpty) continue;
      final rawTitle = a?.querySelector('.name')?.text.trim() ??
          a?.text.trim() ?? '';
      final numMatch = RegExp(r'\d+\.?\d*').firstMatch(rawTitle);
      final number = double.tryParse(numMatch?.group(0) ?? '') ?? 0.0;
      chapters.add(ChapterSummary(
        id: id,
        title: rawTitle.isNotEmpty
            ? rawTitle
            : 'Chapter ${numMatch?.group(0) ?? '?'}',
        number: number,
        url: id,
      ));
    }

    // API returns newest-first — reverse to ascending for DB storage
    return chapters.reversed.toList();
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    final response = await client.get<dynamic>('/ajax/read/$chapterUrl');
    final body = response.data as Map<String, dynamic>;
    final result = body['result'] as Map<String, dynamic>;
    final images = result['images'] as List<dynamic>;
    // Each entry is [url, pageNumber, ""]
    return images.map((img) {
      final arr = img as List<dynamic>;
      return arr[0] as String;
    }).toList();
  }
}
