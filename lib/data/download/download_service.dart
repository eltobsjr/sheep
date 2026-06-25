import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../sources/http_manga_source.dart';
import '../sources/source_registry.dart';

// Downloads chapters from the queue one at a time.
// Pages are written to a _tmp directory; only after ALL pages succeed is the
// directory renamed to its final path — ensuring atomic chapter storage.
class DownloadService {
  DownloadService(this._db);

  final AppDatabase _db;
  bool _running = false;

  Future<void> queue(String chapterId) async {
    await _db.queueDownload(chapterId);
    unawaited(_startIfIdle());
  }

  Future<void> _startIfIdle() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = await _db.nextQueuedDownload();
        if (next == null) break;
        try {
          await _downloadChapter(next.chapterId);
        } catch (_) {
          await _db.markDownloadFailed(next.chapterId);
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _downloadChapter(String chapterId) async {
    final chapter = await _db.watchChapterById(chapterId).first;
    if (chapter == null) return;

    final manga = await _db.watchManga(chapter.mangaId).first;
    if (manga == null) return;

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
  }
}
