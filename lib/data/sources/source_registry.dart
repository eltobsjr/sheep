import 'madara/madara_source.dart';
import 'manga_source.dart';
import 'mangadex/mangadex_source.dart';
import 'mangaflix/mangaflix_source.dart';
import 'mangalivre/mangalivre_source.dart';
import 'weebcentral/weeb_central_source.dart';

// All sources compiled into the APK.
// To add a new Madara site: create a class that extends MadaraSource and
// add an instance here — no other change needed.
final List<MangaSource> allSources = [
  // ── API sources (most reliable, no scraping) ──────────────────────────────
  MangaDexSource(),
  MangaDexSource(lang: 'en'),
  MangaFlixSource(),
  MangaLivreSource(),

  // ── Madara (WordPress WP-Manga) — PT-BR ───────────────────────────────────
  MangaOnlineSource(),
  LeitorDeMangasSource(),
  MangasBrasukaSource(),
  NinjaScanSource(),
  MangaDashSource(),

  // ── HTML scrapers — EN ────────────────────────────────────────────────────
  WeebCentralSource(),
];

// Look up a source by its id.
MangaSource? sourceById(String id) {
  for (final source in allSources) {
    if (source.id == id) return source;
  }
  return null;
}
