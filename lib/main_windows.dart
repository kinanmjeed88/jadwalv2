import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_bootstrap.dart';
import 'app/jadwal_windows_app.dart';
import 'services/desktop_error_log_service.dart';
import 'services/desktop_window_state_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  final desktopErrorLogService = await DesktopErrorLogService.initialize();
  final desktopWindowStateService =
      await DesktopWindowStateService.initialize();

  const windowOptions = WindowOptions(
    size: Size(1280, 768),
    minimumSize: Size(1024, 768),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'جدول الدروس الأسبوعي - Windows 10 و11',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await desktopWindowStateService.restore();
    await windowManager.show();
    await windowManager.focus();
  });

  installErrorHandlers(
    onError: desktopErrorLogService.record,
  );
  runJadwalWindowsApp();
}
