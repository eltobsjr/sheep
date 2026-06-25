import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/manga_source.dart';
import '../../data/sources/source_registry.dart';
import '../../domain/models/manga.dart';

// Currently selected source ID in Browse.
final selectedSourceIdProvider =
    StateProvider<String>((ref) => allSources.first.id);

// Popular mangas from the selected source.
final popularProvider =
    FutureProvider.autoDispose<List<MangaSummary>>((ref) async {
  final sourceId = ref.watch(selectedSourceIdProvider);
  final source = sourceById(sourceId);
  if (source == null) return const [];
  return source.getPopular(1);
});

// Recently updated mangas from the selected source.
final latestProvider =
    FutureProvider.autoDispose<List<MangaSummary>>((ref) async {
  final sourceId = ref.watch(selectedSourceIdProvider);
  final source = sourceById(sourceId);
  if (source == null) return const [];
  return source.getLatest(1);
});

// Search results — used by SearchScreen.
// Returns empty until query is non-empty.
final searchQueryProvider = StateProvider<String>((ref) => '');
final searchSourceIdProvider = StateProvider<String?>((ref) => null); // null = all

final searchResultsProvider =
    FutureProvider.autoDispose<List<MangaSummary>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const [];

  final sourceId = ref.watch(searchSourceIdProvider);

  if (sourceId != null) {
    // Single source search
    final source = sourceById(sourceId);
    if (source == null) return const [];
    return source.search(query, 1);
  }

  // All sources — run in parallel, collect results
  final futures = allSources.map((s) => s.search(query, 1).catchError((_) => <MangaSummary>[]));
  final results = await Future.wait(futures);
  return results.expand((r) => r).toList();
});

// All sources for display in chips.
List<MangaSource> get browseSources => allSources;
