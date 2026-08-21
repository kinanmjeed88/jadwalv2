import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/management/presentation/pages/home_page.dart';
import 'services/analytics_service.dart';
import 'services/desktop_error_log_service.dart';
import 'services/desktop_window_state_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  DesktopErrorLogService? desktopErrorLogService;

  if (isDesktop) {
    await windowManager.ensureInitialized();
    desktopErrorLogService = await DesktopErrorLogService.initialize();
    final desktopWindowStateService =
        await DesktopWindowStateService.initialize();
    const windowOptions = WindowOptions(
      size: Size(1280, 768),
      minimumSize: Size(1024, 768), // منع التصغير المشوه للجدول
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'جدول الدروس الأسبوعي',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await desktopWindowStateService.restore();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  try {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // التعامل مع أخطاء التهيئة بشكل نظيف دون تعطيل التطبيق
    debugPrint('Firebase initialization failed: $e');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (isDesktop) {
      desktopErrorLogService?.record(details.exception, details.stack);
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '🚨 CRITICAL RENDER ERROR:\n\n${details.exceptionAsString()}\n\n${details.stack.toString()}',
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: JadwalApp()));
}

class JadwalApp extends StatelessWidget {
  const JadwalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جدول',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'), // Arabic
      ],
      navigatorObservers: [
        if (AnalyticsService().analyticsObserver != null)
          AnalyticsService().analyticsObserver!,
      ],
      home: const HomePage(),
    );
  }
}
