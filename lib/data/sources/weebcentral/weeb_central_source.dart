import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// HTML scraper for https://weebcentral.com
// Ported from keiyoushi/extensions-source src/en/weebcentral
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
  Map<String, String> get defaultHeaders => const {
    'User-Agent': 'SheepReader/1.0 (Android)',
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

  List<MangaSummary> _parseSearchPage(String html) {
    final doc = html_parser.parse(html);
    final results = <MangaSummary>[];
    for (final el in doc.querySelectorAll('article > section > a')) {
      final href = el.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final path = Uri.tryParse(href)?.path ?? href;
      final titleEl = el.querySelector('div:last-child');
      results.add(MangaSummary(
        id: path,
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
    final html = await fetchHtml('$baseUrl$mangaUrl');
    final doc = html_parser.parse(html);

    final sections = doc.querySelectorAll('section[x-data] > section');
    final infoSection = sections.isNotEmpty ? sections[0] : null;
    final titleSection = sections.length > 1 ? sections[1] : null;

    final title = titleSection?.querySelector('h1')?.text.trim() ?? '';
    final coverUrl = infoSection != null ? _thumbnailUrl(infoSection) ?? '' : '';

    final authorEls = infoSection?.querySelectorAll(
          'ul > li a',
        ) ??
        [];
    final authors = authorEls.map((e) => e.text.trim()).toList();

    final statusText = infoSection
        ?.querySelector('ul > li > a')
        ?.text
        .trim();
    final status = _toStatus(statusText);

    final synopsis =
        titleSection?.querySelector('li p')?.text.trim() ?? '';

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
    // mangaUrl = /series/{id}/{slug}
    // chapter list = /series/{id}/full-chapter-list
    final parts = mangaUrl.split('/');
    final seriesId = parts.length > 2 ? parts[2] : '';
    final html = await fetchHtml('$baseUrl/series/$seriesId/full-chapter-list');
    final doc = html_parser.parse(html);

    final items = doc.querySelectorAll('div[x-data] > a');
    final chapters = <ChapterSummary>[];

    for (final el in items) {
      final href = el.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final path = Uri.tryParse(href)?.path ?? href;
      final nameEl = el.querySelector('span.flex > span');
      final rawTitle = nameEl?.text.trim() ?? '';
      final numMatch = RegExp(r'[\d]+\.?\d*').firstMatch(rawTitle);
      final number = double.tryParse(numMatch?.group(0) ?? '') ?? 0.0;
      chapters.add(ChapterSummary(
        id: path,
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
    // chapterUrl = /chapters/{id}
    // images endpoint = /chapters/{id}/images?is_prev=False&reading_style=long_strip
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
        .map((img) => img.attributes['src'] ?? img.attributes['data-src'] ?? '')
        .where((src) => src.isNotEmpty)
        .toList();
  }
}
