import 'dart:io';

import '../data/sources/manga_source.dart';
import 'models/page_image.dart';

abstract class PageSource {
  Future<List<PageImage>> getPages();
}

class RemotePageSource implements PageSource {
  const RemotePageSource(this.source, this.chapterUrl);
  final MangaSource source;
  final String chapterUrl;

  @override
  Future<List<PageImage>> getPages() async {
    final urls = await source.getPages(chapterUrl);
    return urls.map(NetworkPageImage.new).toList();
  }
}

class LocalPageSource implements PageSource {
  const LocalPageSource(this.chapterFolder);
  final Directory chapterFolder;

  @override
  Future<List<PageImage>> getPages() async {
    final entities = await chapterFolder.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files.map(FilePageImage.new).toList();
  }
}
