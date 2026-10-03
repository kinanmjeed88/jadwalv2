import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_config.dart';

/// قراءة وكتابة ملف إعدادات التطبيق بصيغة JSON.
///
/// يضمن الصنف:
/// * إنشاء المجلد تلقائيًا عند الحاجة.
/// * كتابة ذرّية (ملف مؤقت ثم إعادة تسمية) حتى لا يتلف الملف إذا أُغلق
///   التطبيق أثناء الحفظ.
/// * التسامح مع الملفات التالفة أو الناقصة بالرجوع إلى القيم الافتراضية
///   بدل إسقاط التطبيق.
class AppConfigService {
  AppConfigService({required this.file});

  /// مسار ملف الإعدادات.
  final File file;

  /// اسم الملف داخل مجلد مستندات التطبيق.
  static const String fileName = 'jadwal_app_config.json';

  /// امتداد الملف المؤقت المستخدم في الكتابة الذرّية.
  static const String temporaryExtension = '.tmp';

  /// يقرأ الإعدادات، ويعيد [AppConfig.initial] عند غياب الملف أو تلفه.
  Future<AppConfig> load() async {
    try {
      if (!await file.exists()) {
        return AppConfig.initial();
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return AppConfig.initial();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('AppConfig: unexpected JSON root, using defaults.');
        return AppConfig.initial();
      }

      return AppConfig.fromJson(decoded);
    } catch (error) {
      debugPrint('AppConfig: failed to read config file: $error');
      return AppConfig.initial();
    }
  }

  /// يحفظ الإعدادات كتابةً ذرّية.
  Future<void> save(AppConfig config) async {
    final temporaryFile = File('${file.path}$temporaryExtension');

    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await temporaryFile
        .writeAsString(jsonEncode(config.toJson()), flush: true);

    // على ويندوز يفشل إعادة التسمية فوق ملف قائم، فنُزيل الهدف أولًا.
    if (await file.exists()) {
      await file.delete();
    }
    await temporaryFile.rename(file.path);
  }
}
