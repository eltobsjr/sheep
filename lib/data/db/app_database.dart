import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) await m.createTable(sourceCredentials);
    },
  );

  // Watches all mangas that the user added to their library.
  Stream<List<Manga>> watchLibraryMangas() =>
      (select(mangas)..where((m) => m.inLibrary.equals(true))).watch();

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
