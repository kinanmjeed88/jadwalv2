import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../../core/models/app_config.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/subject_constraint_key.dart';
import '../../../../core/providers/app_config_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../data/services/subject_constraint_auto_sync_service.dart';

/// متحكّم مزامنة قيود المواد التلقائية (سياسة المرحلة الابتدائية).
///
/// يعمل على ثلاث جبهات:
/// * مزامنة أولية عند إقلاع التطبيق.
/// * مراقبة مجموعات المواد والصفوف والحصص والإعدادات، وإعادة المزامنة بعد
///   أي تغيير (بتأخير قصير يمنع تكرار العمل في العملية نفسها).
/// * تسجيل قرارات المستخدم (حذف قيد أو تعديله) حتى تحترمها المزامنة.
///
/// يعتمد الصنف على دوال مُمرَّرة بدل الوصول المباشر إلى حاوية Riverpod، ما
/// يجعله قابلًا للاختبار ومستقلًا عن إصدارات Riverpod.
final subjectConstraintAutoSyncProvider =
    Provider<SubjectConstraintAutoSyncController>((ref) {
  final controller = SubjectConstraintAutoSyncController(
    readIsar: () => ref.read(isarDatabaseProvider.future),
    readConfig: () => ref.read(appConfigNotifierProvider.future),
    replaceConfig: (config) =>
        ref.read(appConfigNotifierProvider.notifier).replace(config),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

class SubjectConstraintAutoSyncController {
  SubjectConstraintAutoSyncController({
    required Future<Isar> Function() readIsar,
    required Future<AppConfig> Function() readConfig,
    required Future<void> Function(AppConfig config) replaceConfig,
  })  : _readIsar = readIsar,
        _readConfig = readConfig,
        _replaceConfig = replaceConfig;

  final Future<Isar> Function() _readIsar;
  final Future<AppConfig> Function() _readConfig;
  final Future<void> Function(AppConfig config) _replaceConfig;

  /// تأخير بسيط لدمج التغييرات المتتابعة في مزامنة واحدة.
  static const Duration _debounceDuration = Duration(milliseconds: 600);

  final List<StreamSubscription<void>> _subscriptions = [];
  Timer? _debounceTimer;
  bool _watchersStarted = false;
  bool _runInProgress = false;
  bool _runQueued = false;
  bool _disposed = false;

  /// يبدأ المراقبة ويُزامن مرة واحدة عند الإقلاع.
  Future<void> start() async {
    if (_disposed) {
      return;
    }

    await _startWatchers();
    await run();
  }

  Future<void> _startWatchers() async {
    if (_watchersStarted || _disposed) {
      return;
    }

    final isar = await _readIsar();
    if (_disposed) {
      return;
    }

    _watchersStarted = true;
    _subscriptions.addAll(<StreamSubscription<void>>[
      isar.subjects.watchLazy().listen((_) => _scheduleSync()),
      isar.classrooms.watchLazy().listen((_) => _scheduleSync()),
      isar.lessons.watchLazy().listen((_) => _scheduleSync()),
      isar.appSettings.watchLazy().listen((_) => _scheduleSync()),
    ]);
  }

  /// ينفّذ مزامنة فورية ويعيد نتيجتها (أو `null` إذا فشلت أو تخطّت).
  Future<AutoConstraintSyncOutcome?> run() async {
    if (_disposed) {
      return null;
    }

    if (_runInProgress) {
      _runQueued = true;
      return null;
    }

    _runInProgress = true;
    try {
      final isar = await _readIsar();
      final config = await _readConfig();
      final service = SubjectConstraintAutoSyncService(isar);
      final outcome = await service.synchronize(config);

      if (outcome.configChanged) {
        await _replaceConfig(outcome.config);
      }

      return outcome;
    } catch (error, stackTrace) {
      debugPrint('SubjectConstraintAutoSync failed: $error\n$stackTrace');
      return null;
    } finally {
      _runInProgress = false;
      if (_runQueued && !_disposed) {
        _runQueued = false;
        _scheduleSync();
      }
    }
  }

  /// يسجّل أن المستخدم حذف قيدًا بنفسه، فلا يُعاد إنشاؤه تلقائيًا.
  ///
  /// يُسجَّل الحذف فقط في المرحلة الابتدائية؛ ففي المراحل الأخرى لا تُنشئ
  /// المزامنة أي قيود أصلًا.
  Future<void> recordManualDeletion(SubjectConstraintKey key) async {
    if (_disposed) {
      return;
    }

    final config = await _readConfig();
    if (!config.schoolStage.enablesAutomaticConstraintBypass) {
      return;
    }

    final managed = Map<String, int>.from(config.managedAutoConstraints)
      ..remove(key.storageKey);
    final dismissed = Set<String>.from(config.dismissedAutoConstraints)
      ..add(key.storageKey);

    await _replaceConfig(
      config.copyWith(
        managedAutoConstraints: managed,
        dismissedAutoConstraints: dismissed,
      ),
    );
  }

  /// يسجّل أن المستخدم أنشأ أو عدّل قيدًا يدويًا، فيتوقف النظام عن إدارته.
  Future<void> recordManualDefinition(SubjectConstraintKey key) async {
    if (_disposed) {
      return;
    }

    final config = await _readConfig();
    if (!config.managedAutoConstraints.containsKey(key.storageKey) &&
        !config.dismissedAutoConstraints.contains(key.storageKey)) {
      return;
    }

    final managed = Map<String, int>.from(config.managedAutoConstraints)
      ..remove(key.storageKey);
    final dismissed = Set<String>.from(config.dismissedAutoConstraints)
      ..remove(key.storageKey);

    await _replaceConfig(
      config.copyWith(
        managedAutoConstraints: managed,
        dismissedAutoConstraints: dismissed,
      ),
    );
  }

  void _scheduleSync() {
    if (_disposed) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(run());
    });
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
