import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  late final FirebaseAnalytics? _analytics =
      (!_isDesktop) ? FirebaseAnalytics.instance : null;

  FirebaseAnalyticsObserver? get analyticsObserver {
    if (_isDesktop) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics!);
  }

  Future<void> logCustomEvent(
    String name,
    Map<String, Object>? parameters,
  ) async {
    if (_isDesktop) return;
    await _analytics?.logEvent(name: name, parameters: parameters);
  }
}
