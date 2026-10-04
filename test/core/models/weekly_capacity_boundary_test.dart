import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_interaction_index.dart';

void main() {
  final settings = AppSettingsEntity.fromIsar(AppSettings()
    ..periodsPerDay = 9
    ..daysPerWeek = 5);
  for (final daily in <List<int>>[
    [6, 6, 6, 6, 6], [7, 6, 6, 6, 6],
    [6, 6, 7, 6, 6], [7, 7, 7, 6, 6],
  ]) {
    test('effective profile $daily overrides rectangular capacity', () {
      final target = daily.reduce((a, b) => a + b);
      final classroom = Classroom()
        ..id = 1
        ..name = 'أ'
        ..grade = 'الصف السادس'
        ..weeklyOverride = ClassroomWeeklyOverride(
            weeklyLessons: target, dailyPeriods: daily);
      final config = AppConfig.initial();
      final entity = ClassroomEntity.fromIsar(classroom,
          effectiveConfig: config.resolveWeeklyConfigForClassroom(
              classroom, daysPerWeek: 5));
      expect(entity.resolveWeeklyCapacity(settings), target);
      expect(entity.resolveDailyPeriods(settings), daily);
      final index = TimetableInteractionIndex.build(
          lessons: [], subjectConstraints: [], appConfig: config);
      for (var day = 0; day < daily.length; day++) {
        expect(index.allowedPeriodsForClassroomOnDay(
            classroom: classroom, dayIndex: day), daily[day]);
      }
    });
  }
  test('only absent capacity uses legacy rectangular fallback', () {
    final legacy = ClassroomEntity(id: 1, name: 'أ', grade: 'الأول');
    expect(legacy.resolveWeeklyCapacity(settings), 45);
    expect(legacy.resolveDailyPeriods(settings), [9, 9, 9, 9, 9]);
    final invalid = ClassroomEntity(id: 1, name: 'أ', grade: 'الأول',
        weeklyTarget: 0, dailyPeriods: [0]);
    expect(invalid.resolveWeeklyCapacity(settings), 0);
    expect(invalid.resolveDailyPeriods(settings), [0]);
  });
  test('orphan daily override does not bypass global policy in interaction', () {
    final classroom = Classroom()
      ..name = 'أ'
      ..grade = 'الصف الأول'
      ..dailyPeriodsOverride = [9, 9, 9, 9, 9];
    final index = TimetableInteractionIndex.build(
        lessons: [], subjectConstraints: [], appConfig: AppConfig.initial());
    expect(index.allowedPeriodsForClassroomOnDay(
        classroom: classroom, dayIndex: 0), 6);
  });
}
