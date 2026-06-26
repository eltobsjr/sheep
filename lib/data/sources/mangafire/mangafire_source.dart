import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// HTML scraper for https://mangafire.to (multi-language)
//
// Chapter list: GET /ajax/manga/{hid}/chapter/{lang}
//   hid = everything after the last dot in the slug
//   Response: JSON { "result": "<li data-number='...'>" }
//
// Chapter URL = "read/{slug}.{hid}/{lang}/chapter-{number}"
// Chapter ID  = "{slug}.{hid}:{number}" (stable, language-independent)
//   so upsert updates the URL when the user switches language.
class MangaFireSource extends HttpMangaSource {
  @override
  String get id => 'mangafire';

  @override
  String get name => 'MangaFire';

  @override
  String get baseUrl => 'https://mangafire.to';

  @override
  String get language => 'multi';

  @override
  List<String> get supportedLanguages => const ['en', 'pt-br', 'es', 'fr'];

  @override
  String get iconAsset => 'assets/svg/sources/mangafire.svg';

  @override
  bool get requiresJavaScript => true;

  @override
  bool get replaceChaptersOnRefetch => false;

  @override
  String chapterBrowserUrl(String chapterUrl) =>
      chapterUrl.startsWith('http') ? chapterUrl : '$baseUrl/$chapterUrl';

  @override
  Map<String, String> get defaultHeaders => {
        ...super.defaultHeaders,
        'Referer': 'https://mangafire.to/',
      };

  MangaStatus _toStatus(String? raw) => switch (raw?.toLowerCase().trim()) {
        'releasing' || 'ongoing' => MangaStatus.ongoing,
        'completed' => MangaStatus.completed,
        'on_hiatus' || 'hiatus' => MangaStatus.hiatus,
        'discontinued' || 'cancelled' => MangaStatus.cancelled,
        _ => MangaStatus.unknown,
      };

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
      if (!seen.add(href)) continue;

      final path = Uri.tryParse(href)?.path ?? href;
      final slug = path.startsWith('/manga/')
          ? path.substring(7).replaceAll(RegExp(r'/$'), '')
          : path.replaceAll(RegExp(r'^/|/$'), '');

      final img = card.querySelector('img');
      final cover = img?.attributes['src'] ??
          img?.attributes['data-src'] ??
          card.querySelector('source')?.attributes['srcset'] ??
          '';

      final title = img?.attributes['alt']?.trim() ??
          a?.attributes['title']?.trim() ??
          card.querySelector('a.name')?.text.trim() ??
          card.querySelector('.info .name')?.text.trim() ??
          card.querySelector('.name')?.text.trim() ??
          card.querySelector('b')?.text.trim() ??
          '';

      if (title.isEmpty || slug.isEmpty) continue;
      results.add(
          MangaSummary(id: slug, sourceId: id, title: title, coverUrl: cover));
    }
    return results;
  }

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
    final html = await fetchHtml('$baseUrl/manga/$mangaUrl');
    final doc = html_parser.parse(html);

    final title = doc.querySelector('.manga-name')?.text.trim() ??
        doc.querySelector('h1')?.text.trim() ??
        '';
    final cover = doc.querySelector('.manga-poster img')?.attributes['src'] ??
        doc.querySelector('.poster img')?.attributes['src'] ??
        '';
    final synopsis = doc.querySelector('.synopsis p')?.text.trim() ??
        doc.querySelector('[class*="description"] p')?.text.trim() ??
        '';
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
  Future<List<ChapterSummary>> getChapters(String mangaUrl,
      {String? lang}) async {
    final selectedLang = lang ?? 'en';
    final dotIdx = mangaUrl.lastIndexOf('.');
    final hid = dotIdx >= 0 ? mangaUrl.substring(dotIdx + 1) : mangaUrl;

    final response = await client.get<dynamic>(
      '/ajax/manga/$hid/chapter/$selectedLang',
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
      final a = li.querySelector('a');
      final href = a?.attributes['href'] ?? '';

      final dataNumber = li.attributes['data-number'] ?? '';
      final double number;
      if (dataNumber.isNotEmpty) {
        final m = RegExp(r'\d+\.?\d*').firstMatch(dataNumber);
        number = double.tryParse(m?.group(0) ?? '') ?? 0.0;
      } else {
        final m = RegExp(r'chapter-(\d+\.?\d*)').firstMatch(href);
        number = double.tryParse(m?.group(1) ?? '') ?? 0.0;
      }
      if (number == 0.0 && dataNumber.isEmpty) continue;

      final numForUrl = number == number.truncateToDouble()
          ? number.toInt().toString()
          : number.toString();

      // Use href from server when it looks like a valid chapter URL;
      // otherwise construct deterministically from slug + lang + number.
      final String chapterUrl;
      if (href.isNotEmpty &&
          href != '#' &&
          href.contains('/read/') &&
          href.contains('/chapter-')) {
        chapterUrl = href.replaceFirst(RegExp(r'^/'), '');
      } else {
        chapterUrl = 'read/$mangaUrl/$selectedLang/chapter-$numForUrl';
      }

      // Stable ID independent of language — so upsert updates the URL
      // when the user switches language instead of creating duplicate rows.
      final stableId = '$mangaUrl:$numForUrl';

      final rawTitle = a?.querySelector('.name')?.text.trim() ??
          a?.text.trim() ??
          '';

      chapters.add(ChapterSummary(
        id: stableId,
        title: rawTitle.isNotEmpty
            ? rawTitle
            : 'Chapter ${dataNumber.isNotEmpty ? dataNumber : numForUrl}',
        number: number,
        url: chapterUrl,
      ));
    }

    return chapters.reversed.toList();
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async =>
      const [];
}
