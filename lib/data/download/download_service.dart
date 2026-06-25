import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../db/app_database.dart';
import '../sources/http_manga_source.dart';
import '../sources/source_registry.dart';
import 'download_worker.dart';

// Downloads chapters from the queue one at a time.
// Pages are written to a _tmp directory; only after ALL pages succeed is the
// directory renamed to its final path — ensuring atomic chapter storage.
class DownloadService {
  DownloadService(this._db);

  final AppDatabase _db;
  bool _running = false;

  Future<void> queue(String chapterId) async {
    await _db.queueDownload(chapterId);
    // Register a background task so downloads survive the app going to background.
    // ExistingWorkPolicy.keep: no-op if a task is already scheduled.
    await Workmanager().registerOneOffTask(
      kDownloadTaskName,
      kDownloadTaskName,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    unawaited(_startIfIdle());
  }

  Future<void> _startIfIdle() => processQueue();

  // Public so the background worker (download_worker.dart) can call this.
  Future<void> processQueue({
    Future<void> Function(String mangaTitle, String chapterTitle)? onChapterDone,
    Future<void> Function(String chapterTitle)? onChapterFailed,
  }) async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = await _db.nextQueuedDownload();
        if (next == null) break;
        try {
          final info = await _downloadChapter(next.chapterId);
          if (onChapterDone != null && info != null) {
            await onChapterDone(info.$1, info.$2);
          }
        } catch (_) {
          await _db.markDownloadFailed(next.chapterId);
          if (onChapterFailed != null) await onChapterFailed(next.chapterId);
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<(String, String)?> _downloadChapter(String chapterId) async {
    final chapter = await _db.watchChapterById(chapterId).first;
    if (chapter == null) return null;

    final manga = await _db.watchManga(chapter.mangaId).first;
    if (manga == null) return null;

    final source = sourceById(manga.sourceId);
    if (source == null) throw Exception('Source not found: ${manga.sourceId}');

    await _db.setDownloadStatus(chapterId, 'downloading');

    final urls = await source.getPages(chapter.url);
    if (urls.isEmpty) throw Exception('No pages for $chapterId');

    final docDir = await getApplicationDocumentsDirectory();
    final base = '${docDir.path}/manga/${chapter.mangaId}';
    final tmpPath = '$base/${chapterId}_tmp';
    final finalPath = '$base/$chapterId';

    final tmpDir = Directory(tmpPath);
    if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    await tmpDir.create(recursive: true);

    for (var i = 0; i < urls.length; i++) {
      final filename = '${i.toString().padLeft(3, '0')}.jpg';
      final file = File('${tmpDir.path}/$filename');

      if (source is HttpMangaSource) {
        final resp = await source.client.get<List<int>>(
          urls[i],
          options: Options(responseType: ResponseType.bytes),
        );
        await file.writeAsBytes(resp.data ?? []);
      } else {
        final dio = Dio();
        final resp = await dio.get<List<int>>(
          urls[i],
          options: Options(responseType: ResponseType.bytes),
        );
        await file.writeAsBytes(resp.data ?? []);
        dio.close();
      }

      final progress = ((i + 1) / urls.length * 100).round();
      await _db.updateDownloadProgress(chapterId, progress);
    }

    // Atomic: rename tmp → final only after all pages succeed
    final finalDir = Directory(finalPath);
    if (finalDir.existsSync()) await finalDir.delete(recursive: true);
    await tmpDir.rename(finalPath);

    await _db.markChapterDownloaded(chapterId, finalPath);
    return (manga.title, chapter.title);
  }
}
