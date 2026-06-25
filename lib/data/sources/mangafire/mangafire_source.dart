import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// HTML scraper + AJAX for https://mangafire.to (EN)
// Ported from keiyoushi/extensions-source src/en/mangafire
//
// Chapter list:  GET /ajax/manga/{slug}/chapter/en
//   Response:    JSON { "result": "<li data-id='...'><a href='/read/...'>" }
// Chapter pages: GET /ajax/read/{chapterId}
//   Response:    JSON { "result": { "images": [["url", pageNum, ""], ...] } }
//
// ID format: the manga slug WITHOUT the /manga/ prefix.
//   e.g. "one-piece.lp7ke" (not "/manga/one-piece.lp7ke")
//   getDetails / getChapters prepend /manga/ internally.
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
  Map<String, String> get defaultHeaders => {
    ...super.defaultHeaders,
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

  // MangaFire may show one card per language for each manga.
  // We deduplicate by href so each manga appears only once.
  List<MangaSummary> _parseCards(String html) {
    final doc = html_parser.parse(html);
    final seen = <String>{};
    final results = <MangaSummary>[];

    for (final card in doc.querySelectorAll('.unit .inner, .unit')) {
      final a = card.querySelector('a.poster') ??
          card.querySelector('a[href*="/manga/"]') ??
          card.querySelector('a');
      final href = a?.attributes['href'] ?? '';
      if (href.isEmpty || !href.contains('/manga/')) continue;
      if (!seen.add(href)) continue; // skip duplicate language variants

      final path = Uri.tryParse(href)?.path ?? href;
      // Store only the slug (after /manga/) — avoids double prefix in router.
      final slug = path.startsWith('/manga/')
          ? path.substring(7).replaceAll(RegExp(r'/$'), '')
          : path.replaceAll(RegExp(r'^/|/$'), '');

      final img = card.querySelector('img');
      final cover = img?.attributes['src'] ??
          img?.attributes['data-src'] ??
          card.querySelector('source')?.attributes['srcset'] ?? '';

      // img[alt] has the real title — .name may contain the language code.
      final title = img?.attributes['alt']?.trim() ??
          a?.attributes['title']?.trim() ??
          card.querySelector('a.name')?.text.trim() ??
          card.querySelector('.info .name')?.text.trim() ??
          card.querySelector('.name')?.text.trim() ??
          card.querySelector('b')?.text.trim() ?? '';

      if (title.isEmpty || slug.isEmpty) continue;
      results.add(MangaSummary(id: slug, sourceId: id, title: title, coverUrl: cover));
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
    // mangaUrl = slug (e.g. "one-piece.lp7ke") — add /manga/ prefix
    final html = await fetchHtml('$baseUrl/manga/$mangaUrl');
    final doc = html_parser.parse(html);

    final title = doc.querySelector('.manga-name')?.text.trim() ??
        doc.querySelector('h1')?.text.trim() ?? '';
    final cover = doc.querySelector('.manga-poster img')?.attributes['src'] ??
        doc.querySelector('.poster img')?.attributes['src'] ?? '';
    final synopsis = doc.querySelector('.synopsis p')?.text.trim() ??
        doc.querySelector('[class*="description"] p')?.text.trim() ?? '';
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
    // mangaUrl = slug (e.g. "one-piece.lp7ke")
    // AJAX endpoint uses only the identifier AFTER the last dot:
    //   "one-piece.lp7ke" → "lp7ke"
    // (same as Mihon's MangaFire extension: manga.url.substringAfterLast("."))
    final dotIdx = mangaUrl.lastIndexOf('.');
    final mangaId =
        dotIdx >= 0 ? mangaUrl.substring(dotIdx + 1) : mangaUrl;

    final response = await client.get<dynamic>(
      '/ajax/manga/$mangaId/chapter/en',
      options: Options(headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, */*',
      }),
    );
    final data = response.data;
    final String html;
    if (data is Map<String, dynamic>) {
      html = data['result'] as String? ?? data['html'] as String? ?? '';
    } else {
      html = data as String? ?? '';
    }

    final doc = html_parser.parse(html);
    final chapters = <ChapterSummary>[];

    var items = doc.querySelectorAll('li[data-id]');
    if (items.isEmpty) items = doc.querySelectorAll('li');

    for (final li in items) {
      final chId = li.attributes['data-id'];
      final a = li.querySelector('a');
      final href = a?.attributes['href'] ?? '';
      if (chId == null && href.isEmpty) continue;
      final chapterRef = chId ?? href.split('/').last;
      if (chapterRef.isEmpty) continue;
      final rawTitle = a?.querySelector('.name')?.text.trim() ??
          a?.text.trim() ?? '';
      final numMatch = RegExp(r'\d+\.?\d*').firstMatch(rawTitle);
      final number = double.tryParse(numMatch?.group(0) ?? '') ?? 0.0;
      chapters.add(ChapterSummary(
        id: chapterRef,
        title: rawTitle.isNotEmpty
            ? rawTitle
            : 'Chapter ${numMatch?.group(0) ?? '?'}',
        number: number,
        url: chapterRef,
      ));
    }

    // API returns newest-first — reverse to ascending for DB storage
    return chapters.reversed.toList();
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    final response = await client.get<dynamic>(
      '/ajax/read/$chapterUrl',
      options: Options(headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, */*',
      }),
    );
    final body = response.data as Map<String, dynamic>;
    final result = body['result'];
    if (result == null) return const [];
    final resultMap = result as Map<String, dynamic>;
    final images = resultMap['images'] as List<dynamic>? ?? const [];
    // Each entry may be [url, pageNum, ""] or {"url": "...", "page": 1}
    return images.map((img) {
      final String rawUrl;
      if (img is List<dynamic>) {
        rawUrl = img[0] as String;
      } else if (img is Map<String, dynamic>) {
        rawUrl = img['url'] as String? ?? img['src'] as String? ?? '';
      } else {
        rawUrl = img as String? ?? '';
      }
      if (rawUrl.startsWith('http')) return rawUrl;
      if (rawUrl.startsWith('//')) return 'https:$rawUrl';
      if (rawUrl.startsWith('/')) return '$baseUrl$rawUrl';
      return rawUrl;
    }).where((url) => url.isNotEmpty).toList();
  }
}
