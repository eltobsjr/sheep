import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';

final activeDownloadsProvider =
    StreamProvider.autoDispose<List<ActiveDownloadEntry>>((ref) =>
        ref.watch(databaseProvider).watchActiveDownloads());

final completedDownloadsProvider =
    StreamProvider.autoDispose<List<CompletedDownloadEntry>>((ref) =>
        ref.watch(databaseProvider).watchCompletedDownloads());

// Tracks whether the download queue is paused. Controlled by the UI.
final downloadPausedProvider = StateProvider<bool>((ref) => false);

// Total bytes used by downloaded manga on disk.
final downloadsDiskUsageProvider = FutureProvider.autoDispose<int>((ref) async {
  final completed = await ref.watch(completedDownloadsProvider.future);
  final docDir = await getApplicationDocumentsDirectory();
  int total = 0;
  for (final entry in completed) {
    final mangaDir = Directory('${docDir.path}/manga/${entry.mangaId}');
    if (!mangaDir.existsSync()) continue;
    for (final entity in mangaDir.listSync(recursive: true)) {
      if (entity is File) total += entity.lengthSync();
    }
  }
  return total;
});

// Cover path for a manga by ID, used by completed download items.
final downloadMangaCoverProvider =
    StreamProvider.autoDispose.family<String, String>(
  (ref, mangaId) => ref
      .watch(databaseProvider)
      .watchManga(mangaId)
      .map((m) => m?.coverPath ?? ''),
);
