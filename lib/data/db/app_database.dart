import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

// Joined result for active download items.
class ActiveDownloadEntry {
  const ActiveDownloadEntry({
    required this.chapterId,
    required this.mangaId,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.progress,
    required this.status,
  });

  final String chapterId;
  final String mangaId;
  final String mangaTitle;
  final String chapterTitle;
  final int progress; // 0–100
  final String status;
}

// Joined result for completed downloads (grouped by manga).
class CompletedDownloadEntry {
  const CompletedDownloadEntry({
    required this.mangaId,
    required this.mangaTitle,
    required this.chapterCount,
  });

  final String mangaId;
  final String mangaTitle;
  final int chapterCount;
}

// Joined result for the "Continue Reading" card.
class LastReadEntry {
  const LastReadEntry({
    required this.mangaId,
    required this.mangaTitle,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.lastPage,
    this.pageCount,
  });

  final String mangaId;
  final String mangaTitle;
  final String chapterId;
  final String chapterTitle;
  final double chapterNumber;
  final int lastPage;
  final int? pageCount;

  double get progress =>
      (pageCount != null && pageCount! > 0) ? lastPage / pageCount! : 0.0;
  int get progressPercent => (progress * 100).clamp(0, 100).round();
}

@DriftDatabase(tables: [Mangas, Chapters, ReadingProgress, DownloadQueue, SourceCredentials])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) await m.createTable(sourceCredentials);
      if (from < 3) {
        await m.addColumn(mangas, mangas.url);
        await m.addColumn(mangas, mangas.synopsis);
        await m.addColumn(mangas, mangas.author);
        await m.addColumn(mangas, mangas.genres);
        await m.addColumn(chapters, chapters.uploadedAt);
      }
    },
  );

  // Watches all mangas that the user added to their library.
  Stream<List<Manga>> watchLibraryMangas() =>
      (select(mangas)..where((m) => m.inLibrary.equals(true))).watch();

  // Watches a single manga by its ID.
  Stream<Manga?> watchManga(String mangaId) =>
      (select(mangas)..where((m) => m.id.equals(mangaId)))
          .watchSingleOrNull();

  // Watches all chapters for a manga, ordered latest first.
  Stream<List<Chapter>> watchChapters(String mangaId) =>
      (select(chapters)
            ..where((c) => c.mangaId.equals(mangaId))
            ..orderBy([(c) => OrderingTerm.desc(c.number)]))
          .watch();

  // Adds or removes a manga from the library.
  Future<void> toggleLibrary(String mangaId, {required bool inLibrary}) =>
      (update(mangas)..where((m) => m.id.equals(mangaId)))
          .write(MangasCompanion(inLibrary: Value(inLibrary)));

  // Inserts or updates a manga (e.g. after fetching details from source).
  Future<void> upsertManga(MangasCompanion row) =>
      into(mangas).insertOnConflictUpdate(row);

  // Bulk inserts/updates chapters (e.g. after fetching chapter list from source).
  Future<void> upsertChapters(List<ChaptersCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(chapters, rows));
  }

  // Watches a single chapter by its ID.
  Stream<Chapter?> watchChapterById(String chapterId) =>
      (select(chapters)..where((c) => c.id.equals(chapterId)))
          .watchSingleOrNull();

  // Saves reading progress (page number) for a chapter.
  Future<void> saveReadingProgress({
    required String chapterId,
    required int lastPage,
    int? pageCount,
  }) async {
    if (pageCount != null) {
      await (update(chapters)..where((c) => c.id.equals(chapterId)))
          .write(ChaptersCompanion(pageCount: Value(pageCount)));
    }
    await into(readingProgress).insertOnConflictUpdate(
      ReadingProgressCompanion(
        chapterId: Value(chapterId),
        lastPage: Value(lastPage),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Watches active/queued downloads, joined with chapter and manga info.
  Stream<List<ActiveDownloadEntry>> watchActiveDownloads() {
    final q = select(downloadQueue).join([
      innerJoin(chapters, chapters.id.equalsExp(downloadQueue.chapterId)),
      innerJoin(mangas, mangas.id.equalsExp(chapters.mangaId)),
    ])..where(downloadQueue.status.isIn(['queued', 'downloading']));

    return q.watch().map((rows) => rows.map((row) {
          final dq = row.readTable(downloadQueue);
          final ch = row.readTable(chapters);
          final m = row.readTable(mangas);
          return ActiveDownloadEntry(
            chapterId: dq.chapterId,
            mangaId: m.id,
            mangaTitle: m.title,
            chapterTitle: ch.title,
            progress: dq.progress,
            status: dq.status,
          );
        }).toList());
  }

  // Watches completed downloads (chapters with isDownloaded=true), grouped by manga.
  Stream<List<CompletedDownloadEntry>> watchCompletedDownloads() {
    final q = select(chapters).join([
      innerJoin(mangas, mangas.id.equalsExp(chapters.mangaId)),
    ])..where(chapters.isDownloaded.equals(true));

    return q.watch().map((rows) {
      final grouped = <String, CompletedDownloadEntry>{};
      for (final row in rows) {
        final m = row.readTable(mangas);
        final existing = grouped[m.id];
        grouped[m.id] = CompletedDownloadEntry(
          mangaId: m.id,
          mangaTitle: m.title,
          chapterCount: (existing?.chapterCount ?? 0) + 1,
        );
      }
      return grouped.values.toList();
    });
  }

  // Saves a manga summary to DB (does NOT overwrite inLibrary or detailed fields).
  Future<void> saveSummary({
    required String id,
    required String sourceId,
    required String title,
    required String url,
  }) => into(mangas).insertOnConflictUpdate(
    MangasCompanion.insert(
      id: id,
      sourceId: sourceId,
      title: title,
      coverPath: '',
      status: 'unknown',
      url: Value(url),
    ),
  );

  // ── Download queue ────────────────────────────────────────────────────────

  // Enqueues a chapter for download (no-op if already queued).
  Future<void> queueDownload(String chapterId) async {
    final existing = await (select(downloadQueue)
          ..where((d) => d.chapterId.equals(chapterId)))
        .getSingleOrNull();
    if (existing != null) return;
    await into(downloadQueue).insert(
      DownloadQueueCompanion.insert(chapterId: chapterId, status: 'queued'),
    );
  }

  // Returns the next chapter waiting to be downloaded.
  Future<DownloadQueueData?> nextQueuedDownload() =>
      (select(downloadQueue)
            ..where((d) => d.status.equals('queued'))
            ..limit(1))
          .getSingleOrNull();

  // Updates the download progress (0–100) for a chapter.
  Future<void> updateDownloadProgress(String chapterId, int progress) =>
      (update(downloadQueue)..where((d) => d.chapterId.equals(chapterId)))
          .write(DownloadQueueCompanion(progress: Value(progress)));

  // Sets the queue status for a chapter ('downloading', 'queued', etc.).
  Future<void> setDownloadStatus(String chapterId, String status) =>
      (update(downloadQueue)..where((d) => d.chapterId.equals(chapterId)))
          .write(DownloadQueueCompanion(status: Value(status)));

  // Marks a chapter as fully downloaded and removes it from the queue.
  Future<void> markChapterDownloaded(
    String chapterId,
    String localPath,
  ) async {
    await (update(chapters)..where((c) => c.id.equals(chapterId))).write(
      ChaptersCompanion(
        isDownloaded: const Value(true),
        localPath: Value(localPath),
      ),
    );
    await (delete(downloadQueue)
          ..where((d) => d.chapterId.equals(chapterId)))
        .go();
  }

  // On failure: retries up to 3 times, then removes from queue.
  Future<void> markDownloadFailed(String chapterId) async {
    final row = await (select(downloadQueue)
          ..where((d) => d.chapterId.equals(chapterId)))
        .getSingleOrNull();
    if (row == null) return;
    if (row.retries >= 3) {
      await (delete(downloadQueue)
            ..where((d) => d.chapterId.equals(chapterId)))
          .go();
    } else {
      await (update(downloadQueue)
            ..where((d) => d.chapterId.equals(chapterId)))
          .write(DownloadQueueCompanion(
        status: const Value('queued'),
        retries: Value(row.retries + 1),
      ));
    }
  }

  // Watches the single most recently read chapter (for "Continue Reading").
  Stream<LastReadEntry?> watchLastRead() {
    final q = select(readingProgress).join([
      innerJoin(chapters, chapters.id.equalsExp(readingProgress.chapterId)),
      innerJoin(mangas, mangas.id.equalsExp(chapters.mangaId)),
    ])
      ..where(mangas.inLibrary.equals(true))
      ..orderBy([OrderingTerm.desc(readingProgress.updatedAt)])
      ..limit(1);

    return q.watchSingleOrNull().map((row) {
      if (row == null) return null;
      final prog = row.readTable(readingProgress);
      final ch = row.readTable(chapters);
      final m = row.readTable(mangas);
      return LastReadEntry(
        mangaId: m.id,
        mangaTitle: m.title,
        chapterId: ch.id,
        chapterTitle: ch.title,
        chapterNumber: ch.number,
        lastPage: prog.lastPage,
        pageCount: ch.pageCount,
      );
    });
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, 'sheep.db'));
    return NativeDatabase.createInBackground(file);
  });
}
