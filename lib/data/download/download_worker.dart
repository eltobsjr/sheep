import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../db/app_database.dart';
import '../notifications/notification_service.dart';
import 'download_service.dart';

const kDownloadTaskName = 'sheep_download';

// Entry point for WorkManager background isolate.
// Must be a top-level function annotated with vm:entry-point.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    final db = AppDatabase();
    final notif = NotificationService.instance;
    await notif.init();

    try {
      final service = DownloadService(db);
      await service.processQueue(
        onChapterDone: (manga, chapter) =>
            notif.showDownloadComplete(manga, chapter),
        onChapterFailed: notif.showDownloadFailed,
      );
    } finally {
      await db.close();
    }
    return true;
  });
}
