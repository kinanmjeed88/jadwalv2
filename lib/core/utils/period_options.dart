import '../models/app_config.dart';
import '../models/classroom.dart';

/// خيارات «الدروس المسموحة» في صفحات المعلمين والمواد.
///
/// عدد الدروس في اليوم قد يتجاوز `settings.periodsPerDay` عندما يكون للصف
/// توزيع يومي خاص (مثال: 31 حصة أسبوعيًا ← 7 حصص يوم الأحد)، لذلك نعتمد أكبر
/// قيمة بين الإعداد العام وأعلى توزيع يومي لأي صف.
class PeriodOptions {
  const PeriodOptions._();

  /// أكبر عدد دروس يومي في المدرسة.
  static int resolveSchoolPeriodCount({
    required int periodsPerDay,
    required int daysPerWeek,
    required AppConfig config,
    required Iterable<Classroom> classrooms,
  }) {
    var count = periodsPerDay;
    for (final classroom in classrooms) {
      final effective = config.resolveWeeklyConfigForClassroom(
        classroom,
        daysPerWeek: daysPerWeek,
      );
      if (effective.maxDailyPeriods > count) {
        count = effective.maxDailyPeriods;
      }
    }
    return count < 1 ? 1 : count;
  }

  /// فهارس الدروس المعروضة كخيارات: من 0 إلى `count - 1`، مع إبقاء أي قيمة
  /// محفوظة خارج هذا النطاق حتى لا تُحذف بصمت عند الحفظ.
  static List<int> choices(int count, Iterable<int> selected) {
    final values = <int>{
      for (var index = 0; index < count; index++) index,
      for (final value in selected)
        if (value >= 0) value,
    };
    return values.toList()..sort();
  }
}
