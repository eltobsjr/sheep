class ChapterSummary {
  const ChapterSummary({
    required this.id,
    required this.title,
    required this.number,
    required this.url,
  });
  final String id;
  final String title;
  final double number;
  final String url;
}

class Chapter {
  const Chapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.number,
    required this.url,
    required this.isDownloaded,
    this.localPath,
    this.pageCount,
  });
  final String id;
  final String mangaId;
  final String title;
  final double number;
  final String url;
  final bool isDownloaded;
  final String? localPath;
  final int? pageCount;
}
