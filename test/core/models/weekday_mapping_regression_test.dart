import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/core/utils/timetable_display_utils.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_interaction_index.dart';

void main() {
  const labels = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

  test('persisted weekday indices stay Sunday-first, Friday=5, Saturday=6', () {
    expect(Weekday.friday.indexPosition, 5);
    expect(Weekday.saturday.indexPosition, 6);
    for (var index = 0; index < labels.length; index++) {
      final day = Weekday.fromDayIndex(index);
      expect(day.indexPosition, index);
      expect(day.arabicLabel, labels[index]);
    }
  });

  for (final days in [6, 7]) {
    test('$days-day UI/PDF/Excel adapter retains every weekday identity', () {
      final display = timetableDayLabels(days);
      expect(display, labels.take(days).toList());
      expect(display[Weekday.friday.indexPosition], 'الجمعة');
      if (days == 6) {
        expect(display, isNot(contains('السبت')));
      } else {
        expect(display[Weekday.saturday.indexPosition], 'السبت');
      }
      for (final day in Weekday.workingDays(days)) {
        expect(display[day.indexPosition], day.arabicLabel);
      }
    });

    for (final selectedDay in Weekday.workingDays(days)
        .where((day) => day == Weekday.friday || day == Weekday.saturday)) {
      test('$days-day ${selectedDay.name} customization keeps its day through resolution', () {
        final classroom = Classroom()
          ..id = 1
          ..name = 'أ'
          ..grade = 'الصف الأول'
          ..weeklyOverride = ClassroomWeeklyOverride.withExtraDays(
            weeklyLessons: days * 4 + 1,
            daysPerWeek: days,
            extraDays: [selectedDay.indexPosition],
          );
        final config = AppConfig.initial();
        final effective = config.resolveWeeklyConfigForClassroom(
            classroom, daysPerWeek: days);
        final settings = AppSettingsEntity.fromIsar(AppSettings()
          ..periodsPerDay = 7
          ..daysPerWeek = days);
        final entity = ClassroomEntity.fromIsar(classroom,
            effectiveConfig: effective);
        final index = TimetableInteractionIndex.build(
            lessons: [], subjectConstraints: [], appConfig: config,
            daysPerWeek: days);
        final display = timetableDayLabels(days);
        expect(effective.weekdayPeriods[selectedDay], 5);
        expect(DailyDistribution.fromWeekdayMap(effective.weekdayPeriods,
            daysPerWeek: days), classroom.dailyPeriodsOverride);
        for (final day in Weekday.workingDays(days)) {
          final expectedPeriods = day == selectedDay ? 5 : 4;
          expect(effective.weekdayPeriods[day], expectedPeriods);
          expect(entity.periodsForDay(day.indexPosition, settings), expectedPeriods);
          expect(index.allowedPeriodsForClassroomOnDay(
              classroom: classroom, dayIndex: day.indexPosition), expectedPeriods);
          // Same pairing used by the classroom customization preview, and
          // the shared adapter consumed by timetable/PDF/Excel renderers.
          expect('${display[day.indexPosition]} ($expectedPeriods)',
              '${day.arabicLabel} (${effective.dailyPeriods[day.indexPosition]})');
        }
      });
    }
  }

  test('all timetable renderers delegate day labels to the tested shared adapter', () {
    // Wiring regression guard: a correct helper alone must not hide a renderer
    // reverting to a private Friday/Saturday-swapped array.
    for (final path in [
      'lib/features/timetable/presentation/pages/timetable_page.dart',
      'lib/features/timetable/domain/usecases/pdf_export_usecase.dart',
      'lib/features/timetable/domain/usecases/excel_export_usecase.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('timetableDayLabels(settings.daysPerWeek)'), reason: path);
      expect(source, isNot(contains("'الجمعة'")), reason: path);
      expect(source, isNot(contains("'السبت'")), reason: path);
    }
  });
}
