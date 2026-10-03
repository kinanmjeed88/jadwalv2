import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/features/management/domain/services/lesson_assignment_planner.dart';

Teacher _teacher({int id = 1, int maxWeekly = 40, int maxDaily = 8}) {
  return Teacher()
    ..id = id
    ..name = 'معلم $id'
    ..specialization = 'عام'
    ..maxLessonsPerDay = maxDaily
    ..maxLessonsPerWeek = maxWeekly
    ..unavailableDays = const <int>[]
    ..allowedPeriods = const <int>[];
}

Subject _subject({required int id, required String name, int weekly = 2}) {
  return Subject()
    ..id = id
    ..name = name
    ..lessonsPerWeek = weekly
    ..allowedPeriods = const <int>[];
}

Classroom _classroom({required int id, required String name}) {
  return Classroom()
    ..id = id
    ..name = name
    ..grade = 'الصف الأول';
}

AppSettings _settings() {
  return AppSettings()
    ..periodsPerDay = 7
    ..daysPerWeek = 5;
}

Lesson _lesson({
  required Teacher teacher,
  required Subject subject,
  required Classroom classroom,
}) {
  return Lesson()
    ..teacher.value = teacher
    ..subject.value = subject
    ..classroom.value = classroom;
}

void main() {
  group('LessonAssignmentPlanner', () {
    test('ينشئ كل تراكيب مادة × صف دون تكرار', () {
      final teacher = _teacher();
      final math = _subject(id: 1, name: 'رياضيات');
      final arabic = _subject(id: 2, name: 'عربي');
      final c1 = _classroom(id: 1, name: '1أ');
      final c2 = _classroom(id: 2, name: '1ب');

      final plan = LessonAssignmentPlanner.plan(
        teacher: teacher,
        subjects: [math, arabic],
        classrooms: [c1, c2],
        existingLessons: const <Lesson>[],
        settings: _settings(),
      );

      expect(plan.isSuccess, isTrue);
      expect(plan.pairsToCreate, hasLength(4));
      expect(plan.skippedDuplicates, isEmpty);

      final lessons = LessonAssignmentPlanner.buildPoolLessons(
        teacher: teacher,
        pairs: plan.pairsToCreate,
      );
      expect(lessons, hasLength(8));
    });

    test('يتخطى الزوج المكرر عند الإنشاء الأولي', () {
      final teacher = _teacher();
      final math = _subject(id: 1, name: 'رياضيات');
      final c1 = _classroom(id: 1, name: '1أ');
      final existing = _lesson(teacher: teacher, subject: math, classroom: c1);

      final plan = LessonAssignmentPlanner.plan(
        teacher: teacher,
        subjects: [math],
        classrooms: [c1],
        existingLessons: [existing],
        settings: _settings(),
        duplicateBehavior: DuplicateAssignmentBehavior.skip,
      );

      expect(plan.isSuccess, isTrue);
      expect(plan.pairsToCreate, isEmpty);
      expect(plan.skippedDuplicates, hasLength(1));
    });

    test('يفشل عند التكرار في مسار صفحة الإسناد', () {
      final teacher = _teacher();
      final math = _subject(id: 1, name: 'رياضيات');
      final c1 = _classroom(id: 1, name: '1أ');
      final existing = _lesson(teacher: teacher, subject: math, classroom: c1);

      final plan = LessonAssignmentPlanner.plan(
        teacher: teacher,
        subjects: [math],
        classrooms: [c1],
        existingLessons: [existing],
        settings: _settings(),
        duplicateBehavior: DuplicateAssignmentBehavior.fail,
      );

      expect(plan.isSuccess, isFalse);
      expect(plan.errorMessage, 'تم إسناد هذه المادة لهذا الصف مسبقاً');
    });

    test('يرفض تجاوز سعة الصف أو نصاب المعلم ويلغي العملية بالكامل', () {
      final teacher = _teacher(maxWeekly: 2);
      final math = _subject(id: 1, name: 'رياضيات', weekly: 3);
      final c1 = _classroom(id: 1, name: '1أ');

      final plan = LessonAssignmentPlanner.plan(
        teacher: teacher,
        subjects: [math],
        classrooms: [c1],
        existingLessons: const <Lesson>[],
        settings: _settings(),
      );

      expect(plan.isSuccess, isFalse);
      expect(plan.pairsToCreate, isEmpty);
      expect(plan.errorMessage, contains('المعلم'));
    });

    test('بدون مواد أو صفوف لا ينشئ إسنادات ولا يفشل', () {
      final plan = LessonAssignmentPlanner.plan(
        teacher: _teacher(),
        subjects: const <Subject>[],
        classrooms: [_classroom(id: 1, name: '1أ')],
        existingLessons: const <Lesson>[],
        settings: _settings(),
      );

      expect(plan.isSuccess, isTrue);
      expect(plan.pairsToCreate, isEmpty);
    });
  });
}
