import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_config.dart';
import '../models/school_stage.dart';
import '../services/app_config_service.dart';
import 'database_provider.dart';

/// خدمة ملف إعدادات التطبيق (تُهيَّأ مرة واحدة لكل تشغيل).
final appConfigServiceProvider = FutureProvider<AppConfigService>((ref) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(
    '${directory.path}${Platform.pathSeparator}${AppConfigService.fileName}',
  );
  return AppConfigService(file: file);
});

/// حالة إعدادات التطبيق (هل أُكمل الإعداد الأولي؟ وما المرحلة الدراسية؟).
final appConfigNotifierProvider =
    AsyncNotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);

/// حالة الإعداد الأولي كما تراها واجهة الإقلاع.
enum AppSetupStatus {
  /// مستخدم جديد: يجب إكمال البيانات الإلزامية والمرحلة قبل استخدام التطبيق.
  needsSetup,

  /// توجد بيانات سابقة (ترقية من نسخة أقدم): نُكمل الإعداد تلقائيًا دون
  /// مقاطعة المستخدم، وبقيت المرحلة قابلة للتغيير من الإعدادات.
  legacyDataDetected,

  /// الإعداد الأولي مكتمل.
  completed,
}

/// يقرأ حالة الإعداد الأولي دون أي آثار جانبية.
///
/// إذا لم يكن الإعداد مكتملًا لكن قاعدة البيانات تحتوي بيانات (مستخدم قديم)،
/// تُعاد [AppSetupStatus.legacyDataDetected] ليتولّى واجهة الإقلاع اعتماد
/// الإعداد بصمت.
final appSetupStatusProvider = FutureProvider<AppSetupStatus>((ref) async {
  final config = await ref.watch(appConfigNotifierProvider.future);
  if (config.isSetupCompleted) {
    return AppSetupStatus.completed;
  }

  final isar = await ref.watch(isarDatabaseProvider.future);
  final teachers = await isar.teachers.count();
  final subjects = await isar.subjects.count();
  final classrooms = await isar.classrooms.count();
  final lessons = await isar.lessons.count();

  final hasExistingData =
      teachers > 0 || subjects > 0 || classrooms > 0 || lessons > 0;
  return hasExistingData
      ? AppSetupStatus.legacyDataDetected
      : AppSetupStatus.needsSetup;
});

/// يقرأ ويحفظ [AppConfig] ويثبّت آخر قيمة في حالة Riverpod.
class AppConfigNotifier extends AsyncNotifier<AppConfig> {
  @override
  Future<AppConfig> build() async {
    final service = await ref.watch(appConfigServiceProvider.future);
    return service.load();
  }

  /// يُنهي الإعداد الأولي ويثبّت المرحلة المختارة.
  Future<void> completeSetup({required SchoolStage stage}) {
    return _update(
      (config) => config.copyWith(
        isSetupCompleted: true,
        schoolStage: stage,
      ),
    );
  }

  /// يعتمد إعدادًا صامتًا لمستخدم قائم (ترقية) بمرحلة لا تغيّر سلوك الجدول.
  Future<void> adoptLegacySetup() {
    return completeSetup(stage: SchoolStage.fallback);
  }

  /// يستبدل الإعدادات الحالية بالكامل (تستخدمه المزامنة التلقائية).
  Future<void> replace(AppConfig config) async {
    if (state.valueOrNull == config) {
      return;
    }
    await _persist(config);
  }

  Future<void> _update(AppConfig Function(AppConfig config) transform) async {
    final current = state.valueOrNull ?? await _loadFromDisk();
    await _persist(transform(current));
  }

  Future<AppConfig> _loadFromDisk() async {
    final service = await ref.read(appConfigServiceProvider.future);
    return service.load();
  }

  Future<void> _persist(AppConfig config) async {
    final service = await ref.read(appConfigServiceProvider.future);
    await service.save(config);
    state = AsyncData(config);
  }
}
