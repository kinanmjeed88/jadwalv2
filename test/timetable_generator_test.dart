import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';
import 'package:jadwal_v2/features/timetable/domain/models/timetable_dto.dart';

void main() {
  test('TimetableGenerator creates valid schedule enforcing max limits', () {
    final settings = AppSettingsDto(daysPerWeek: 5, periodsPerDay: 7);

    final t1 = TeacherDto(
      id: 1,
      name: 'Teacher 1',
      maxLessonsPerWeek: 10,
      maxLessonsPerDay: 2,
      unavailableDays: [],
      allowedPeriods: [],
    );

    final s1 = SubjectDto(
      id: 1,
      name: 'Math',
      lessonsPerWeek: 5,
      preferEarlyPeriods: false,
      allowedPeriods: [],
    );

    final c1 = ClassroomDto(
      id: 1,
      name: 'Class 1',
    );

    final lessonList = <LessonDto>[];
    for (int i=0; i<5; i++) {
      final l = LessonDto(
        id: i,
        teacher: t1,
        subject: s1,
        classroom: c1,
        isPinned: false,
      );
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
      int lessonsToday = generated.where((l) => l.dayIndex == day && l.teacher?.id == t1.id).length;
      expect(lessonsToday <= t1.maxLessonsPerDay, isTrue);
    }
  });

  test('TimetableGenerator respects pinned lessons', () {
    final settings = AppSettingsDto(daysPerWeek: 5, periodsPerDay: 7);

    final t1 = TeacherDto(id: 1, name: '', maxLessonsPerDay: 2, maxLessonsPerWeek: 10, unavailableDays: [], allowedPeriods: []);
    final s1 = SubjectDto(id: 1, name: '', lessonsPerWeek: 1, preferEarlyPeriods: false, allowedPeriods: []);
    final c1 = ClassroomDto(id: 1, name: '');

    final pinnedLesson = LessonDto(
      id: 1,
      teacher: t1,
      subject: s1,
      classroom: c1,
      dayIndex: 0,
      periodIndex: 0,
      isPinned: true,
    );

    final unpinnedLesson = LessonDto(
      id: 2,
      teacher: t1,
      subject: s1,
      classroom: c1,
      isPinned: false,
    );

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
