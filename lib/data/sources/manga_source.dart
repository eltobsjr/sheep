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

  // When true, the source's HTTP API is blocked at TLS fingerprint level (e.g.
  // Cloudflare WAF rejecting non-Chrome clients). Cannot be worked around with
  // cookies. Tapping a manga in Browse opens Source Browser directly instead of
  // the native manga detail screen.
  bool get httpBlocked => false;

  // Language codes offered by multi-language sources (e.g. MangaFire).
  // Empty for single-language sources.
  List<String> get supportedLanguages => const [];

  // When true, fetching chapters replaces all existing rows instead of upserting.
  // Needed for sources whose chapter URLs change when switching language.
  bool get replaceChaptersOnRefetch => false;

  // Returns the web URL for a chapter to open in Source Browser.
  // Override in sources with requiresJavaScript=true to provide the chapter URL.
  String chapterBrowserUrl(String chapterUrl) => baseUrl;

  // Returns the web URL for a manga's main page in Source Browser.
  // Used when httpBlocked=true: tapping a manga opens this URL directly.
  // Default returns baseUrl; override to build per-manga URLs.
  String mangaBrowserUrl(String mangaUrl) => baseUrl;

  Future<List<MangaSummary>> getPopular(int page);
  Future<List<MangaSummary>> getLatest(int page);
  Future<List<MangaSummary>> search(String query, int page);
  Future<MangaDetails> getDetails(String mangaUrl);
  Future<List<ChapterSummary>> getChapters(String mangaUrl, {String? lang});
  Future<List<String>> getPages(String chapterUrl, {bool dataSaver = false});
}
