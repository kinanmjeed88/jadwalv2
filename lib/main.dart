import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/management/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '🚨 CRITICAL RENDER ERROR:\n\n${details.exceptionAsString()}\n\n${details.stack.toString()}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
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
      home: const HomePage(),
    );
  }
}
