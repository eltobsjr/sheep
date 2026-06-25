import 'dart:convert' as dart_convert;

import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// Scraper + tRPC client for https://taiyo.moe (PT-BR)
//
// Tech: Next.js App Router with React Server Components (RSC).
//   No public REST API — uses tRPC internally.
//
// ID format: the media UUID from /media/{uuid}.
//   e.g. "17b03940-450b-4b34-a904-e9b296daee9a"
//
// Chapter URL format: "{mediaId}:{chapterId}"
//   e.g. "17b03940...:9d694606..."
//   getPages() splits on ":" to get both IDs needed for CDN URL.
//
// Chapter pages: parsed from <script>self.__next_f.push([1,"...\"pages\":[...]..."]) tags
//   in the SSR HTML of /chapter/{chapterId}/1.
//
// CDN image URL: https://cdn.taiyo.moe/medias/{mediaId}/chapters/{chapterId}/{pageId}.{ext}
class TaiyoSource extends HttpMangaSource {
  static const _cdnBase = 'https://cdn.taiyo.moe';

  @override
  String get id => 'taiyo';

  @override
  String get name => 'Taiyō';

  @override
  String get baseUrl => 'https://taiyo.moe';

  @override
  String get iconAsset => 'assets/svg/sources/taiyo.svg';

  @override
  Map<String, String> get defaultHeaders => {
        ...super.defaultHeaders,
        'Referer': 'https://taiyo.moe/',
        'Accept': 'text/html,application/json,*/*',
      };

  // ── helpers ────────────────────────────────────────────────────────────────

  // Extract the real CDN URL from a Next.js proxied image URL.
  // /_next/image?url=https%3A%2F%2Fcdn.taiyo.moe%2F...&w=640&q=75
  String _extractCdnUrl(String src) {
    if (!src.contains('/_next/image')) return src;
    final start = src.indexOf('?url=');
    if (start < 0) return src;
    final rest = src.substring(start + 5);
    final ampIdx = rest.indexOf('&');
    final encoded = ampIdx >= 0 ? rest.substring(0, ampIdx) : rest;
    try {
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return encoded;
    }
  }

  // Parse manga cards from any page that has <a href="/media/{uuid}"> links.
  List<MangaSummary> _parseMangaCards(String html) {
    final doc = html_parser.parse(html);
    final seen = <String>{};
    final results = <MangaSummary>[];

    for (final a in doc.querySelectorAll('a[href*="/media/"]')) {
      final href = a.attributes['href'] ?? '';
      final path = Uri.tryParse(href)?.path ?? href;
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.length < 2 || segments[0] != 'media') continue;
      final mediaId = segments[1];
      if (!seen.add(mediaId)) continue;

      // Title: prefer an explicit heading, fall back to first line of text
      final titleEl = a.querySelector('h2') ??
          a.querySelector('h3') ??
          a.querySelector('h1') ??
          a.querySelector('[class*="title"]');
      final rawText = a.text.trim();
      final title = titleEl?.text.trim().isNotEmpty == true
          ? titleEl!.text.trim()
          : rawText.split('\n').first.trim();

      // Cover: look for any img inside the card
      final img = a.querySelector('img');
      final rawSrc = img?.attributes['src'] ??
          img?.attributes['data-src'] ?? '';
      final coverUrl = rawSrc.isNotEmpty ? _extractCdnUrl(rawSrc) : '';

      if (title.isEmpty || mediaId.isEmpty) continue;
      results.add(MangaSummary(
        id: mediaId,
        sourceId: id,
        title: title,
        coverUrl: coverUrl,
      ));
    }
    return results;
  }

  // Parse the RSC payload inside <script>self.__next_f.push([...])> tags
  // to extract the pages array: [{id, extension}, ...]
  List<Map<String, String>> _parsePagesFromRsc(String html) {
    final doc = html_parser.parse(html);
    const marker = r'\"pages\":[';

    for (final script in doc.querySelectorAll('script')) {
      final text = script.text;
      final markerIdx = text.indexOf(marker);
      if (markerIdx < 0) continue;

      // Find the opening bracket
      final bracketIdx = markerIdx + marker.length - 1;
      // Walk forward counting brackets to find matching ]
      var depth = 0;
      var end = bracketIdx;
      for (var i = bracketIdx; i < text.length; i++) {
        final ch = text[i];
        if (ch == '[') {
          depth++;
        } else if (ch == ']') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }

      // Extract the JSON array string and un-escape \" → "
      final rawFragment = text.substring(bracketIdx, end + 1);
      final unescaped = rawFragment.replaceAll(r'\"', '"');

      try {
        final list = dart_convert.jsonDecode(unescaped) as List<dynamic>;
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          return {
            'id': m['id'] as String? ?? '',
            'extension': m['extension'] as String? ?? 'jpg',
          };
        }).where((m) => m['id']!.isNotEmpty).toList();
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  // ── MangaSource ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    if (page > 1) return [];
    final html = await fetchHtml(baseUrl);
    return _parseMangaCards(html);
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    if (page > 1) return [];
    final html = await fetchHtml(baseUrl);
    return _parseMangaCards(html);
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    // Taiyo has no public search API — filter the homepage list locally.
    if (page > 1) return [];
    final html = await fetchHtml(baseUrl);
    final all = _parseMangaCards(html);
    final q = query.toLowerCase();
    return all.where((m) => m.title.toLowerCase().contains(q)).toList();
  }

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    // mangaUrl = mediaId (UUID)
    final html = await fetchHtml('$baseUrl/media/$mangaUrl');
    final doc = html_parser.parse(html);

    // Title: og:title meta tag, then h1
    final ogTitle = doc
        .querySelector('meta[property="og:title"]')
        ?.attributes['content']
        ?.trim();
    final title = ogTitle?.isNotEmpty == true
        ? ogTitle!
        : doc.querySelector('h1')?.text.trim() ?? '';

    // Cover: img[alt*="cover"]
    String coverUrl = '';
    for (final img in doc.querySelectorAll('img')) {
      final alt = (img.attributes['alt'] ?? '').toLowerCase();
      if (alt.contains('cover')) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty) {
          coverUrl = _extractCdnUrl(src);
          break;
        }
      }
    }

    // Synopsis: og:description
    final synopsis = doc
            .querySelector('meta[property="og:description"]')
            ?.attributes['content']
            ?.trim() ??
        doc
            .querySelector('meta[name="description"]')
            ?.attributes['content']
            ?.trim() ??
        '';

    return MangaDetails(
      id: mangaUrl,
      title: title,
      coverUrl: coverUrl,
      synopsis: synopsis,
      status: MangaStatus.unknown,
      authors: [],
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async {
    // mangaUrl = mediaId (UUID)
    final all = <ChapterSummary>[];
    var page = 1;
    const perPage = 50;

    while (true) {
      final inputJson =
          '{"0":{"json":{"mediaId":"$mangaUrl","page":$page,"perPage":$perPage}}}';
      final inputEncoded = Uri.encodeComponent(inputJson);
      final response = await client.get<dynamic>(
        '/api/trpc/chapters.getByMediaId?batch=1&input=$inputEncoded',
      );

      final batchList = response.data as List<dynamic>;
      final result =
          (batchList[0] as Map<String, dynamic>)['result'] as Map<String, dynamic>?;
      final dataWrapper = result?['data'] as Map<String, dynamic>?;
      final jsonData = dataWrapper?['json'] as Map<String, dynamic>?;
      final chapters = (jsonData?['chapters'] as List<dynamic>?) ?? [];
      final totalPages = (jsonData?['totalPages'] as num?)?.toInt() ?? 1;

      for (final raw in chapters) {
        final ch = raw as Map<String, dynamic>;
        final chId = ch['id'] as String;
        final number = (ch['number'] as num?)?.toDouble() ?? 0.0;
        final rawTitle = ch['title'] as String?;
        final createdAt = ch['createdAt'] as String?;

        all.add(ChapterSummary(
          id: chId,
          title: (rawTitle != null && rawTitle.isNotEmpty)
              ? rawTitle
              : 'Capítulo ${number == number.truncateToDouble() ? number.toInt() : number}',
          number: number,
          // Encode mediaId:chapterId — getPages needs both to build CDN URLs.
          url: '$mangaUrl:$chId',
          uploadedAt: createdAt != null ? DateTime.tryParse(createdAt) : null,
        ));
      }

      if (page >= totalPages || chapters.isEmpty) break;
      page++;
    }

    // API returns newest-first — reverse for ascending display
    return all.reversed.toList();
  }

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async {
    // chapterUrl = "{mediaId}:{chapterId}"
    final colonIdx = chapterUrl.lastIndexOf(':');
    if (colonIdx < 0) throw Exception('Taiyo: invalid chapter URL: $chapterUrl');
    final mediaId = chapterUrl.substring(0, colonIdx);
    final chapterId = chapterUrl.substring(colonIdx + 1);

    // Fetch the SSR chapter page — RSC payload contains the pages array.
    final html = await fetchHtml('$baseUrl/chapter/$chapterId/1');
    final pages = _parsePagesFromRsc(html);

    if (pages.isEmpty) {
      throw Exception('Taiyo: no pages found for chapter $chapterId');
    }

    return pages
        .map((p) =>
            '$_cdnBase/medias/$mediaId/chapters/$chapterId/${p["id"]}.${p["extension"]}')
        .toList();
  }
}
