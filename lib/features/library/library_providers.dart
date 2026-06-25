import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';

final libraryMangasProvider = StreamProvider<List<Manga>>((ref) {
  return ref.watch(databaseProvider).watchLibraryMangas();
});

final lastReadProvider = StreamProvider<LastReadEntry?>((ref) {
  return ref.watch(databaseProvider).watchLastRead();
});
