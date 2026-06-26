import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../manga_source.dart';

// MangaFire — acesso somente via Source Browser (WebView).
// VRF token gerado por JS obfuscado não pode ser replicado em Dart.
// requiresJavaScript = true → chips no filtro Web do Browse abrem a URL base.
class MangaFireSource extends MangaSource {
  @override
  String get id => 'mangafire';

  @override
  String get name => 'MangaFire';

  @override
  String get baseUrl => 'https://mangafire.to';

  @override
  String get language => 'en';

  @override
  String get iconAsset => 'assets/svg/sources/mangafire.svg';

  @override
  bool get requiresJavaScript => true;

  @override
  String chapterBrowserUrl(String chapterUrl) =>
      chapterUrl.startsWith('http') ? chapterUrl : '$baseUrl/$chapterUrl';

  @override
  Future<List<MangaSummary>> getPopular(int page) async => const [];

  @override
  Future<List<MangaSummary>> getLatest(int page) async => const [];

  @override
  Future<List<MangaSummary>> search(String query, int page) async => const [];

  @override
  Future<MangaDetails> getDetails(String mangaUrl) async => MangaDetails(
        id: mangaUrl,
        title: '',
        coverUrl: '',
        synopsis: '',
        status: MangaStatus.unknown,
        authors: const [],
      );

  @override
  Future<List<ChapterSummary>> getChapters(String mangaUrl) async => const [];

  @override
  Future<List<String>> getPages(String chapterUrl,
      {bool dataSaver = false}) async => const [];
}
