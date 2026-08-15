import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_interaction_index.dart';

void main() {
  group('TimetableInteractionIndex', () {
    test('indexes slot, daily, and subject constraints', () {
      final teacher = _teacher(1, maxLessonsPerDay: 2);
      final subject = _subject(1);
      final classroom = _classroom(1, grade: 'Grade 1');
      final lessons = [
        _lesson(1, teacher, subject, classroom, day: 0, period: 0),
        _lesson(2, teacher, subject, classroom, day: 0, period: 1),
      ];
      final index = TimetableInteractionIndex.build(
        lessons: lessons,
        subjectConstraints: [
          _constraint(grade: 'Grade 1', subjectName: 'Math', maxPeriods: 2),
        ],
      );

      expect(
        index.hasTeacherConflict(
          teacherId: teacher.id,
          dayIndex: 0,
          periodIndex: 0,
        ),
        isTrue,
      );
      expect(
        index.hasClassroomConflict(
          classroomId: classroom.id,
          dayIndex: 0,
          periodIndex: 1,
        ),
        isTrue,
      );
      expect(
        index.teacherCountOnDay(teacherId: teacher.id, dayIndex: 0),
        2,
      );
      expect(
        index.subjectCountOnDay(
          classroomId: classroom.id,
          subjectId: subject.id,
          dayIndex: 0,
        ),
        2,
      );
      expect(
        index.maxPeriodsPerDay(grade: 'Grade 1', subjectName: 'Math'),
        2,
      );
    });

    test('updates only affected buckets after moving a lesson', () {
      final teacher = _teacher(1, maxLessonsPerDay: 2);
      final subject = _subject(1);
      final classroom = _classroom(1, grade: 'Grade 1');
      final lesson = _lesson(
        1,
        teacher,
        subject,
        classroom,
        day: 0,
        period: 0,
      );
      final index = TimetableInteractionIndex.build(
        lessons: [lesson],
        subjectConstraints: const [],
      );

      index.moveLesson(lessonId: lesson.id, newDay: 1, newPeriod: 2);

      expect(lesson.dayIndex, 1);
      expect(lesson.periodIndex, 2);
      expect(
        index.hasTeacherConflict(
          teacherId: teacher.id,
          dayIndex: 0,
          periodIndex: 0,
        ),
        isFalse,
      );
      expect(
        index.hasTeacherConflict(
          teacherId: teacher.id,
          dayIndex: 1,
          periodIndex: 2,
        ),
        isTrue,
      );
      expect(index.teacherCountOnDay(teacherId: teacher.id, dayIndex: 0), 0);
      expect(index.teacherCountOnDay(teacherId: teacher.id, dayIndex: 1), 1);
    });

    test('updates both lessons after a swap', () {
      final teacher = _teacher(1, maxLessonsPerDay: 3);
      final subject = _subject(1);
      final classroom = _classroom(1, grade: 'Grade 1');
      final first = _lesson(
        1,
        teacher,
        subject,
        classroom,
        day: 0,
        period: 0,
      );
      final second = _lesson(
        2,
        teacher,
        subject,
        classroom,
        day: 1,
        period: 1,
      );
      final index = TimetableInteractionIndex.build(
        lessons: [first, second],
        subjectConstraints: const [],
      );

      expect(index.swapLessons(firstId: first.id, secondId: second.id), isTrue);

      expect(first.dayIndex, 1);
      expect(first.periodIndex, 1);
      expect(second.dayIndex, 0);
      expect(second.periodIndex, 0);
      expect(
        index.hasClassroomConflict(
          classroomId: classroom.id,
          dayIndex: 0,
          periodIndex: 0,
          excludedLessonIds: {second.id},
        ),
        isFalse,
      );
      expect(
        index.hasClassroomConflict(
          classroomId: classroom.id,
          dayIndex: 1,
          periodIndex: 1,
          excludedLessonIds: {first.id},
        ),
        isFalse,
      );
    });
  });
}

Teacher _teacher(int id, {required int maxLessonsPerDay}) {
  return Teacher()
    ..id = id
    ..name = 'Teacher $id'
    ..specialization = ''
    ..maxLessonsPerWeek = 20
    ..maxLessonsPerDay = maxLessonsPerDay
    ..unavailableDays = <int>[]
    ..allowedPeriods = <int>[];
}

Subject _subject(int id) {
  return Subject()
    ..id = id
    ..name = 'Math'
    ..lessonsPerWeek = 2
    ..preferEarlyPeriods = false
    ..allowedPeriods = <int>[];
}

Classroom _classroom(int id, {required String grade}) {
  return Classroom()
    ..id = id
    ..name = 'Class $id'
    ..grade = grade;
}

SubjectConstraint _constraint({
  required String grade,
  required String subjectName,
  required int maxPeriods,
}) {
  return SubjectConstraint()
    ..grade = grade
    ..subjectName = subjectName
    ..maxPeriodsPerDay = maxPeriods;
}

Lesson _lesson(
  int id,
  Teacher teacher,
  Subject subject,
  Classroom classroom, {
  required int day,
  required int period,
}) {
  return Lesson()
    ..id = id
    ..dayIndex = day
    ..periodIndex = period
    ..teacher.value = teacher
    ..subject.value = subject
    ..classroom.value = classroom;
}
