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
    List<Lesson> oneLessonPerDay(
        Teacher teacher, Subject subject, Classroom classroom) {
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

  // جداول قديمة محفوظة قبل تطبيق القواعد قد تحمل مخالفة. يُسمح بالحركة التي
  // تُصلحها أو تقلّلها، ويُرفض نقل المخالفة من يوم إلى آخر حتى لو بقي
  // مجموعها الأسبوعي ثابتًا.
  group('validateGroupRules: legacy violations cannot move to another day', () {
    test('consecutive: moving a gap from one day to another is rejected', () {
      final teacher = _teacher(1);
      final subject =
          _subject(1, consecutiveness: SubjectConsecutiveness.consecutive);
      final classroom = _classroom(1);
      // اليوم 0: الحصتان 1 و3 (فراغ قديم). اليوم 1: الحصة 1.
      final lessons = [
        _lesson(1, teacher, subject, classroom, day: 0, period: 0),
        _lesson(2, teacher, subject, classroom, day: 0, period: 2),
        _lesson(3, teacher, subject, classroom, day: 1, period: 0),
      ];
      final validator = _validator(lessons, maxPerDay: 2);

      // يُزال الفراغ من اليوم 0 ويُنشأ فراغ جديد في اليوم 1.
      expect(
        validator.validateGroupRules(
          moves: {2: (dayIndex: 1, periodIndex: 2)},
          operationLabel: 'النقل',
        ),
        contains('«متتالي»'),
      );

      // الإصلاح الحقيقي: الحصة تلتصق بحصة اليوم 1.
      expect(
        validator.validateGroupRules(
          moves: {2: (dayIndex: 1, periodIndex: 1)},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });

    test('consecutive: a move that only reduces a legacy day is allowed', () {
      final teacher = _teacher(1);
      final subject =
          _subject(1, consecutiveness: SubjectConsecutiveness.consecutive);
      final classroom = _classroom(1);
      // اليوم 0: الحصص 1 و3 و5 (فراغان قديمان).
      final lessons = [
        _lesson(1, teacher, subject, classroom, day: 0, period: 0),
        _lesson(2, teacher, subject, classroom, day: 0, period: 2),
        _lesson(3, teacher, subject, classroom, day: 0, period: 4),
      ];

      // 5 ← 4: يبقى فراغ واحد بدل اثنين؛ تحسين تدريجي مسموح.
      expect(
        _validator(lessons, maxPerDay: 3).validateGroupRules(
          moves: {3: (dayIndex: 0, periodIndex: 3)},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });

    test('nonConsecutive: moving an adjacency to another day is rejected', () {
      final teacher = _teacher(1);
      final subject =
          _subject(1, consecutiveness: SubjectConsecutiveness.nonConsecutive);
      final classroom = _classroom(1);
      // اليوم 0: الحصتان 1 و2 متجاورتان (مخالفة قديمة). اليوم 1: الحصة 4.
      final lessons = [
        _lesson(1, teacher, subject, classroom, day: 0, period: 0),
        _lesson(2, teacher, subject, classroom, day: 0, period: 1),
        _lesson(3, teacher, subject, classroom, day: 1, period: 3),
      ];
      final validator = _validator(lessons, maxPerDay: 2);

      expect(
        validator.validateGroupRules(
          moves: {2: (dayIndex: 1, periodIndex: 2)},
          operationLabel: 'النقل',
        ),
        contains('«غير متتالي»'),
      );
      expect(
        validator.validateGroupRules(
          moves: {2: (dayIndex: 1, periodIndex: 1)},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });

    test('distribution: moving a shortfall to another day is rejected', () {
      final teacher = _teacher(1);
      final subject = _subject(1);
      final classroom = _classroom(1);
      // 5 حصص على 5 أيام بتوزيع قديم [2,0,1,1,1]: نقص في اليوم 1 وزيادة في اليوم 0.
      final lessons = [
        _lesson(1, teacher, subject, classroom, day: 0, period: 0),
        _lesson(2, teacher, subject, classroom, day: 0, period: 1),
        _lesson(3, teacher, subject, classroom, day: 2, period: 0),
        _lesson(4, teacher, subject, classroom, day: 3, period: 0),
        _lesson(5, teacher, subject, classroom, day: 4, period: 0),
      ];
      final validator = _validator(lessons, maxPerDay: 2);

      // [2,1,0,1,1]: يُسدّ نقص اليوم 1 ويُفتح نقص جديد في اليوم 2؛ المجموع ثابت.
      expect(
        validator.validateGroupRules(
          moves: {3: (dayIndex: 1, periodIndex: 0)},
          operationLabel: 'النقل',
        ),
        contains('توزيع حصص مادة'),
      );

      // [1,1,1,1,1]: إصلاح كامل.
      expect(
        validator.validateGroupRules(
          moves: {2: (dayIndex: 1, periodIndex: 0)},
          operationLabel: 'النقل',
        ),
        isNull,
      );
    });

    test('distribution: moving an excess to another day is rejected', () {
      final teacher = _teacher(1);
      final subject = _subject(1);
      final classroom = _classroom(1);
      final lessons = [
        _lesson(1, teacher, subject, classroom, day: 0, period: 0),
        _lesson(2, teacher, subject, classroom, day: 0, period: 1),
        _lesson(3, teacher, subject, classroom, day: 2, period: 0),
        _lesson(4, teacher, subject, classroom, day: 3, period: 0),
        _lesson(5, teacher, subject, classroom, day: 4, period: 0),
      ];

      // [1,0,2,1,1]: تُزال زيادة اليوم 0 وتنشأ زيادة في اليوم 2.
      expect(
        _validator(lessons, maxPerDay: 2).validateGroupRules(
          moves: {2: (dayIndex: 2, periodIndex: 1)},
          operationLabel: 'النقل',
        ),
        contains('توزيع حصص مادة'),
      );
    });

    test('swap: a violation carried to another day by a swap is rejected', () {
      final arabicTeacher = _teacher(1);
      final mathTeacher = _teacher(2);
      final arabic =
          _subject(1, consecutiveness: SubjectConsecutiveness.consecutive);
      final math = _subject(2, name: 'Math');
      final classroom = _classroom(1);
      final lessons = [
        _lesson(1, arabicTeacher, arabic, classroom, day: 0, period: 0),
        _lesson(2, arabicTeacher, arabic, classroom, day: 0, period: 2),
        _lesson(3, arabicTeacher, arabic, classroom, day: 1, period: 0),
        _lesson(4, mathTeacher, math, classroom, day: 1, period: 3),
      ];
      final validator = _validatorWithConstraints(
        lessons,
        {'Arabic': 2, 'Math': 1},
      );

      // تبديل العربي (اليوم 0، الحصة 3) مع الرياضيات (اليوم 1، الحصة 4).
      expect(
        validator.validateGroupRules(
          moves: {
            2: (dayIndex: 1, periodIndex: 3),
            4: (dayIndex: 0, periodIndex: 2),
          },
          operationLabel: 'التبديل',
        ),
        contains('«متتالي»'),
      );
    });
  });

  group('rejected validation leaves no partial modification', () {
    test('placement and group checks never mutate lessons or the index', () {
      final arabicTeacher = _teacher(1);
      final mathTeacher = _teacher(2);
      final arabic =
          _subject(1, consecutiveness: SubjectConsecutiveness.consecutive);
      final math = _subject(2, name: 'Math');
      final classroom = _classroom(1);
      final lessons = [
        _lesson(1, arabicTeacher, arabic, classroom, day: 0, period: 0),
        _lesson(2, arabicTeacher, arabic, classroom, day: 0, period: 2),
        _lesson(3, arabicTeacher, arabic, classroom, day: 1, period: 0),
        _lesson(4, mathTeacher, math, classroom, day: 1, period: 3),
      ];
      final validator = _validatorWithConstraints(
        lessons,
        {'Arabic': 2, 'Math': 1},
      );
      final before = _snapshot(validator.index);

      // رفض على مستوى الحصة: الصف مشغول.
      expect(
        validator.validatePlacement(
          lesson: lessons[1],
          newDay: 1,
          newPeriod: 3,
          excludedLessonIds: {2},
          operationLabel: 'النقل',
        ),
        isNotNull,
      );
      // رفض على مستوى المجموعة للنقل (فراغ إضافي في اليوم 0) والتبديل.
      expect(
        validator.validateGroupRules(
          moves: {3: (dayIndex: 0, periodIndex: 4)},
          operationLabel: 'النقل',
        ),
        isNotNull,
      );
      expect(
        validator.validateGroupRules(
          moves: {
            2: (dayIndex: 1, periodIndex: 3),
            4: (dayIndex: 0, periodIndex: 2),
          },
          operationLabel: 'التبديل',
        ),
        isNotNull,
      );

      expect(_snapshot(validator.index), before);
      expect(
        [
          for (final lesson in lessons)
            '${lesson.dayIndex}:${lesson.periodIndex}'
        ],
        ['0:0', '0:2', '1:0', '1:3'],
      );
    });
  });
}

TimetableMoveValidator _validatorWithConstraints(
  List<Lesson> lessons,
  Map<String, int> maxPerDayBySubject,
) {
  final grade = lessons.first.classroom.value!.grade;
  return TimetableMoveValidator(
    TimetableInteractionIndex.build(
      lessons: lessons,
      subjectConstraints: [
        for (final entry in maxPerDayBySubject.entries)
          SubjectConstraint()
            ..grade = grade
            ..subjectName = entry.key
            ..maxPeriodsPerDay = entry.value,
      ],
    ),
  );
}

/// صورة نصية حتمية لكل ما يحمله الفهرس: مواضع الحصص وكل الحاويات.
String _snapshot(TimetableInteractionIndex index) {
  String bucket<K>(Map<K, Set<int>> map) {
    final entries = [
      for (final entry in map.entries)
        if (entry.value.isNotEmpty)
          '${entry.key}=${(entry.value.toList()..sort()).join(',')}',
    ]..sort();
    return entries.join(';');
  }

  final lessons = index.lessonsById.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return [
    for (final lesson in lessons)
      '${lesson.id}@${lesson.dayIndex}:${lesson.periodIndex}',
    bucket(index.teacherLessonsBySlot),
    bucket(index.classroomLessonsBySlot),
    bucket(index.subjectLessonsByDay),
    bucket(index.teacherLessonsByDay),
  ].join('\n');
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
  String name = 'Arabic',
  List<int> allowedPeriods = const [],
  SubjectConsecutiveness consecutiveness = SubjectConsecutiveness.any,
}) {
  return Subject()
    ..id = id
    ..name = name
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
