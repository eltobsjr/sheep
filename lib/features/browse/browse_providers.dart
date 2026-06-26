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
  if (source == null || source.requiresJavaScript) return const [];
  return source.getPopular(1);
});

// Recently updated mangas from the selected source.
final latestProvider =
    FutureProvider.autoDispose<List<MangaSummary>>((ref) async {
  final sourceId = ref.watch(selectedSourceIdProvider);
  final source = sourceById(sourceId);
  if (source == null || source.requiresJavaScript) return const [];
  return source.getLatest(1);
});

// Search results — used by SearchScreen.
// Returns empty until query is non-empty.
final searchQueryProvider = StateProvider<String>((ref) => '');
final searchSourceIdProvider = StateProvider<String?>((ref) => null); // null = all

// Single-source search result list.
final searchResultsProvider =
    FutureProvider.autoDispose<List<MangaSummary>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const [];
  final sourceId = ref.watch(searchSourceIdProvider);
  if (sourceId == null) return const [];
  final source = sourceById(sourceId);
  if (source == null) return const [];
  return source.search(query, 1);
});

// Per-source result bucket for "All sources" mode.
class SourceSearchResult {
  const SourceSearchResult({
    required this.source,
    required this.items,
    this.error,
  });

  final MangaSource source;
  final List<MangaSummary> items;
  final Object? error;

  bool get hasError => error != null;
}

// All-sources search — runs each source in parallel, returns grouped results.
// Successful sources come first (sorted by order), then failed ones at the end.
final allSourcesResultsProvider =
    FutureProvider.autoDispose<List<SourceSearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const [];

  final futures = allSources.map((s) async {
    try {
      final items = await s.search(query, 1);
      return SourceSearchResult(source: s, items: items);
    } catch (e) {
      // Web sources failing (e.g. CF not yet solved) show no error — just 0 results.
      if (s.requiresJavaScript) return SourceSearchResult(source: s, items: const []);
      return SourceSearchResult(source: s, items: const [], error: e);
    }
  });

  final results = await Future.wait(futures);
  final ok = results.where((r) => !r.hasError && r.items.isNotEmpty).toList();
  final empty = results.where((r) => !r.hasError && r.items.isEmpty).toList();
  final failed = results.where((r) => r.hasError).toList();
  return [...ok, ...empty, ...failed];
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
