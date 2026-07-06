import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';

void main() {
  test('TimetableGenerator creates valid schedule enforcing max limits', () {
    final settings = AppSettingsEntity(
      daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportPageSize: 'A4', exportOrientation: 'Portrait', exportAutoScale: true
    );

    final t1 = TeacherEntity(
      id: 1,
      name: 'Teacher 1',
      specialization: '',
      maxLessonsPerWeek: 10,
      maxLessonsPerDay: 2,
      unavailableDays: [],
      allowedPeriods: [],
    );

    final s1 = SubjectEntity(
      id: 1,
      name: 'Math',
      lessonsPerWeek: 5,
      preferEarlyPeriods: false,
      allowedPeriods: [],
    );

    final c1 = ClassroomEntity(
      id: 1,
      name: 'Class A',
      grade: 'Grade 1'
    );

    List<LessonEntity> lessonList = [];
    for (int i = 0; i < 5; i++) {
      lessonList.add(LessonEntity(
        id: i,
        teacher: t1,
        subject: s1,
        classroom: c1,
        isPinned: false,
      ));
    }

    final generator = TimetableGenerator(
      teachers: [t1],
      subjects: [s1],
      classrooms: [c1],
      settings: settings,
      existingLessons: lessonList,
    );

    final result = generator.generate();

    expect(result.length, 5);

    Map<int, int> daysCount = {};
    for (var l in result) {
      expect(l.dayIndex, isNotNull);
      expect(l.periodIndex, isNotNull);
      daysCount[l.dayIndex!] = (daysCount[l.dayIndex!] ?? 0) + 1;
    }

    for (var count in daysCount.values) {
      expect(count <= t1.maxLessonsPerDay, true);
    }
  });

  test('TimetableGenerator respects pinned lessons', () {
    final settings = AppSettingsEntity(
      daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportPageSize: 'A4', exportOrientation: 'Portrait', exportAutoScale: true
    );

    final t1 = TeacherEntity(id: 1, name: '', specialization: '', maxLessonsPerDay: 2, maxLessonsPerWeek: 10, unavailableDays: [], allowedPeriods: []);
    final s1 = SubjectEntity(id: 1, name: 'Math', lessonsPerWeek: 2, preferEarlyPeriods: false, allowedPeriods: []);
    final c1 = ClassroomEntity(id: 1, name: '', grade: '');

    final pinnedLesson = LessonEntity(
      id: 1,
      teacher: t1,
      subject: s1,
      classroom: c1,
      dayIndex: 1,
      periodIndex: 1,
      isPinned: true,
    );

    final unpinnedLesson = LessonEntity(
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

    final result = generator.generate();

    final pLesson = result.firstWhere((l) => l.id == 1);
    expect(pLesson.dayIndex, 1);
    expect(pLesson.periodIndex, 1);
    expect(pLesson.isPinned, true);

    final uLesson = result.firstWhere((l) => l.id == 2);
    expect(uLesson.dayIndex, isNotNull);
    expect(uLesson.periodIndex, isNotNull);

    // Ensure they don't overlap
    bool overlap = (uLesson.dayIndex == pLesson.dayIndex && uLesson.periodIndex == pLesson.periodIndex);
    expect(overlap, false);
  });
}
