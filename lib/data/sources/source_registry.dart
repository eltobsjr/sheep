import 'madara/madara_source.dart';
import 'manga_source.dart';
import 'mangafire/mangafire_source.dart';
import 'mangaflix/mangaflix_source.dart';
import 'taiyo/taiyo_source.dart';
final List<MangaSource> allSources = [
  // ── Madara (WordPress WP-Manga) — PT-BR ───────────────────────────────────
  MangaFlixSource(),
  MangaOnlineSource(),
  MangaLivreToSource(),

  // ── HTML scrapers — EN ────────────────────────────────────────────────────
  MangaFireSource(),

  // ── Next.js tRPC — PT-BR ─────────────────────────────────────────────────
  TaiyoSource(),
];

// Look up a source by its id.
MangaSource? sourceById(String id) {
  for (final source in allSources) {
    if (source.id == id) return source;
  }
  return null;
}
