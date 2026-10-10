import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_interaction_index.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_move_validator.dart';

/// السحب والتبديل اليدوي يطبّقان قواعد المحرك نفسها.
void main() {
  group('validatePlacement', () {
    test('rejects a period outside the teacher allowed periods', () {
      final teacher = _teacher(1, allowedPeriods: const [0, 1]);
      final subject = _subject(1);
      final classroom = _classroom(1);
      final lesson = _lesson(1, teacher, subject, classroom, day: 0, period: 0);
      final validator = _validator([lesson]);

      final error = validator.validatePlacement(
        lesson: lesson,
        newDay: 1,
        newPeriod: 3,
        excludedLessonIds: {lesson.id},
        operationLabel: 'النقل',
      );
      expect(error, contains('غير مسموح له بالتدريس في الحصة (4)'));

      expect(
        validator.validatePlacement(
          lesson: lesson,
          newDay: 1,
          newPeriod: 1,
          excludedLessonIds: {lesson.id},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });

    test('keeps the existing subject allowed-period message', () {
      final teacher = _teacher(1);
      final subject = _subject(1, allowedPeriods: const [2]);
      final classroom = _classroom(1);
      final lesson = _lesson(1, teacher, subject, classroom, day: 0, period: 2);

      expect(
        _validator([lesson]).validatePlacement(
          lesson: lesson,
          newDay: 1,
          newPeriod: 0,
          excludedLessonIds: {lesson.id},
          operationLabel: 'النقل',
        ),
        'لا يمكن النقل: المادة غير مسموح بتدريسها في الحصة (1) بناءً على إعداداتها',
      );
    });
  });

  group('validateGroupRules: consecutiveness', () {
    String? moveSecondTo(SubjectConsecutiveness policy, int period) {
      final teacher = _teacher(1);
      final subject = _subject(1, consecutiveness: policy);
      final classroom = _classroom(1);
      final first = _lesson(1, teacher, subject, classroom, day: 0, period: 0);
      final second = _lesson(2, teacher, subject, classroom, day: 1, period: 0);
      return _validator([first, second], maxPerDay: 2).validateGroupRules(
        moves: {second.id: (dayIndex: 0, periodIndex: period)},
        operationLabel: 'النقل',
      );
    }

    test('consecutive rejects a gap and accepts an adjacent period', () {
      expect(moveSecondTo(SubjectConsecutiveness.consecutive, 2),
          contains('«متتالي»'));
      expect(moveSecondTo(SubjectConsecutiveness.consecutive, 1), isNull);
    });

    test('nonConsecutive rejects adjacency and accepts a gap', () {
      expect(moveSecondTo(SubjectConsecutiveness.nonConsecutive, 1),
          contains('«غير متتالي»'));
      expect(moveSecondTo(SubjectConsecutiveness.nonConsecutive, 2), isNull);
    });

    test('any accepts both', () {
      expect(moveSecondTo(SubjectConsecutiveness.any, 1), isNull);
      expect(moveSecondTo(SubjectConsecutiveness.any, 2), isNull);
    });

    test('a move that repairs a legacy gap is allowed', () {
      final teacher = _teacher(1);
      final subject =
          _subject(1, consecutiveness: SubjectConsecutiveness.consecutive);
      final classroom = _classroom(1);
      final first = _lesson(1, teacher, subject, classroom, day: 0, period: 0);
      final second = _lesson(2, teacher, subject, classroom, day: 0, period: 2);

      expect(
        _validator([first, second], maxPerDay: 2).validateGroupRules(
          moves: {second.id: (dayIndex: 0, periodIndex: 1)},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });
  });

  group('validateGroupRules: weekly distribution', () {
    List<Lesson> oneLessonPerDay(Teacher teacher, Subject subject,
        Classroom classroom) {
      return [
        for (var day = 0; day < 5; day++)
          _lesson(day + 1, teacher, subject, classroom, day: day, period: 0),
      ];
    }

    test('emptying a day of a balanced subject is rejected', () {
      final teacher = _teacher(1);
      final subject = _subject(1);
      final classroom = _classroom(1);
      final lessons = oneLessonPerDay(teacher, subject, classroom);

      final error = _validator(lessons, maxPerDay: 2).validateGroupRules(
        moves: {lessons[1].id: (dayIndex: 0, periodIndex: 1)},
        operationLabel: 'النقل',
      );

      expect(error, contains('توزيع حصص مادة'));
    });

    test('moving within the same day keeps the distribution', () {
      final teacher = _teacher(1);
      final subject = _subject(1);
      final classroom = _classroom(1);
      final lessons = oneLessonPerDay(teacher, subject, classroom);

      expect(
        _validator(lessons, maxPerDay: 2).validateGroupRules(
          moves: {lessons[1].id: (dayIndex: 1, periodIndex: 3)},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });

    test('swap applies both moves before checking the group', () {
      final teacher = _teacher(1);
      final subject = _subject(1);
      final classroom = _classroom(1);
      final lessons = oneLessonPerDay(teacher, subject, classroom);

      // Swapping two lessons of the same subject leaves one per day.
      expect(
        _validator(lessons, maxPerDay: 2).validateGroupRules(
          moves: {
            lessons[0].id: (dayIndex: 1, periodIndex: 0),
            lessons[1].id: (dayIndex: 0, periodIndex: 0),
          },
          operationLabel: 'التبديل',
        ),
        isNull,
      );
    });
  });
}

TimetableMoveValidator _validator(List<Lesson> lessons, {int maxPerDay = 1}) {
  final grade = lessons.first.classroom.value!.grade;
  final subjectName = lessons.first.subject.value!.name;
  return TimetableMoveValidator(
    TimetableInteractionIndex.build(
      lessons: lessons,
      subjectConstraints: [
        SubjectConstraint()
          ..grade = grade
          ..subjectName = subjectName
          ..maxPeriodsPerDay = maxPerDay,
      ],
    ),
  );
}

Teacher _teacher(int id, {List<int> allowedPeriods = const []}) {
  return Teacher()
    ..id = id
    ..name = 'Teacher $id'
    ..specialization = ''
    ..maxLessonsPerWeek = 30
    ..maxLessonsPerDay = 5
    ..unavailableDays = <int>[]
    ..allowedPeriods = List<int>.of(allowedPeriods);
}

Subject _subject(
  int id, {
  List<int> allowedPeriods = const [],
  SubjectConsecutiveness consecutiveness = SubjectConsecutiveness.any,
}) {
  return Subject()
    ..id = id
    ..name = 'Arabic'
    ..lessonsPerWeek = 5
    ..preferEarlyPeriods = false
    ..allowedPeriods = List<int>.of(allowedPeriods)
    ..consecutiveness = consecutiveness;
}

Classroom _classroom(int id) {
  return Classroom()
    ..id = id
    ..name = 'Class $id'
    ..grade = 'Grade 1';
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
