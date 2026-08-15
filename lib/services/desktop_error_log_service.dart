import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DesktopErrorLogService {
  DesktopErrorLogService._(this._logFile);

  final File _logFile;

  static Future<DesktopErrorLogService> initialize() async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final service = DesktopErrorLogService._(
      File('${appSupportDirectory.path}${Platform.pathSeparator}errors.log'),
    );
    await service._logFile.parent.create(recursive: true);
    return service;
  }

  void record(Object error, StackTrace? stackTrace) {
    unawaited(_append(error, stackTrace));
  }

  Future<void> _append(Object error, StackTrace? stackTrace) async {
    try {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final stack = stackTrace?.toString() ?? 'No stack trace';
      await _logFile.writeAsString(
        '[$timestamp] $error\n$stack\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging must never become a source of application failures.
    }
  }
}
