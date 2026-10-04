import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/excel_export_usecase.dart';

void main() {
  late Directory directory;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    directory = await Directory.systemTemp.createTemp('weekday_excel_');
    isar = await Isar.open(
      [ClassroomSchema, SubjectSchema, TeacherSchema, LessonSchema],
      directory: directory.path, name: 'weekday_excel',
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  for (final days in [6, 7]) {
    test('$days-day saved customization exports lessons under the correct Excel day', () async {
      final daily = List<int>.generate(days, (index) => index + 1);
      final classroom = Classroom()
        ..name = 'أ'
        ..grade = 'الصف الأول'
        ..weeklyOverride = ClassroomWeeklyOverride(
            weeklyLessons: daily.reduce((a, b) => a + b), dailyPeriods: daily);
      final teacher = Teacher()
        ..name = 'معلم الاختبار'
        ..specialization = 'عام'
        ..maxLessonsPerDay = 7
        ..maxLessonsPerWeek = 40;
      final lessons = <Lesson>[];
      await isar.writeTxn(() async {
        await isar.classrooms.put(classroom);
        await isar.teachers.put(teacher);
        for (final day in Weekday.workingDays(days)) {
          final subject = Subject()
            ..name = 'مادة ${day.arabicLabel}'
            ..lessonsPerWeek = 1;
          await isar.subjects.put(subject);
          final lesson = Lesson()
            ..classroom.value = classroom
            ..teacher.value = teacher
            ..subject.value = subject
            ..dayIndex = day.indexPosition
            ..periodIndex = daily[day.indexPosition] - 1;
          await isar.lessons.put(lesson);
          await lesson.classroom.save();
          await lesson.teacher.save();
          await lesson.subject.save();
          lessons.add(lesson);
        }
      });
      final restored = (await isar.classrooms.get(classroom.id))!;
      final effective = AppConfig.initial()
          .resolveWeeklyConfigForClassroom(restored, daysPerWeek: days);
      expect(effective.dailyPeriods, daily);
      final settings = AppSettings()
        ..periodsPerDay = 7
        ..daysPerWeek = days;
      final bytes = await ExcelExportUseCase()
          .generateTimetableExcel(lessons, [restored], settings);
      final sheet = Excel.decodeBytes(bytes).tables['الجدول الأسبوعي']!;
      const expectedLabels = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      for (var day = 0; day < days; day++) {
        final startRow = 4 + day * settings.periodsPerDay;
        final lessonRow = startRow + effective.dailyPeriods[day] - 1;
        expect(sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 2, rowIndex: startRow)).value.toString(), expectedLabels[day]);
        expect(sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: 0, rowIndex: lessonRow)).value.toString(),
            'مادة ${expectedLabels[day]} | معلم');
      }
    });
  }
}
