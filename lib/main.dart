import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app_bootstrap.dart';
import 'app/jadwal_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // نقطة الدخول هذه مخصصة للـAPK والويب. لا تستورد أي خدمة خاصة بسطح المكتب.
  final isMobileOrWeb =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.fuchsia;

  if (isMobileOrWeb) {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      // فشل Firebase لا يجب أن يمنع تشغيل تطبيق الهاتف.
      debugPrint('Firebase initialization failed: $error');
    }
  }

  installErrorHandlers();
  runJadwalApp();
}
