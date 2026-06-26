import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';

final libraryMangasProvider = StreamProvider.autoDispose<List<Manga>>((ref) {
  return ref.watch(databaseProvider).watchLibraryMangas();
});

final lastReadProvider = StreamProvider.autoDispose<LastReadEntry?>((ref) {
  return ref.watch(databaseProvider).watchLastRead();
});

final recentlyReadProvider = StreamProvider.autoDispose<List<LastReadEntry>>((ref) {
  return ref.watch(databaseProvider).watchRecentlyRead();
});

final libraryProgressProvider =
    StreamProvider.autoDispose<Map<String, MangaProgressEntry>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchLibraryProgress()
      .map((list) => {for (final e in list) e.mangaId: e});
});
