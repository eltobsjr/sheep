import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/sources/source_registry.dart';

// Watches the manga row from Drift by ID.
final mangaWatchProvider =
    StreamProvider.autoDispose.family<Manga?, String>((ref, mangaId) {
  return ref.watch(databaseProvider).watchManga(mangaId);
});

// Watches all chapters for a manga, ordered latest first.
final chaptersWatchProvider =
    StreamProvider.autoDispose.family<List<Chapter>, String>((ref, mangaId) {
  return ref.watch(databaseProvider).watchChapters(mangaId);
});

// Fetches manga detail + chapters from source, saves to DB.
// Called from the screen via ref.watch — triggers on first build.
final fetchMangaDetailProvider =
    FutureProvider.autoDispose.family<void, String>((ref, mangaId) async {
  final db = ref.read(databaseProvider);
  final manga = await db.watchManga(mangaId).first;
  if (manga == null) return;

  final source = sourceById(manga.sourceId);
  if (source == null || manga.url == null) return;

  final details = await source.getDetails(manga.url!);
  final chapterSummaries = await source.getChapters(manga.url!);

  // Download cover if not already saved
  String coverPath = manga.coverPath;
  if (details.coverUrl.isNotEmpty && coverPath.isEmpty) {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final coverDir = Directory(p.join(appDocDir.path, 'manga', mangaId));
      await coverDir.create(recursive: true);
      final coverFile = File(p.join(coverDir.path, 'cover.jpg'));
      if (!coverFile.existsSync()) {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent': 'SheepReader/1.0 (Android)',
            'Referer': source.baseUrl,
          },
        ));
        final response = await dio.get<List<int>>(
          details.coverUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          await coverFile.writeAsBytes(response.data!);
        }
      }
      if (coverFile.existsSync()) coverPath = coverFile.path;
    } catch (_) {
      // Non-fatal — continue without cover
    }
  }

  await db.upsertManga(
    MangasCompanion(
      id: Value(manga.id),
      sourceId: Value(manga.sourceId),
      title: Value(details.title),
      coverPath: Value(coverPath),
      status: Value(details.status.name),
      url: Value(manga.url),
      synopsis: Value(details.synopsis),
      author: Value(details.authors.join(', ')),
      genres: Value(jsonEncode(details.genres)),
    ),
  );

  await db.upsertChapters(
    chapterSummaries.map((ch) => ChaptersCompanion(
          id: Value(ch.id),
          mangaId: Value(mangaId),
          title: Value(ch.title),
          number: Value(ch.number),
          url: Value(ch.url),
          uploadedAt: Value(ch.uploadedAt),
        )).toList(),
  );
});

// Toggles library membership for a manga.
final toggleLibraryProvider =
    Provider.autoDispose.family<Future<void> Function(bool), String>(
  (ref, mangaId) => (bool inLibrary) =>
      ref.read(databaseProvider).toggleLibrary(mangaId, inLibrary: inLibrary),
);
