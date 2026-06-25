import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/sources/source_registry.dart';
import '../../domain/models/page_image.dart';
import '../../domain/page_source.dart';

// Watches the chapter row from Drift by ID.
final readerChapterProvider =
    StreamProvider.autoDispose.family<Chapter?, String>((ref, chapterId) =>
        ref.watch(databaseProvider).watchChapterById(chapterId));

// Loads pages for a chapter — resolves local vs. remote automatically.
final readerPagesProvider =
    FutureProvider.autoDispose.family<List<PageImage>, String>(
        (ref, chapterId) async {
  final db = ref.read(databaseProvider);
  final chapter = await db.watchChapterById(chapterId).first;
  if (chapter == null) throw Exception('Chapter $chapterId not found');

  final manga = await db.watchManga(chapter.mangaId).first;
  if (manga == null) throw Exception('Manga ${chapter.mangaId} not found');

  final pageSource = _resolvePageSource(chapter, manga.sourceId);
  return pageSource.getPages();
});

PageSource _resolvePageSource(Chapter chapter, String sourceId) {
  if (chapter.isDownloaded && chapter.localPath != null) {
    final dir = Directory(chapter.localPath!);
    if (dir.existsSync()) return LocalPageSource(dir);
  }
  final source = sourceById(sourceId);
  if (source == null) throw Exception('Source $sourceId not found');
  return RemotePageSource(source, chapter.url);
}
