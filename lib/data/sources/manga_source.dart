import '../../domain/models/chapter.dart';
import '../../domain/models/manga.dart';

abstract class MangaSource {
  String get id;
  String get name;
  String get baseUrl;
  String get iconAsset;

  // ISO 639-1 language code: 'pt-br', 'en', etc.
  String get language => 'en';

  // Sources that require JavaScript to render chapter pages set this to true.
  // When true, the reader falls back to the in-app Source Browser WebView.
  bool get requiresJavaScript => false;

  Future<List<MangaSummary>> getPopular(int page);
  Future<List<MangaSummary>> getLatest(int page);
  Future<List<MangaSummary>> search(String query, int page);
  Future<MangaDetails> getDetails(String mangaUrl);
  Future<List<ChapterSummary>> getChapters(String mangaUrl);
  Future<List<String>> getPages(String chapterUrl, {bool dataSaver = false});
}
