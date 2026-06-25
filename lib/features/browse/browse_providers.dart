import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sources/manga_source.dart';
import '../../data/sources/source_registry.dart';
import '../../domain/models/manga.dart';

// Currently selected language filter in Browse: 'all', 'pt-br', 'en'
final selectedLanguageProvider =
    StateProvider<String>((ref) => 'all');

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

// Persistent ordered list of source IDs — reorderable via drag-and-drop.
class SourceOrderNotifier extends StateNotifier<List<String>> {
  static const _prefKey = 'browse_source_order';

  SourceOrderNotifier() : super(allSources.map((s) => s.id).toList()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefKey);
    if (saved == null) return;

    final currentIds = allSources.map((s) => s.id).toSet();
    // Preserve saved order for existing sources, append new ones at the end.
    final ordered = saved.where(currentIds.contains).toList();
    for (final s in allSources) {
      if (!ordered.contains(s.id)) ordered.add(s.id);
    }
    if (ordered.isNotEmpty) state = ordered;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, state);
  }
}

final sourceOrderProvider =
    StateNotifierProvider<SourceOrderNotifier, List<String>>(
  (ref) => SourceOrderNotifier(),
);
