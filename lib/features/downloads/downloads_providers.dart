import 'package:flutter_riverpod/flutter_riverpod.dart';

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
