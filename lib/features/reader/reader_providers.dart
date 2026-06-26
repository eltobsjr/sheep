import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/settings/settings_repository.dart';
import '../../data/sources/source_registry.dart';
import '../../domain/models/page_image.dart';
import '../../domain/page_source.dart';

final readerChapterProvider =
    StreamProvider.autoDispose.family<Chapter?, String>((ref, chapterId) =>
        ref.watch(databaseProvider).watchChapterById(chapterId));

// True when the source for this chapter requires JavaScript to render pages.
// Used by the reader to show the in-app browser fallback instead of 0 pages.
final readerSourceNeedsJsProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, chapterId) async {
  final db = ref.read(databaseProvider);
  final chapter = await db.watchChapterById(chapterId).first;
  if (chapter == null) return false;
  final manga = await db.watchManga(chapter.mangaId).first;
  if (manga == null) return false;
  return sourceById(manga.sourceId)?.requiresJavaScript ?? false;
});

// Source name + chapterBrowserUrl builder for the needsJs fallback in ReaderScreen.
final readerSourceInfoProvider = FutureProvider.autoDispose
    .family<({String name, String Function(String) browserUrl})?
    , String>((ref, chapterId) async {
  final db = ref.read(databaseProvider);
  final chapter = await db.watchChapterById(chapterId).first;
  if (chapter == null) return null;
  final manga = await db.watchManga(chapter.mangaId).first;
  if (manga == null) return null;
  final source = sourceById(manga.sourceId);
  if (source == null) return null;
  return (name: source.name, browserUrl: source.chapterBrowserUrl);
});

final readerPagesProvider =
    FutureProvider.autoDispose.family<List<PageImage>, String>(
        (ref, chapterId) async {
  final db = ref.read(databaseProvider);
  final settings = ref.read(settingsProvider);
  final chapter = await db.watchChapterById(chapterId).first;
  if (chapter == null) throw Exception('Chapter $chapterId not found');

  final manga = await db.watchManga(chapter.mangaId).first;
  if (manga == null) throw Exception('Manga ${chapter.mangaId} not found');

  final dataSaver = settings.imageQuality == 'low';
  final pageSource =
      await _resolvePageSource(chapter, manga.sourceId, dataSaver, db);
  return pageSource.getPages();
});

// Returns the 0-based page index to resume from (0 = start from beginning).
final readerInitialPageProvider =
    FutureProvider.autoDispose.family<int, String>((ref, chapterId) async {
  final db = ref.read(databaseProvider);
  final progress = await db.getReadingProgress(chapterId);
  if (progress == null) return 0;
  return (progress.lastPage - 1).clamp(0, 9999);
});

// Watches all chapters for a manga (used to find next chapter).
final _readerMangaChaptersProvider =
    StreamProvider.autoDispose.family<List<Chapter>, String>(
  (ref, mangaId) => ref.watch(databaseProvider).watchChapters(mangaId),
);

// Returns the next chapter's ID (the chapter with the lowest number greater
// than the current chapter), or null if this is the last chapter.
final nextChapterIdProvider =
    Provider.autoDispose.family<String?, (String, String)>(
  (ref, args) {
    final (mangaId, currentChapterId) = args;
    final chapters =
        ref.watch(_readerMangaChaptersProvider(mangaId)).valueOrNull;
    if (chapters == null || chapters.isEmpty) return null;
    final current = chapters.cast<Chapter?>().firstWhere(
          (ch) => ch?.id == currentChapterId,
          orElse: () => null,
        );
    if (current == null) return null;
    Chapter? next;
    for (final ch in chapters) {
      if (ch.number > current.number) {
        if (next == null || ch.number < next.number) next = ch;
      }
    }
    return next?.id;
  },
);

Future<PageSource> _resolvePageSource(
    Chapter chapter, String sourceId, bool dataSaver, AppDatabase db) async {
  if (chapter.isDownloaded && chapter.localPath != null) {
    final dir = Directory(chapter.localPath!);
    if (dir.existsSync()) return LocalPageSource(dir);
    // Folder gone — reset stale flag so UI reflects reality.
    await db.resetChapterDownload(chapter.id);
  }
  final source = sourceById(sourceId);
  if (source == null) throw Exception('Source $sourceId not found');
  return RemotePageSource(source, chapter.url, dataSaver: dataSaver);
}
