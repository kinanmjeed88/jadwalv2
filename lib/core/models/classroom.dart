import 'package:isar/isar.dart';

import 'weekly_load_policy.dart';

part 'classroom.g.dart';

@collection
class Classroom {
  Id id = Isar.autoIncrement;

  /// E.g., "شعبة أ"
  late String name;

  /// E.g., "الصف الأول"
  late String grade;

  /// تخصيص اختياري لعدد الحصص الأسبوعية لهذا الصف (`null` = استخدام الإعداد العام).
  int? weeklyLessonsOverride;

  /// تخصيص اختياري لتوزيع الحصص على أيام الدوام (`null` = توزيع تلقائي).
  List<int>? dailyPeriodsOverride;

  /// هل يملك الصف تخصيصًا مستقلًا عن الإعداد العام؟
  @ignore
  bool get hasWeeklyOverride =>
      weeklyLessonsOverride != null && weeklyLessonsOverride! > 0;

  /// قراءة أو تعيين التخصيص الأسبوعي الاختياري كـ Value Object.
  @ignore
  ClassroomWeeklyOverride? get weeklyOverride {
    final weekly = weeklyLessonsOverride;
    if (weekly == null || weekly <= 0) {
      return null;
    }
    return ClassroomWeeklyOverride(
      weeklyLessons: weekly,
      dailyPeriods: dailyPeriodsOverride == null
          ? null
          : List<int>.from(dailyPeriodsOverride!),
    );
  }

  set weeklyOverride(ClassroomWeeklyOverride? value) {
    if (value == null) {
      weeklyLessonsOverride = null;
      dailyPeriodsOverride = null;
      return;
    }
    weeklyLessonsOverride = value.weeklyLessons;
    dailyPeriodsOverride = value.dailyPeriods == null
        ? null
        : List<int>.from(value.dailyPeriods!);
  }
}
