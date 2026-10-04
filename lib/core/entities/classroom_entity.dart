import '../models/classroom.dart';
import '../models/weekly_load_policy.dart';
import 'app_settings_entity.dart';

class ClassroomEntity {
  final int id;
  final String name;
  final String grade;
  final int? weeklyTarget;
  final List<int>? dailyPeriods;

  ClassroomEntity({
    required this.id,
    required this.name,
    required this.grade,
    this.weeklyTarget,
    List<int>? dailyPeriods,
  }) : dailyPeriods = dailyPeriods == null
            ? null
            : List<int>.unmodifiable(dailyPeriods);

  factory ClassroomEntity.fromIsar(
    Classroom classroom, {
    EffectiveWeeklyConfig? effectiveConfig,
  }) {
    if (effectiveConfig != null) {
      return ClassroomEntity(
        id: classroom.id,
        name: classroom.name,
        grade: classroom.grade,
        weeklyTarget: effectiveConfig.weeklyTarget,
        dailyPeriods: effectiveConfig.dailyPeriods,
      );
    }

    return ClassroomEntity(
      id: classroom.id,
      name: classroom.name,
      grade: classroom.grade,
      weeklyTarget: classroom.weeklyLessonsOverride,
      dailyPeriods: classroom.dailyPeriodsOverride,
    );
  }

  /// السعة الأسبوعية الفعلية للصف.
  ///
  /// تعتمد على [weeklyTarget] (أو مجموع [dailyPeriods]) عند توفّره،
  /// وتعود إلى `settings.periodsPerDay * settings.daysPerWeek` فقط عند
  /// عدم تزويد أي إعداد أسبوعي (للتوافق الخلفي مع البيانات/الاختبارات القديمة).
  int resolveWeeklyCapacity(AppSettingsEntity settings) {
    if (weeklyTarget != null && weeklyTarget! > 0) {
      return weeklyTarget!;
    }
    if (dailyPeriods != null && dailyPeriods!.isNotEmpty) {
      return dailyPeriods!.fold<int>(0, (sum, p) => sum + p);
    }
    final safeDays = settings.daysPerWeek < 1 ? 5 : settings.daysPerWeek;
    final safePeriods = settings.periodsPerDay < 1 ? 1 : settings.periodsPerDay;
    return safeDays * safePeriods;
  }

  /// التوزيع اليومي الفعلي للحصص على أيام الدوام.
  List<int> resolveDailyPeriods(AppSettingsEntity settings) {
    final safeDays = settings.daysPerWeek < 1 ? 5 : settings.daysPerWeek;
    if (dailyPeriods != null && dailyPeriods!.length == safeDays) {
      return dailyPeriods!;
    }
    if (weeklyTarget != null && weeklyTarget! > 0) {
      return DailyDistribution.buildAutomatic(weeklyTarget!, safeDays);
    }
    final safePeriods = settings.periodsPerDay < 1 ? 1 : settings.periodsPerDay;
    return List<int>.filled(safeDays, safePeriods, growable: false);
  }

  /// عدد الحصص المتاحة لهذا الصف في يوم معيّن.
  int periodsForDay(int dayIndex, AppSettingsEntity settings) {
    final resolved = resolveDailyPeriods(settings);
    if (dayIndex < 0 || dayIndex >= resolved.length) {
      return 0;
    }
    return resolved[dayIndex];
  }
}
