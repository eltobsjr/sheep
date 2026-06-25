import 'package:drift/drift.dart';

class Mangas extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId => text()();
  TextColumn get title => text()();
  TextColumn get coverPath => text()();
  TextColumn get status => text()();
  BoolColumn get inLibrary =>
      boolean().withDefault(const Constant(false))();

  @override
  // ignore: strict_raw_types
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get mangaId => text().references(Mangas, #id)();
  TextColumn get title => text()();
  RealColumn get number => real()();
  TextColumn get url => text()();
  BoolColumn get isDownloaded =>
      boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();
  IntColumn get pageCount => integer().nullable()();

  @override
  // ignore: strict_raw_types
  Set<Column> get primaryKey => {id};
}

class ReadingProgress extends Table {
  TextColumn get chapterId => text().references(Chapters, #id)();
  IntColumn get lastPage => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  // ignore: strict_raw_types
  Set<Column> get primaryKey => {chapterId};
}

class DownloadQueue extends Table {
  TextColumn get chapterId => text()();
  TextColumn get status => text()();
  IntColumn get progress =>
      integer().withDefault(const Constant(0))();
  IntColumn get retries =>
      integer().withDefault(const Constant(0))();
}
