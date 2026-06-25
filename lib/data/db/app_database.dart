import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

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
  final int progress;
  final String status;
}

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

class LastReadEntry {
  const LastReadEntry({
    required this.mangaId,
    required this.mangaTitle,
    required this.coverPath,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.lastPage,
    this.pageCount,
  });

  final String mangaId;
  final String mangaTitle;
  final String coverPath;
  final String chapterId;
  final String chapterTitle;
  final double chapterNumber;
  final int lastPage;
  final int? pageCount;

  double get progress =>
      (pageCount != null && pageCount! > 0) ? lastPage / pageCount! : 0.0;
  int get progressPercent => (progress * 100).clamp(0, 100).round();
}

class MangaProgressEntry {
  const MangaProgressEntry({
    required this.mangaId,
    required this.readCount,
    required this.totalCount,
  });

  final String mangaId;
  final int readCount;
  final int totalCount;

  double get ratio => totalCount > 0 ? readCount / totalCount : 0.0;
}

@DriftDatabase(tables: [Mangas, Chapters, ReadingProgress, DownloadQueue, SourceCredentials])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

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
      if (from < 4) {
        await m.addColumn(readingProgress, readingProgress.isRead);
      }
    },
  );

  Stream<List<Manga>> watchLibraryMangas() =>
      (select(mangas)..where((m) => m.inLibrary.equals(true))).watch();

  Stream<Manga?> watchManga(String mangaId) =>
      (select(mangas)..where((m) => m.id.equals(mangaId)))
          .watchSingleOrNull();

  Stream<List<Chapter>> watchChapters(String mangaId) =>
      (select(chapters)
            ..where((c) => c.mangaId.equals(mangaId))
            ..orderBy([(c) => OrderingTerm.desc(c.number)]))
          .watch();

  Future<void> toggleLibrary(String mangaId, {required bool inLibrary}) =>
      (update(mangas)..where((m) => m.id.equals(mangaId)))
          .write(MangasCompanion(inLibrary: Value(inLibrary)));

  Future<void> upsertManga(MangasCompanion row) =>
      into(mangas).insertOnConflictUpdate(row);

  Future<void> upsertChapters(List<ChaptersCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(chapters, rows));
  }

  Stream<Chapter?> watchChapterById(String chapterId) =>
      (select(chapters)..where((c) => c.id.equals(chapterId)))
          .watchSingleOrNull();

  Future<ReadingProgressData?> getReadingProgress(String chapterId) =>
      (select(readingProgress)..where((r) => r.chapterId.equals(chapterId)))
          .getSingleOrNull();

  Future<void> saveReadingProgress({
    required String chapterId,
    required int lastPage,
    int? pageCount,
  }) async {
    if (pageCount != null) {
      await (update(chapters)..where((c) => c.id.equals(chapterId)))
          .write(ChaptersCompanion(pageCount: Value(pageCount)));
    }
    final autoRead = pageCount != null && lastPage >= pageCount;
    await into(readingProgress).insertOnConflictUpdate(
      ReadingProgressCompanion(
        chapterId: Value(chapterId),
        lastPage: Value(lastPage),
        updatedAt: Value(DateTime.now()),
        isRead: autoRead ? const Value(true) : const Value.absent(),
      ),
    );
  }

  Future<void> markChapterRead(String chapterId, {required bool isRead}) async {
    final existing = await getReadingProgress(chapterId);
    if (existing != null) {
      await (update(readingProgress)
            ..where((r) => r.chapterId.equals(chapterId)))
          .write(ReadingProgressCompanion(
            isRead: Value(isRead),
            updatedAt: Value(DateTime.now()),
          ));
    } else {
      await into(readingProgress).insert(ReadingProgressCompanion(
        chapterId: Value(chapterId),
        lastPage: const Value(1),
        updatedAt: Value(DateTime.now()),
        isRead: Value(isRead),
      ));
    }
  }

  Stream<Map<String, bool>> watchChapterReadMap(String mangaId) {
    final q = select(readingProgress).join([
      innerJoin(chapters, chapters.id.equalsExp(readingProgress.chapterId)),
    ])..where(chapters.mangaId.equals(mangaId));

    return q.watch().map((rows) => {
          for (final row in rows)
            row.readTable(readingProgress).chapterId:
                row.readTable(readingProgress).isRead,
        });
  }

  Stream<List<MangaProgressEntry>> watchLibraryProgress() {
    return customSelect(
      '''
      SELECT m.id AS manga_id,
             COUNT(c.id) AS total,
             COALESCE(SUM(CASE WHEN rp.is_read = 1 THEN 1 ELSE 0 END), 0) AS read_count
      FROM mangas m
      LEFT JOIN chapters c ON c.manga_id = m.id
      LEFT JOIN reading_progress rp ON rp.chapter_id = c.id
      WHERE m.in_library = 1
      GROUP BY m.id
      ''',
      readsFrom: {mangas, chapters, readingProgress},
    ).watch().map(
          (rows) => rows
              .map((row) => MangaProgressEntry(
                    mangaId: row.read<String>('manga_id'),
                    readCount: row.read<int>('read_count'),
                    totalCount: row.read<int>('total'),
                  ))
              .toList(),
        );
  }

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

  Future<void> queueDownload(String chapterId) async {
    final existing = await (select(downloadQueue)
          ..where((d) => d.chapterId.equals(chapterId)))
        .getSingleOrNull();
    if (existing != null) return;
    await into(downloadQueue).insert(
      DownloadQueueCompanion.insert(chapterId: chapterId, status: 'queued'),
    );
  }

  Future<DownloadQueueData?> nextQueuedDownload() =>
      (select(downloadQueue)
            ..where((d) => d.status.equals('queued'))
            ..limit(1))
          .getSingleOrNull();

  Stream<DownloadQueueData?> watchDownloadEntry(String chapterId) =>
      (select(downloadQueue)..where((d) => d.chapterId.equals(chapterId)))
          .watchSingleOrNull();

  Future<void> updateDownloadProgress(String chapterId, int progress) =>
      (update(downloadQueue)..where((d) => d.chapterId.equals(chapterId)))
          .write(DownloadQueueCompanion(progress: Value(progress)));

  Future<void> setDownloadStatus(String chapterId, String status) =>
      (update(downloadQueue)..where((d) => d.chapterId.equals(chapterId)))
          .write(DownloadQueueCompanion(status: Value(status)));

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

  Future<void> cancelDownload(String chapterId) =>
      (delete(downloadQueue)..where((d) => d.chapterId.equals(chapterId))).go();

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

  Stream<LastReadEntry?> watchLastRead() => watchRecentlyRead(limit: 1)
      .map((list) => list.isEmpty ? null : list.first);

  // Returns the most recently read chapter per manga for the given limit,
  // ordered by last-read time descending. One entry per manga (latest chapter).
  Stream<List<LastReadEntry>> watchRecentlyRead({int limit = 8}) {
    return customSelect(
      '''
      SELECT rp.chapter_id, rp.last_page,
             ch.title AS ch_title, ch.number AS ch_number, ch.page_count,
             m.id AS manga_id, m.title AS manga_title, m.cover_path
      FROM reading_progress rp
      INNER JOIN chapters ch ON ch.id = rp.chapter_id
      INNER JOIN mangas m ON m.id = ch.manga_id
      WHERE m.in_library = 1
        AND rp.updated_at = (
          SELECT MAX(rp2.updated_at)
          FROM reading_progress rp2
          INNER JOIN chapters ch2 ON ch2.id = rp2.chapter_id
          WHERE ch2.manga_id = m.id
        )
      ORDER BY rp.updated_at DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {readingProgress, chapters, mangas},
    ).watch().map((rows) => rows
        .map((row) => LastReadEntry(
              mangaId: row.read<String>('manga_id'),
              mangaTitle: row.read<String>('manga_title'),
              coverPath: row.read<String>('cover_path'),
              chapterId: row.read<String>('chapter_id'),
              chapterTitle: row.read<String>('ch_title'),
              chapterNumber: row.read<double>('ch_number'),
              lastPage: row.read<int>('last_page'),
              pageCount: row.readNullable<int>('page_count'),
            ))
        .toList());
  }

  Future<void> resetStuckDownloads() async {
    await (update(downloadQueue)
          ..where((d) => d.status.equals('downloading')))
        .write(const DownloadQueueCompanion(status: Value('queued')));
  }

  // ── Source Credentials ────────────────────────────────────────────────────

  Future<SourceCredential?> getCredentials(String sourceId) =>
      (select(sourceCredentials)
            ..where((c) => c.sourceId.equals(sourceId)))
          .getSingleOrNull();

  Stream<SourceCredential?> watchCredentials(String sourceId) =>
      (select(sourceCredentials)
            ..where((c) => c.sourceId.equals(sourceId)))
          .watchSingleOrNull();

  Future<void> saveCredentials({
    required String sourceId,
    required String? username,
    required String? password,
    String? extraJson,
  }) =>
      into(sourceCredentials).insertOnConflictUpdate(
        SourceCredentialsCompanion.insert(
          sourceId: sourceId,
          username: Value(username),
          password: Value(password),
          extraJson: Value(extraJson),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> clearCredentials(String sourceId) =>
      (delete(sourceCredentials)
            ..where((c) => c.sourceId.equals(sourceId)))
          .go();
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, 'sheep.db'));
    return NativeDatabase.createInBackground(file);
  });
}
