import 'package:flutter/foundation.dart';

import 'school_stage.dart';

/// إعدادات المنصة العامة التي تُخزَّن في ملف JSON مستقل عن قاعدة البيانات.
///
/// لماذا ملف مستقل بدل مجموعة Isar جديدة؟
/// * هذه بيانات وصفية (أول تشغيل، المرحلة، سجلّ القيود التوليدية) ولا حاجة
///   لاستعلامها أو فرزها داخل قاعدة البيانات.
/// * تفاديًا لأي هجرة مخطط (schema migration) على بيانات المستخدمين
///   الحاليين، خصوصًا أن قيود المواد نفسها تبقى في Isar وتُقرأ كما هي.
///
/// الملف مقروء للتوسعة مستقبلًا عبر [schemaVersion]، وأي قيمة غير معروفة
/// تُترجم إلى الافتراضي بدل أن تُعطّل التطبيق.
class AppConfig {
  const AppConfig({
    required this.isSetupCompleted,
    required this.schoolStage,
    required this.managedAutoConstraints,
    required this.dismissedAutoConstraints,
  });

  /// الحالة الافتراضية: لم يُكمل المستخدم الإعداد الأولي بعد.
  factory AppConfig.initial() {
    return const AppConfig(
      isSetupCompleted: false,
      schoolStage: SchoolStage.fallback,
      managedAutoConstraints: <String, int>{},
      dismissedAutoConstraints: <String>{},
    );
  }

  /// صيغة التخزين الحالية؛ تُستخدم لتمييز الملفات القديمة عند التوسعة.
  static const int currentSchemaVersion = 1;

  static const String _setupKey = 'isSetupCompleted';
  static const String _stageKey = 'schoolStage';
  static const String _managedKey = 'managedAutoConstraints';
  static const String _dismissedKey = 'dismissedAutoConstraints';
  static const String _versionKey = 'schemaVersion';

  /// هل أتمّ المستخدم الإعداد الأولي (البيانات الإلزامية + المرحلة)؟
  final bool isSetupCompleted;

  /// المرحلة الدراسية المختارة.
  final SchoolStage schoolStage;

  /// القيود التي أنشأها نظام المزامنة التلقائي للمرحلة الابتدائية.
  /// المفتاح هو [SubjectConstraintKey.storageKey] والقيمة هي الحد اليومي
  /// الذي كتبته المزامنة، فإذا تغيّرت القيمة يدويًا يُعتبر القيد ملكًا
  /// للمستخدم وتتوقف المزامنة عن إدارته.
  final Map<String, int> managedAutoConstraints;

  /// مفاتيح حذفها المستخدم صراحةً فلا تُعاد تلقائيًا ما دامت مؤهلة.
  final Set<String> dismissedAutoConstraints;

  int get schemaVersion => currentSchemaVersion;

  AppConfig copyWith({
    bool? isSetupCompleted,
    SchoolStage? schoolStage,
    Map<String, int>? managedAutoConstraints,
    Set<String>? dismissedAutoConstraints,
  }) {
    return AppConfig(
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
      schoolStage: schoolStage ?? this.schoolStage,
      managedAutoConstraints:
          managedAutoConstraints ?? this.managedAutoConstraints,
      dismissedAutoConstraints:
          dismissedAutoConstraints ?? this.dismissedAutoConstraints,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      _versionKey: currentSchemaVersion,
      _setupKey: isSetupCompleted,
      _stageKey: schoolStage.storageName,
      _managedKey: Map<String, int>.from(managedAutoConstraints),
      _dismissedKey: dismissedAutoConstraints.toList(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      isSetupCompleted: json[_setupKey] == true,
      schoolStage: SchoolStage.fromStorage(json[_stageKey]),
      managedAutoConstraints: _decodeManaged(json[_managedKey]),
      dismissedAutoConstraints: _decodeDismissed(json[_dismissedKey]),
    );
  }

  static Map<String, int> _decodeManaged(Object? raw) {
    if (raw is! Map) {
      return <String, int>{};
    }

    final decoded = <String, int>{};
    raw.forEach((key, value) {
      if (key is String && value is num) {
        decoded[key] = value.toInt();
      }
    });
    return decoded;
  }

  static Set<String> _decodeDismissed(Object? raw) {
    if (raw is! List) {
      return <String>{};
    }

    return raw.whereType<String>().toSet();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppConfig &&
        other.isSetupCompleted == isSetupCompleted &&
        other.schoolStage == schoolStage &&
        mapEquals(other.managedAutoConstraints, managedAutoConstraints) &&
        setEquals(other.dismissedAutoConstraints, dismissedAutoConstraints);
  }

  @override
  int get hashCode => Object.hash(
        isSetupCompleted,
        schoolStage,
        Object.hashAllUnordered(managedAutoConstraints.entries
            .map((entry) => Object.hash(entry.key, entry.value))),
        Object.hashAllUnordered(dismissedAutoConstraints),
      );

  @override
  String toString() {
    return 'AppConfig(setup: $isSetupCompleted, stage: ${schoolStage.name}, '
        'managed: ${managedAutoConstraints.length}, '
        'dismissed: ${dismissedAutoConstraints.length})';
  }
}
