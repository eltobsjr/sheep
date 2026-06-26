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
  // When true, chapter taps open Source Browser instead of the native reader.
  bool get requiresJavaScript => false;

  // Returns the web URL for a chapter to open in Source Browser.
  // Override in sources with requiresJavaScript=true to provide the chapter URL.
  String chapterBrowserUrl(String chapterUrl) => baseUrl;

  Future<List<MangaSummary>> getPopular(int page);
  Future<List<MangaSummary>> getLatest(int page);
  Future<List<MangaSummary>> search(String query, int page);
  Future<MangaDetails> getDetails(String mangaUrl);
  Future<List<ChapterSummary>> getChapters(String mangaUrl);
  Future<List<String>> getPages(String chapterUrl, {bool dataSaver = false});
}
