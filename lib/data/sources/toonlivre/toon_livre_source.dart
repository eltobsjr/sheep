import '../../../domain/models/chapter.dart';
import '../../../domain/models/manga.dart';
import '../manga_source.dart';

// ToonLivre — acesso somente via Source Browser (WebView).
// requiresJavaScript = true → chips no filtro Web do Browse abrem a URL base.
// Sem scraping HTTP: CF e complexidade de API removidos.
class ToonLivreSource extends MangaSource {
  @override
  String get id => 'toonlivre';

  @override
  String get name => 'ToonLivre';

  @override
  String get baseUrl => 'https://toonlivre.net';

  @override
  String get language => 'pt-br';

  @override
  String get iconAsset => 'assets/svg/sources/toonlivre.svg';

  @override
  bool get requiresJavaScript => true;

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
