import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver? get analyticsObserver {
    if (kIsWeb) return FirebaseAnalyticsObserver(analytics: _analytics);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  // دالة مخصصة لتسجيل الأحداث عند الحاجة
  Future<void> logCustomEvent(String name, Map<String, Object>? parameters) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
