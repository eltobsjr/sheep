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
  bool _isPaused = false;
  CancelToken? _cancelToken;
  String? _currentChapterId;

  bool get isPaused => _isPaused;

  Future<void> queue(String chapterId) async {
    await _db.queueDownload(chapterId);
    await Workmanager().registerOneOffTask(
      kDownloadTaskName,
      kDownloadTaskName,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    unawaited(_startIfIdle());
  }

  void pause() {
    _isPaused = true;
    // Cancel the current in-flight request — it will be re-queued automatically.
    _cancelToken?.cancel('paused');
  }

  void resume() {
    _isPaused = false;
    unawaited(_startIfIdle());
  }

  // Cancels and removes a specific chapter from the queue.
  Future<void> cancel(String chapterId) async {
    await _db.cancelDownload(chapterId);
    if (chapterId == _currentChapterId) {
      _cancelToken?.cancel('cancelled');
    }
    // Clean up any partial tmp directory.
    try {
      final chapter = await _db.watchChapterById(chapterId).first;
      if (chapter != null) {
        final docDir = await getApplicationDocumentsDirectory();
        final tmpPath =
            '${docDir.path}/manga/${chapter.mangaId}/${chapterId}_tmp';
        final tmpDir = Directory(tmpPath);
        if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _startIfIdle() => processQueue();

  // Public so the background worker (download_worker.dart) can call this.
  Future<void> processQueue({
    Future<void> Function(String mangaTitle, String chapterTitle)? onChapterDone,
    Future<void> Function(String chapterTitle)? onChapterFailed,
  }) async {
    if (_running || _isPaused) return;
    _running = true;
    try {
      while (true) {
        if (_isPaused) break;
        final next = await _db.nextQueuedDownload();
        if (next == null) break;
        _currentChapterId = next.chapterId;
        _cancelToken = CancelToken();
        try {
          final info =
              await _downloadChapter(next.chapterId, _cancelToken!);
          if (onChapterDone != null && info != null) {
            await onChapterDone(info.$1, info.$2);
          }
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) {
            if (e.message == 'paused') {
              // Put back to queued so it's picked up on resume.
              await _db.setDownloadStatus(next.chapterId, 'queued');
            }
            // If 'cancelled' or other cancel reason: already removed by cancel().
          } else {
            await _db.markDownloadFailed(next.chapterId);
            if (onChapterFailed != null) {
              await onChapterFailed(next.chapterId);
            }
          }
        } catch (_) {
          await _db.markDownloadFailed(next.chapterId);
          if (onChapterFailed != null) {
            await onChapterFailed(next.chapterId);
          }
        } finally {
          _currentChapterId = null;
          _cancelToken = null;
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<(String, String)?> _downloadChapter(
    String chapterId,
    CancelToken cancelToken,
  ) async {
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
          cancelToken: cancelToken,
        );
        final bytes = resp.data;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Empty page at index $i for chapter $chapterId');
        }
        await file.writeAsBytes(bytes);
      } else {
        final dio = Dio();
        final resp = await dio.get<List<int>>(
          urls[i],
          options: Options(responseType: ResponseType.bytes),
          cancelToken: cancelToken,
        );
        final bytes = resp.data;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Empty page at index $i for chapter $chapterId');
        }
        await file.writeAsBytes(bytes);
        dio.close();
      }

      final progress = ((i + 1) / urls.length * 100).round();
      await _db.updateDownloadProgress(chapterId, progress);
    }

    // Atomic: rename tmp → final only after all pages succeed.
    final finalDir = Directory(finalPath);
    if (finalDir.existsSync()) await finalDir.delete(recursive: true);
    await tmpDir.rename(finalPath);

    await _db.markChapterDownloaded(chapterId, finalPath);
    return (manga.title, chapter.title);
  }
}
