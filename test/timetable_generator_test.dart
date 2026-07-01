import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';

void main() {
  test('TimetableGenerator creates valid schedule enforcing max limits', () {
    final settings = AppSettings()..daysPerWeek = 5..periodsPerDay = 7;

    final t1 = Teacher()
      ..id = 1
      ..name = 'Teacher 1'
      ..maxLessonsPerWeek = 10
      ..maxLessonsPerDay = 2;

    final s1 = Subject()
      ..id = 1
      ..name = 'Math'
      ..lessonsPerWeek = 5;

    final c1 = Classroom()
      ..id = 1
      ..name = 'Class 1';

    final lessonList = <Lesson>[];
    for (int i=0; i<5; i++) {
      final l = Lesson();
      l.teacher.value = t1;
      l.subject.value = s1;
      l.classroom.value = c1;
      lessonList.add(l);
    }

    final generator = TimetableGenerator(
      teachers: [t1],
      subjects: [s1],
      classrooms: [c1],
      settings: settings,
      existingLessons: lessonList,
    );

    final generated = generator.generate();

    // Check all are placed
    expect(generated.every((l) => l.dayIndex != null && l.periodIndex != null), isTrue);

    // Check teacher daily limits
    for (int day=0; day<5; day++) {
      int lessonsToday = generated.where((l) => l.dayIndex == day && l.teacher.value?.id == t1.id).length;
      expect(lessonsToday <= t1.maxLessonsPerDay, isTrue);
    }
  });

  test('TimetableGenerator respects pinned lessons', () {
    final settings = AppSettings()..daysPerWeek = 5..periodsPerDay = 7;

    final t1 = Teacher()..id = 1..maxLessonsPerDay = 2..maxLessonsPerWeek=10;
    final s1 = Subject()..id = 1;
    final c1 = Classroom()..id = 1;

    final pinnedLesson = Lesson()
      ..teacher.value = t1
      ..subject.value = s1
      ..classroom.value = c1
      ..dayIndex = 0
      ..periodIndex = 0
      ..isPinned = true;

    final unpinnedLesson = Lesson()
      ..teacher.value = t1
      ..subject.value = s1
      ..classroom.value = c1;

    final generator = TimetableGenerator(
      teachers: [t1],
      subjects: [s1],
      classrooms: [c1],
      settings: settings,
      existingLessons: [pinnedLesson, unpinnedLesson],
    );

    final generated = generator.generate();

    final pLesson = generated.firstWhere((l) => l.isPinned);
    expect(pLesson.dayIndex, 0);
    expect(pLesson.periodIndex, 0);

    final uLesson = generated.firstWhere((l) => !l.isPinned);
    expect(uLesson.dayIndex != 0 || uLesson.periodIndex != 0, isTrue); // Must not overlap
  });
}
