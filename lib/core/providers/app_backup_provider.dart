import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_backup_service.dart';
import 'app_config_provider.dart';
import 'repository_provider.dart';

/// خدمة النسخ الاحتياطي الموحّدة (قاعدة البيانات + إعدادات التطبيق).
///
/// مكتوبة يدويًا بلا توليد، انسجامًا مع مزوّدات الإعداد الأولي في
/// `app_config_provider.dart`، ولأن توليد المزوّدات يتطلب build_runner.
final appBackupServiceProvider = FutureProvider<AppBackupService>((ref) async {
  final databaseBackup = await ref.watch(backupServiceProvider.future);
  final appConfigService = await ref.watch(appConfigServiceProvider.future);
  return AppBackupService(
    databaseBackup: databaseBackup,
    appConfigService: appConfigService,
  );
});
