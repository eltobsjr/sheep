import 'package:dio/dio.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

// Abstract base for WordPress WP-Manga (Madara theme) sites.
// Ported from keiyoushi/extensions-source lib-multisrc/madara
//
// Concrete subclasses only need to override id, name, baseUrl, iconAsset.
// Sites that use non-standard selectors can also override the selector getters.
abstract class MadaraSource extends HttpMangaSource {
  // Override in subclasses if the site uses different selectors.
  String get popularSelector => 'div.page-item-detail';
  String get searchSelector => '.c-tabs-item .c-image-hover a';
  String get chapterSelector => 'li.wp-manga-chapter';
  String get pageSelector => '.reading-content img';

  // Most Madara sites now use the /ajax/chapters/ endpoint.
  bool get useNewChapterEndpoint => true;

  @override
  Map<String, String> get defaultHeaders => const {
    'User-Agent': 'SheepReader/1.0 (Android)',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,en-US;q=0.9,en;q=0.8',
  };

  // ── helpers ────────────────────────────────────────────────────────────────

  String _imgSrc(html_dom.Element el) {
    for (final attr in ['data-src', 'data-lazy-src', 'srcset', 'src']) {
      final val = el.attributes[attr]?.trim() ?? '';
      if (val.isNotEmpty) {
        // srcset may have descriptors like "url 1x, url2 2x" — take first
        return val.split(',').first.trim().split(' ').first;
      }
    }
    return '';
  }

  MangaStatus _toStatus(String? raw) => switch (raw?.toLowerCase().trim()) {
    'ongoing' || 'em lançamento' || 'ativo' => MangaStatus.ongoing,
    'completed' || 'completo' || 'concluído' => MangaStatus.completed,
    'hiatus' || 'em hiato' => MangaStatus.hiatus,
    'cancelled' || 'cancelado' => MangaStatus.cancelled,
    _ => MangaStatus.unknown,
  };

  MangaSummary _parseCard(html_dom.Element el) {
    final anchor = el.querySelector('.post-title a') ?? el.querySelector('a');
    final img = el.querySelector('img');
    final href = anchor?.attributes['href'] ?? '';
    final mangaPath = Uri.tryParse(href)?.path ?? href;
    return MangaSummary(
      id: mangaPath,
      sourceId: id,
      title: anchor?.text.trim() ?? '',
      coverUrl: img != null ? _imgSrc(img) : '',
    );
  }

  // ── MangaSource ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    final html = await fetchHtml(
      '$baseUrl/manga/',
      params: <String, dynamic>{'m_orderby': 'views', 'page': page},
    );
    final doc = html_parser.parse(html);
    return doc
        .querySelectorAll(popularSelector)
        .map(_parseCard)
        .where((m) => m.title.isNotEmpty)
        .toList();
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    final html = await fetchHtml(
      '$baseUrl/manga/',
      params: <String, dynamic>{'m_orderby': 'latest', 'page': page},
    );
    final doc = html_parser.parse(html);
    return doc
        .querySelectorAll(popularSelector)
        .map(_parseCard)
        .where((m) => m.title.isNotEmpty)
        .toList();
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    final html = await fetchHtml(
      '$baseUrl/',
      params: <String, dynamic>{
        's': query,
        'post_type': 'wp-manga',
        'page': page,
      },
    );
    final doc = html_parser.parse(html);
    // Try custom selector first, fall back to popularSelector
    final elements = doc.querySelectorAll(searchSelector).isNotEmpty
        ? doc.querySelectorAll(searchSelector)
        : doc.querySelectorAll(popularSelector);

    final results = <MangaSummary>[];
    for (final el in elements) {
      final href = el.attributes['href'] ?? el.querySelector('a')?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final img = el.querySelector('img');
      final titleEl = el.querySelector('.post-title') ??
          el.querySelector('h3') ??
          el.querySelector('h4');
      results.add(MangaSummary(
        id: Uri.tryParse(href)?.path ?? href,
        sourceId: id,
        title: titleEl?.text.trim() ?? el.text.trim(),
        coverUrl: img != null ? _imgSrc(img) : '',
      ));
    }
    return results.where((m) => m.title.isNotEmpty).toList();
  }

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    final html = await fetchHtml('$baseUrl$mangaUrl');
    final doc = html_parser.parse(html);

    final title = doc.querySelector('.post-title h1')?.text.trim() ??
        doc.querySelector('.post-title h3')?.text.trim() ?? '';

    final img = doc.querySelector('.summary_image img');
    final coverUrl = img != null ? _imgSrc(img) : '';

    final synopsis = doc.querySelector('.summary__content p')?.text.trim() ??
        doc.querySelector('.manga-summary')?.text.trim() ?? '';

    final authorEls = doc.querySelectorAll('.author-content a');
    final authors = authorEls.map((e) => e.text.trim()).toList();

    final statusEl = doc.querySelector('.post-status .summary-content');
    final status = _toStatus(statusEl?.text.trim());

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
    final chapterListUrl = useNewChapterEndpoint
        ? '$baseUrl$mangaUrl${mangaUrl.endsWith('/') ? '' : '/'}ajax/chapters/'
        : '$baseUrl/wp-admin/admin-ajax.php';

    final html = useNewChapterEndpoint
        ? await fetchHtml(chapterListUrl)
        : await _postChapterList(mangaUrl);

    final doc = html_parser.parse(html);
    final items = doc.querySelectorAll(chapterSelector);
    final chapters = <ChapterSummary>[];

    for (final li in items) {
      final anchor = li.querySelector('a');
      final href = anchor?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final chPath = Uri.tryParse(href)?.path ?? href;
      final rawTitle = anchor?.text.trim() ?? '';
      // Extract chapter number from title like "Capítulo 1.5" or "Chapter 10"
      final numMatch = RegExp(r'[\d]+\.?\d*').firstMatch(rawTitle);
      final number = double.tryParse(numMatch?.group(0) ?? '') ?? 0.0;

      chapters.add(ChapterSummary(
        id: chPath,
        title: rawTitle.isNotEmpty ? rawTitle : 'Cap. ${numMatch?.group(0) ?? '?'}',
        number: number,
        url: chPath,
      ));
    }

    // Madara returns chapters newest-first; reverse for ascending order.
    return chapters.reversed.toList();
  }

  Future<String> _postChapterList(String mangaUrl) async {
    // Fallback: POST to admin-ajax.php — needs manga post ID from page.
    // For simplicity, fetch the manga page and extract the ID.
    final html = await fetchHtml('$baseUrl$mangaUrl');
    final doc = html_parser.parse(html);
    final idEl = doc.querySelector('[data-id]');
    final postId = idEl?.attributes['data-id'] ?? '';

    final response = await client.post<String>(
      '/wp-admin/admin-ajax.php',
      data: 'action=ajax_chapterlist_manga&manga_id=$postId',
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.plain,
      ),
    );
    return response.data ?? '';
  }

  @override
  Future<List<String>> getPages(String chapterUrl) async {
    final html = await fetchHtml('$baseUrl$chapterUrl');
    final doc = html_parser.parse(html);
    final images = doc.querySelectorAll(pageSelector);
    return images
        .map((img) => _imgSrc(img))
        .where((src) => src.isNotEmpty)
        .toList();
  }
}

// ── Concrete Madara sites ────────────────────────────────────────────────────

class MangaOnlineSource extends MadaraSource {
  @override
  String get id => 'mangaonline';
  @override
  String get name => 'Manga Online';
  @override
  String get baseUrl => 'https://mangaonline.red';
  @override
  String get iconAsset => 'assets/svg/sources/mangaonline.svg';
  @override
  String get searchSelector => '#loop-content .page-listing-item';
}

class LeitorDeMangasSource extends MadaraSource {
  @override
  String get id => 'leitordemangas';
  @override
  String get name => 'Leitor de Mangás';
  @override
  String get baseUrl => 'https://leitordemangas.com';
  @override
  String get iconAsset => 'assets/svg/sources/leitordemangas.svg';
}

class MangasBrasukaSource extends MadaraSource {
  @override
  String get id => 'mangasbrasuka';
  @override
  String get name => 'Mangás Brasuka';
  @override
  String get baseUrl => 'https://mangasbrasuka.com';
  @override
  String get iconAsset => 'assets/svg/sources/mangasbrasuka.svg';
}

class NinjaScanSource extends MadaraSource {
  @override
  String get id => 'ninjascan';
  @override
  String get name => 'Ninja Scan';
  @override
  String get baseUrl => 'https://ninjascan.com.br';
  @override
  String get iconAsset => 'assets/svg/sources/ninjascan.svg';
}

class MangaDashSource extends MadaraSource {
  @override
  String get id => 'mangadash';
  @override
  String get name => 'MangaDash';
  @override
  String get baseUrl => 'https://mangadash.com.br';
  @override
  String get iconAsset => 'assets/svg/sources/mangadash.svg';
}
