import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_provider.dart';
import 'download_service.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.read(databaseProvider));
});
