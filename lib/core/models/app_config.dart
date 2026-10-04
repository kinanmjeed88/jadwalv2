import 'package:flutter/foundation.dart';

import 'classroom.dart';
import 'school_stage.dart';
import 'weekly_load_policy.dart';

/// إعدادات المنصة العامة التي تُخزَّن في ملف JSON مستقل عن قاعدة البيانات.
///
/// لماذا ملف مستقل بدل مجموعة Isar جديدة؟
/// * هذه بيانات وصفية (أول تشغيل، المرحلة، سياسة الحصص الأسبوعية، الخطة الرسمية،
///   وسجلّ القيود التوليدية) ولا حاجة لاستعلامها أو فرزها داخل قاعدة البيانات.
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
    this.weeklyLoadMode = WeeklyLoadMode.fallback,
    this.officialWeeklyPlan = const OfficialWeeklyPlan.standard(),
  });

  /// الحالة الافتراضية: لم يُكمل المستخدم الإعداد الأولي بعد.
  factory AppConfig.initial() {
    return const AppConfig(
      isSetupCompleted: false,
      schoolStage: SchoolStage.fallback,
      managedAutoConstraints: <String, int>{},
      dismissedAutoConstraints: <String>{},
      weeklyLoadMode: WeeklyLoadMode.fallback,
      officialWeeklyPlan: OfficialWeeklyPlan.standard(),
    );
  }

  /// صيغة التخزين الحالية؛ تُستخدم لتمييز الملفات القديمة عند التوسعة.
  static const int currentSchemaVersion = 2;

  static const String _setupKey = 'isSetupCompleted';
  static const String _stageKey = 'schoolStage';
  static const String _managedKey = 'managedAutoConstraints';
  static const String _dismissedKey = 'dismissedAutoConstraints';
  static const String _weeklyLoadModeKey = 'weeklyLoadMode';
  static const String _officialWeeklyPlanKey = 'officialWeeklyPlan';
  static const String _versionKey = 'schemaVersion';

  /// هل أتمّ المستخدم الإعداد الأولي (البيانات الإلزامية + المرحلة)؟
  final bool isSetupCompleted;

  /// المرحلة الدراسية المختارة.
  final SchoolStage schoolStage;

  /// السياسة العامة لتحديد عدد الحصص الأسبوعية للصفوف.
  final WeeklyLoadMode weeklyLoadMode;

  /// بيانات الخطة الدراسية الرسمية القابلة للتعديل.
  final OfficialWeeklyPlan officialWeeklyPlan;

  /// القيود التي أنشأها نظام المزامنة التلقائي للمرحلة الابتدائية.
  /// المفتاح هو [SubjectConstraintKey.storageKey] والقيمة هي الحد اليومي
  /// الذي كتبته المزامنة، فإذا تغيّرت القيمة يدويًا يُعتبر القيد ملكًا
  /// للمستخدم وتتوقف المزامنة عن إدارته.
  final Map<String, int> managedAutoConstraints;

  /// مفاتيح حذفها المستخدم صراحةً فلا تُعاد تلقائيًا ما دامت مؤهلة.
  final Set<String> dismissedAutoConstraints;

  int get schemaVersion => currentSchemaVersion;

  /// يحسب الإعداد الأسبوعي الفعلي لصف معيّن بناءً على السياسة العامة وتخصيص الصف.
  EffectiveWeeklyConfig resolveWeeklyConfigForClassroom(
    Classroom classroom, {
    required int daysPerWeek,
    int dailyMaximum = WeeklyLoadValidator.defaultDailyMaximum,
  }) {
    return WeeklyLoadResolver.resolveForClassroom(
      classroom: classroom,
      mode: weeklyLoadMode,
      officialPlan: officialWeeklyPlan,
      schoolStage: schoolStage,
      daysPerWeek: daysPerWeek,
      dailyMaximum: dailyMaximum,
    );
  }

  AppConfig copyWith({
    bool? isSetupCompleted,
    SchoolStage? schoolStage,
    WeeklyLoadMode? weeklyLoadMode,
    OfficialWeeklyPlan? officialWeeklyPlan,
    Map<String, int>? managedAutoConstraints,
    Set<String>? dismissedAutoConstraints,
  }) {
    return AppConfig(
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
      schoolStage: schoolStage ?? this.schoolStage,
      weeklyLoadMode: weeklyLoadMode ?? this.weeklyLoadMode,
      officialWeeklyPlan: officialWeeklyPlan ?? this.officialWeeklyPlan,
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
      _weeklyLoadModeKey: weeklyLoadMode.storageName,
      _officialWeeklyPlanKey: officialWeeklyPlan.toJson(),
      _managedKey: Map<String, int>.from(managedAutoConstraints),
      _dismissedKey: dismissedAutoConstraints.toList(),
    };
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      isSetupCompleted: json[_setupKey] == true,
      schoolStage: SchoolStage.fromStorage(json[_stageKey]),
      weeklyLoadMode: WeeklyLoadMode.fromStorage(json[_weeklyLoadModeKey]),
      officialWeeklyPlan:
          OfficialWeeklyPlan.fromJson(json[_officialWeeklyPlanKey]),
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
        other.weeklyLoadMode == weeklyLoadMode &&
        other.officialWeeklyPlan == officialWeeklyPlan &&
        mapEquals(other.managedAutoConstraints, managedAutoConstraints) &&
        setEquals(other.dismissedAutoConstraints, dismissedAutoConstraints);
  }

  @override
  int get hashCode => Object.hash(
        isSetupCompleted,
        schoolStage,
        weeklyLoadMode,
        officialWeeklyPlan,
        Object.hashAllUnordered(managedAutoConstraints.entries
            .map((entry) => Object.hash(entry.key, entry.value))),
        Object.hashAllUnordered(dismissedAutoConstraints),
      );

  @override
  String toString() {
    return 'AppConfig(setup: $isSetupCompleted, stage: ${schoolStage.name}, '
        'weeklyMode: ${weeklyLoadMode.name}, '
        'managed: ${managedAutoConstraints.length}, '
        'dismissed: ${dismissedAutoConstraints.length})';
  }
}
