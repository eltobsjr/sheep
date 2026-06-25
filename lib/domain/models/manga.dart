enum MangaStatus { ongoing, completed, hiatus, cancelled, unknown }

class MangaSummary {
  const MangaSummary({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.coverUrl,
    this.author = '',
    String? url,
  }) : url = url ?? id;
  final String id;
  final String sourceId;
  final String title;
  final String coverUrl;
  final String author;
  // URL or ID used as argument to MangaSource.getDetails() / getChapters().
  final String url;
}

class MangaDetails {
  const MangaDetails({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.synopsis,
    required this.status,
    required this.authors,
    this.genres = const [],
  });
  final String id;
  final String title;
  final String coverUrl;
  final String synopsis;
  final MangaStatus status;
  final List<String> authors;
  final List<String> genres;
}

class Manga {
  const Manga({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.coverPath,
    required this.status,
    required this.inLibrary,
  });
  final String id;
  final String sourceId;
  final String title;
  final String coverPath;
  final MangaStatus status;
  final bool inLibrary;
}
