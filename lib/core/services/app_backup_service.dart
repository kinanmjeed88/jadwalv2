import 'dart:convert';

import '../models/app_config.dart';
import 'app_config_service.dart';
import 'backup_service.dart';

/// نسخة احتياطية موحّدة: قاعدة بيانات Isar + ملف إعدادات التطبيق.
///
/// يبقى [BackupService] مسؤولًا عن قاعدة البيانات وحدها، وتضيف هذه الطبقة
/// مقطع `appConfig` الذي يحمل حالة الإعداد الأولي والمرحلة الدراسية وسجلّ
/// القيود التلقائية (المُدارة والمحذوفة)، حتى لا تفقد النسخ الاحتياطية شيئًا
/// من بيانات الميزة الجديدة.
///
/// التوافق الخلفي: النسخ القديمة التي لا تحتوي المقطع تُستورد كما هي دون
/// المساس بملف الإعدادات الحالي، لأن المقطع يُقرأ اختياريًا.
class AppBackupService {
  const AppBackupService({
    required BackupService databaseBackup,
    required AppConfigService appConfigService,
  })  : _databaseBackup = databaseBackup,
        _appConfigService = appConfigService;

  final BackupService _databaseBackup;
  final AppConfigService _appConfigService;

  /// مفتاح مقطع إعدادات التطبيق داخل ملف النسخة الاحتياطية.
  static const String appConfigKey = 'appConfig';

  /// يصدّر قاعدة البيانات وإعدادات التطبيق في مستند JSON واحد.
  Future<String> exportToJson() async {
    final databaseJson = await _databaseBackup.exportDatabaseToJson();
    final data = jsonDecode(databaseJson) as Map<String, dynamic>;
    final config = await _appConfigService.load();
    data[appConfigKey] = config.toJson();
    return jsonEncode(data);
  }

  /// يستورد نسخة أنشأها [exportToJson] أو نسخة قديمة من قاعدة البيانات وحدها.
  Future<void> importFromJson(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;
    final rawConfig = data.remove(appConfigKey);

    await _databaseBackup.importDatabaseFromJson(jsonEncode(data));

    if (rawConfig is Map) {
      await _appConfigService.save(
        AppConfig.fromJson(Map<String, dynamic>.from(rawConfig)),
      );
    }
  }
}
