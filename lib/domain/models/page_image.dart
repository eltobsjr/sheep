import 'dart:io';

sealed class PageImage {
  const PageImage();
}

final class NetworkPageImage extends PageImage {
  const NetworkPageImage(this.url);
  final String url;
}

final class FilePageImage extends PageImage {
  const FilePageImage(this.file);
  final File file;
}
