import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// HTML scraper for https://weebcentral.com
// Ported from keiyoushi/extensions-source src/en/weebcentral
//
// ID format: the series ULID only (e.g. "01J2GKJH7K6VK3EF2M8E3BYSAH").
//   getDetails / getChapters prepend /series/ internally.
//   WeebCentral redirects /series/{id} → /series/{id}/{slug} automatically.
//
// Chapter ID: the chapter ULID (e.g. "01J2..."), extracted from /chapters/{id}/read.
//   Chapter.url stores the full path for getPages().
class WeebCentralSource extends HttpMangaSource {
  @override
  String get id => 'weebcentral';

  @override
  String get name => 'Weeb Central';

  @override
  String get baseUrl => 'https://weebcentral.com';

  @override
  String get iconAsset => 'assets/svg/sources/weebcentral.svg';

  @override
  Map<String, String> get defaultHeaders => {
    ...super.defaultHeaders,
    'Referer': 'https://weebcentral.com/',
  };

  static const _fetchLimit = 32;

  // ── helpers ────────────────────────────────────────────────────────────────

  String? _thumbnailUrl(html_dom.Element el) {
    final srcset = el.querySelector('source')?.attributes['srcset'];
    if (srcset != null && srcset.isNotEmpty) {
      return srcset.replaceAll('small', 'normal');
    }
    final src = el.querySelector('img')?.attributes['src'] ?? '';
    return src.isNotEmpty ? src : null;
  }

  MangaStatus _toStatus(String? raw) => switch (raw?.toLowerCase()) {
    'ongoing' => MangaStatus.ongoing,
    'complete' => MangaStatus.completed,
    'hiatus' => MangaStatus.hiatus,
    'canceled' => MangaStatus.cancelled,
    _ => MangaStatus.unknown,
  };

  // Extract series ULID from /series/{id}/{slug} paths.
  // Prevents double-prefix when router builds /manga/{mangaId}.
  String _seriesIdFromPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    // segments: ["series", "{id}", "{slug}"] — return the ULID
    if (segments.length >= 2 && segments[0] == 'series') return segments[1];
    return segments.isNotEmpty ? segments.last : path;
  }

  List<MangaSummary> _parseSearchPage(String html) {
    final doc = html_parser.parse(html);
    final results = <MangaSummary>[];
    for (final el in doc.querySelectorAll('article > section > a')) {
      final href = el.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final path = Uri.tryParse(href)?.path ?? href;
      final seriesId = _seriesIdFromPath(path);
      // <a> children: <picture> (first-child) then <div>Title</div> (first div)
      // then <div>Official</div> (last div). Use div:first-of-type to skip
      // the picture and land on the title div, NOT div:first-child which fails
      // because no div is the first child.
      final titleEl = el.querySelector('div:first-of-type span') ??
          el.querySelector('div:first-of-type') ??
          el.querySelector('span');
      results.add(MangaSummary(
        id: seriesId,
        sourceId: id,
        title: titleEl?.text.trim() ?? '',
        coverUrl: _thumbnailUrl(el) ?? '',
      ));
    }
    return results;
  }

  // ── MangaSource ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    final html = await fetchHtml(
      '$baseUrl/search/data',
      params: <String, dynamic>{
        'text': '',
        'sort': 'Popularity',
        'order': 'Descending',
        'limit': _fetchLimit,
        'offset': (page - 1) * _fetchLimit,
        'display_mode': 'Full Display',
      },
    );
    return _parseSearchPage(html);
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    final html = await fetchHtml(
      '$baseUrl/search/data',
      params: <String, dynamic>{
        'text': '',
        'sort': 'Latest Updates',
        'order': 'Descending',
        'limit': _fetchLimit,
        'offset': (page - 1) * _fetchLimit,
        'display_mode': 'Full Display',
      },
    );
    return _parseSearchPage(html);
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    final html = await fetchHtml(
      '$baseUrl/search/data',
      params: <String, dynamic>{
        'text': query,
        'limit': _fetchLimit,
        'offset': (page - 1) * _fetchLimit,
        'display_mode': 'Full Display',
      },
    );
    return _parseSearchPage(html);
  }

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    // mangaUrl = series ULID — WeebCentral redirects /series/{id} → full slug URL
    final html = await fetchHtml('$baseUrl/series/$mangaUrl');
    final doc = html_parser.parse(html);

    final sections = doc.querySelectorAll('section[x-data] > section');
    final infoSection = sections.isNotEmpty ? sections[0] : null;
    final titleSection = sections.length > 1 ? sections[1] : null;

    final title = titleSection?.querySelector('h1')?.text.trim() ?? '';
    final coverUrl = infoSection != null ? _thumbnailUrl(infoSection) ?? '' : '';

    final authorEls = infoSection?.querySelectorAll('ul > li a') ?? [];
    final authors = authorEls.map((e) => e.text.trim()).toList();

    final statusText = infoSection?.querySelector('ul > li > a')?.text.trim();
    final status = _toStatus(statusText);

    final synopsis = titleSection?.querySelector('li p')?.text.trim() ?? '';

    return MangaDetails(
      id: mangaUrl,
      title: title,
      coverUrl: coverUrl,
      synopsis: synopsis,
      status: status,
      authors: authors,
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async {
    // mangaUrl = series ULID — chapter list is at /series/{id}/full-chapter-list
    final html =
        await fetchHtml('$baseUrl/series/$mangaUrl/full-chapter-list');
    final doc = html_parser.parse(html);

    final items = doc.querySelectorAll('div[x-data] > a');
    final chapters = <ChapterSummary>[];

    for (final el in items) {
      final href = el.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final path = Uri.tryParse(href)?.path ?? href;
      // path = /chapters/{chapterId}/read
      // Chapter ID = the ULID segment (URL-safe). URL = full path for getPages.
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      // ["chapters", "{id}", "read"] → id = segments[1]
      final chapterId = (segments.length >= 2 && segments[0] == 'chapters')
          ? segments[1]
          : path;
      final nameEl = el.querySelector('span.flex > span');
      final rawTitle = nameEl?.text.trim() ?? '';
      final numMatch = RegExp(r'[\d]+\.?\d*').firstMatch(rawTitle);
      final number = double.tryParse(numMatch?.group(0) ?? '') ?? 0.0;
      chapters.add(ChapterSummary(
        id: chapterId,
        title: rawTitle.isNotEmpty ? rawTitle : path,
        number: number,
        url: path,
      ));
    }

    return chapters;
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    // chapterUrl = full path like /chapters/{id}/read (stored in Chapter.url)
    // images endpoint = /chapters/{id}/read/images?is_prev=False&...
    final html = await fetchHtml(
      '$baseUrl$chapterUrl/images',
      params: <String, dynamic>{
        'is_prev': 'False',
        'reading_style': 'long_strip',
      },
    );
    final doc = html_parser.parse(html);
    return doc
        .querySelectorAll('section img')
        .map((img) =>
            img.attributes['src'] ?? img.attributes['data-src'] ?? '')
        .where((src) => src.isNotEmpty)
        .toList();
  }
}
