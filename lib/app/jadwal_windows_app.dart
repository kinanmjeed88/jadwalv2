import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/management/presentation/pages/home_page.dart';

void runJadwalWindowsApp() {
  runApp(const ProviderScope(child: JadwalWindowsApp()));
}

class JadwalWindowsApp extends StatelessWidget {
  const JadwalWindowsApp({super.key});

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
        Locale('ar', 'AE'),
      ],
      home: const HomePage(),
    );
  }
}
