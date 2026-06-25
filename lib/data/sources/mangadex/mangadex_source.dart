import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../http_manga_source.dart';

class MangaDexSource extends HttpMangaSource {
  MangaDexSource({this.lang = 'pt-br'});

  final String lang;

  @override
  String get id => 'mangadex_$lang';

  @override
  String get name => lang == 'pt-br' ? 'MangaDex PT-BR' : 'MangaDex EN';

  @override
  String get baseUrl => 'https://api.mangadex.org';

  @override
  String get iconAsset => 'assets/svg/sources/mangadex.svg';

  static const _coversBase = 'https://uploads.mangadex.org/covers';
  static const _pageLimit = 20;
  static const _chapterBatch = 500;

  @override
  Map<String, String> get defaultHeaders => const {
    'User-Agent': 'SheepReader/1.0 (Android)',
  };

  // ── helpers ────────────────────────────────────────────────────────────────

  String _coverUrl(String mangaId, String? fileName) {
    if (fileName == null || fileName.isEmpty) return '';
    return '$_coversBase/$mangaId/$fileName';
  }

  MangaStatus _toStatus(String? raw) => switch (raw) {
    'ongoing' => MangaStatus.ongoing,
    'completed' => MangaStatus.completed,
    'hiatus' => MangaStatus.hiatus,
    'cancelled' => MangaStatus.cancelled,
    _ => MangaStatus.unknown,
  };

  String _title(Map<String, dynamic> map) {
    final pref = map[lang] as String?;
    if (pref != null && pref.isNotEmpty) return pref;
    final en = map['en'] as String?;
    if (en != null && en.isNotEmpty) return en;
    return (map.values.firstOrNull as String?) ?? '';
  }

  String? _coverFileName(List<dynamic> rels) {
    for (final r in rels) {
      final rel = r as Map<String, dynamic>;
      final type = rel['type'] as String?;
      if (type == 'cover_art') {
        return (rel['attributes'] as Map<String, dynamic>?)?['fileName'] as String?;
      }
    }
    return null;
  }

  List<String> _authors(List<dynamic> rels) {
    final seen = <String>{};
    final out = <String>[];
    for (final r in rels) {
      final rel = r as Map<String, dynamic>;
      final t = rel['type'] as String?;
      if (t == 'author' || t == 'artist') {
        final name = (rel['attributes'] as Map<String, dynamic>?)?['name'] as String?;
        if (name != null && seen.add(name)) out.add(name);
      }
    }
    return out;
  }

  MangaSummary _toSummary(Map<String, dynamic> data) {
    final mangaId = data['id'] as String;
    final attrs = data['attributes'] as Map<String, dynamic>;
    final rels = data['relationships'] as List<dynamic>;
    return MangaSummary(
      id: mangaId,
      sourceId: id,
      title: _title(attrs['title'] as Map<String, dynamic>),
      coverUrl: _coverUrl(mangaId, _coverFileName(rels)),
      author: _authors(rels).firstOrNull ?? '',
    );
  }

  // ── MangaSource ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> getPopular(int page) async {
    final response = await client.get<dynamic>(
      '/manga',
      queryParameters: <String, dynamic>{
        'order[followedCount]': 'desc',
        'availableTranslatedLanguage[]': lang,
        'limit': _pageLimit,
        'offset': (page - 1) * _pageLimit,
        'includes[]': ['cover_art', 'author', 'artist'],
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MangaSummary>> getLatest(int page) async {
    final chapRes = await client.get<dynamic>(
      '/chapter',
      queryParameters: <String, dynamic>{
        'translatedLanguage[]': lang,
        'order[publishAt]': 'desc',
        'limit': _pageLimit,
        'offset': (page - 1) * _pageLimit,
        'includeFuturePublishAt': '0',
        'includeEmptyPages': '0',
      },
    );
    final chapBody = chapRes.data as Map<String, dynamic>;
    final chapData = chapBody['data'] as List<dynamic>;

    final ids = <String>{};
    for (final c in chapData) {
      final rels = (c as Map<String, dynamic>)['relationships'] as List<dynamic>;
      for (final r in rels) {
        final rel = r as Map<String, dynamic>;
        final relType = rel['type'] as String?;
        if (relType == 'manga') ids.add(rel['id'] as String);
      }
    }
    if (ids.isEmpty) return [];

    final mangaRes = await client.get<dynamic>(
      '/manga',
      queryParameters: <String, dynamic>{
        'ids[]': ids.toList(),
        'limit': ids.length,
        'includes[]': ['cover_art', 'author', 'artist'],
      },
    );
    final mangaBody = mangaRes.data as Map<String, dynamic>;
    final mangaData = mangaBody['data'] as List<dynamic>;
    return mangaData.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MangaSummary>> search(String query, int page) async {
    final response = await client.get<dynamic>(
      '/manga',
      queryParameters: <String, dynamic>{
        'title': query,
        'limit': _pageLimit,
        'offset': (page - 1) * _pageLimit,
        'includes[]': ['cover_art', 'author', 'artist'],
        'availableTranslatedLanguage[]': lang,
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data.map((d) => _toSummary(d as Map<String, dynamic>)).toList();
  }

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async {
    final response = await client.get<dynamic>(
      '/manga/$mangaUrl',
      queryParameters: <String, dynamic>{
        'includes[]': ['cover_art', 'author', 'artist'],
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    final mangaId = data['id'] as String;
    final attrs = data['attributes'] as Map<String, dynamic>;
    final rels = data['relationships'] as List<dynamic>;
    final descMap = (attrs['description'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final desc = (descMap[lang] as String?) ?? (descMap['en'] as String?) ?? '';

    final tagList = (attrs['tags'] as List<dynamic>?) ?? const [];
    final genres = tagList
        .where((t) =>
            ((t as Map<String, dynamic>)['attributes'] as Map<String, dynamic>?)?['group'] ==
            'genre')
        .map((t) {
          final n = ((t as Map<String, dynamic>)['attributes'] as Map<String, dynamic>)['name']
              as Map<String, dynamic>;
          return (n['en'] ?? n.values.firstOrNull) as String? ?? '';
        })
        .where((g) => g.isNotEmpty)
        .toList();

    return MangaDetails(
      id: mangaId,
      title: _title(attrs['title'] as Map<String, dynamic>),
      coverUrl: _coverUrl(mangaId, _coverFileName(rels)),
      synopsis: desc,
      status: _toStatus(attrs['status'] as String?),
      authors: _authors(rels),
      genres: genres,
    );
  }

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async {
    final all = <ChapterSummary>[];
    var offset = 0;

    while (true) {
      final response = await client.get<dynamic>(
        '/chapter',
        queryParameters: <String, dynamic>{
          'manga': mangaUrl,
          'translatedLanguage[]': lang,
          'order[chapter]': 'asc',
          'limit': _chapterBatch,
          'offset': offset,
          'includeFuturePublishAt': '0',
        },
      );
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>;
      final total = body['total'] as int;

      for (final raw in data) {
        final ch = raw as Map<String, dynamic>;
        final chId = ch['id'] as String;
        final attrs = ch['attributes'] as Map<String, dynamic>;
        final externalUrl = attrs['externalUrl'];
        if (externalUrl != null && (attrs['pages'] as int? ?? 0) == 0) continue;

        final numStr = attrs['chapter'] as String?;
        final chTitle = attrs['title'] as String?;
        final number = double.tryParse(numStr ?? '') ?? 0.0;
        final title = (chTitle != null && chTitle.isNotEmpty)
            ? chTitle
            : (numStr != null ? 'Cap. $numStr' : 'Sem título');

        final publishAt = attrs['publishAt'] as String?;
        all.add(ChapterSummary(
          id: chId,
          title: title,
          number: number,
          url: chId,
          uploadedAt: publishAt != null ? DateTime.tryParse(publishAt) : null,
        ));
      }

      offset += data.length;
      if (offset >= total || data.isEmpty) break;
    }
    return all;
  }

  @override
  Future<List<String>> getPages(String chapterUrl) async {
    final response = await client.get<dynamic>('/at-home/server/$chapterUrl');
    final body = response.data as Map<String, dynamic>;
    final atHome = body['baseUrl'] as String;
    final chapter = body['chapter'] as Map<String, dynamic>;
    final hash = chapter['hash'] as String;
    final pages = chapter['data'] as List<dynamic>;
    return pages.map((p) => '$atHome/data/$hash/${p as String}').toList();
  }
}
