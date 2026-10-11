import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/core/entities/subject_constraint_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/exceptions/timetable_generation_exception.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/smart_auto_fix_usecase.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';

/// اختبارات المحرك الفعلي (Dart) لسياسة التوزيع الأسبوعي والتتابع والتفضيلات.
///
/// كل سيناريو يملأ سعة الصف بحصص فارغة (بلا مادة ولا معلم) كما في الاختبارات
/// الموجودة، لأن الفحص المسبق يشترط تطابق الإسناد مع السعة.
void main() {
  const seeds = [1, 2, 3, 4, 5];

  group('Weekly distribution (hard balance + Sunday-first preference)', () {
    for (final seed in seeds) {
      test('Arabic 6 lessons on 5 days becomes [2,1,1,1,1] (seed $seed)', () {
        final scenario = _Scenario(lessonCount: 6, maxPerDay: 2);
        final result = scenario.generator(seed: seed).generate();

        expect(scenario.countsByDay(result), [2, 1, 1, 1, 1]);
        expect(scenario.generator().calculateCost(result), 0);
      });
    }

    for (final seed in seeds) {
      test('7 lessons become [2,2,1,1,1] (seed $seed)', () {
        final scenario = _Scenario(lessonCount: 7, maxPerDay: 2);
        final result = scenario.generator(seed: seed).generate();

        expect(scenario.countsByDay(result), [2, 2, 1, 1, 1]);
      });
    }

    test('teacher off on Sunday shifts extras to Monday and Tuesday', () {
      for (final seed in seeds) {
        final scenario = _Scenario(
          lessonCount: 6,
          maxPerDay: 2,
          teacherUnavailableDays: const [0],
        );
        final result = scenario.generator(seed: seed).generate();

        expect(scenario.countsByDay(result), [0, 2, 2, 1, 1],
            reason: 'seed $seed');
      }
    });

    test('5 lessons on 5 days is exactly one per day even with max 2', () {
      for (final seed in seeds) {
        final scenario = _Scenario(lessonCount: 5, maxPerDay: 2);
        final result = scenario.generator(seed: seed).generate();

        expect(scenario.countsByDay(result), [1, 1, 1, 1, 1],
            reason: 'seed $seed');
      }
    });

    test('fewer lessons than days keeps only the daily maximum', () {
      for (final seed in seeds) {
        final scenario = _Scenario(lessonCount: 3, maxPerDay: 1);
        final result = scenario.generator(seed: seed).generate();
        final counts = scenario.countsByDay(result);

        expect(counts.every((count) => count <= 1), isTrue,
            reason: 'seed $seed');
        expect(counts.fold<int>(0, (sum, c) => sum + c), 3);
      }
    });

    test('a missing day is a hard, diagnosed violation', () {
      final scenario = _Scenario(lessonCount: 6, maxPerDay: 2);
      final generator = scenario.generator();
      // [2,2,0,1,1]: Tuesday has no Arabic lesson.
      final state = scenario.placeSubject([
        (0, 0),
        (0, 1),
        (1, 0),
        (1, 1),
        (3, 0),
        (4, 0),
      ]);

      expect(generator.calculateCost(state), greaterThanOrEqualTo(1000));
      final diagnostic = generator.diagnose(state).singleWhere(
            (diagnostic) =>
                diagnostic.reason is SubjectDailyDistributionConflict,
          );
      expect(diagnostic.isHard, isTrue);
      final reason = diagnostic.reason as SubjectDailyDistributionConflict;
      expect(reason.day, 2);
      expect(reason.currentCount, 0);
      expect(reason.minRequired, 1);
    });

    test('an extra outside Sunday is a preference, not a violation', () {
      final scenario = _Scenario(lessonCount: 6, maxPerDay: 2);
      final generator = scenario.generator();
      // [1,1,1,1,2]
      final late = scenario.placeSubject([
        (0, 0),
        (1, 0),
        (2, 0),
        (3, 0),
        (4, 0),
        (4, 1),
      ]);
      // [2,1,1,1,1]
      final ideal = scenario.placeSubject([
        (0, 0),
        (0, 1),
        (1, 0),
        (2, 0),
        (3, 0),
        (4, 0),
      ]);

      expect(generator.calculateCost(late), 0);
      expect(generator.diagnose(late).where((d) => d.isHard), isEmpty);
      expect(
        generator.evaluate(late).preferenceCost,
        greaterThan(generator.evaluate(ideal).preferenceCost),
      );
    });
  });

  group('Consecutiveness policies differ in the real engine', () {
    test('cost and diagnostics for adjacent vs split placements', () {
      final adjacent = [(0, 0), (0, 1), (1, 0), (2, 0), (3, 0), (4, 0)];
      final split = [(0, 0), (0, 2), (1, 0), (2, 0), (3, 0), (4, 0)];

      final consecutive = _Scenario(
        lessonCount: 6,
        maxPerDay: 2,
        policy: SubjectConsecutiveness.consecutive,
      );
      final nonConsecutive = _Scenario(
        lessonCount: 6,
        maxPerDay: 2,
        policy: SubjectConsecutiveness.nonConsecutive,
      );
      final any = _Scenario(lessonCount: 6, maxPerDay: 2);

      int cost(_Scenario scenario, List<(int, int)> slots) =>
          scenario.generator().calculateCost(scenario.placeSubject(slots));

      expect(cost(consecutive, adjacent), 0);
      expect(cost(consecutive, split), 1000);
      expect(cost(nonConsecutive, adjacent), 1000);
      expect(cost(nonConsecutive, split), 0);
      expect(cost(any, adjacent), 0);
      expect(cost(any, split), 0);

      final nonConsecutiveDiagnostic = nonConsecutive
          .generator()
          .diagnose(nonConsecutive.placeSubject(adjacent))
          .singleWhere((d) => d.reason is AdjacentSubjectPeriodsConflict);
      expect(nonConsecutiveDiagnostic.isHard, isTrue);

      final consecutiveDiagnostic = consecutive
          .generator()
          .diagnose(consecutive.placeSubject(split))
          .singleWhere((d) => d.reason is NonConsecutiveSubjectPeriodsConflict);
      expect(consecutiveDiagnostic.isHard, isTrue);
    });

    for (final seed in seeds) {
      test('generated double lessons follow each policy (seed $seed)', () {
        final consecutive = _Scenario(
          lessonCount: 6,
          maxPerDay: 2,
          policy: SubjectConsecutiveness.consecutive,
        );
        final nonConsecutive = _Scenario(
          lessonCount: 6,
          maxPerDay: 2,
          policy: SubjectConsecutiveness.nonConsecutive,
        );

        final consecutiveResult = consecutive.generator(seed: seed).generate();
        final nonConsecutiveResult =
            nonConsecutive.generator(seed: seed).generate();

        for (final periods
            in consecutive.periodsByDay(consecutiveResult).values) {
          if (periods.length >= 2) {
            expect(periods.last - periods.first, periods.length - 1);
          }
        }
        for (final periods
            in nonConsecutive.periodsByDay(nonConsecutiveResult).values) {
          for (var i = 0; i < periods.length - 1; i++) {
            expect(periods[i + 1] - periods[i], greaterThan(1));
          }
        }
      });
    }

    test('consecutive does not force a double lesson', () {
      for (final seed in seeds) {
        final scenario = _Scenario(
          lessonCount: 5,
          maxPerDay: 2,
          policy: SubjectConsecutiveness.consecutive,
        );
        final result = scenario.generator(seed: seed).generate();

        expect(scenario.countsByDay(result), [1, 1, 1, 1, 1]);
      }
    });
  });

  group('Preferences and hard period rules', () {
    test('preferEarly affects the final schedule', () {
      for (final seed in seeds) {
        final scenario = _Scenario(lessonCount: 5, preferEarly: true);
        final generator = scenario.generator(seed: seed);
        final result = generator.generate();

        expect(
          scenario.subjectLessons(result).map((l) => l.periodIndex).toSet(),
          {0},
          reason: 'seed $seed',
        );
        expect(generator.evaluate(result).preferenceCost, 0);
      }
    });

    test('preferEarly never overrides subject allowed periods', () {
      final scenario = _Scenario(
        lessonCount: 5,
        preferEarly: true,
        subjectAllowedPeriods: const [2, 3],
      );
      final result = scenario.generator(seed: 7).generate();

      for (final lesson in scenario.subjectLessons(result)) {
        expect(lesson.periodIndex, 2);
      }
    });

    test('teacher allowed periods and days off are enforced', () {
      for (final seed in seeds) {
        final scenario = _Scenario(
          lessonCount: 4,
          teacherAllowedPeriods: const [1, 3],
          teacherUnavailableDays: const [2],
        );
        final result = scenario.generator(seed: seed).generate();

        for (final lesson in scenario.subjectLessons(result)) {
          expect([1, 3], contains(lesson.periodIndex));
          expect(lesson.dayIndex, isNot(2));
        }
      }
    });

    test('same seed gives the same schedule', () {
      final scenario = _Scenario(lessonCount: 6, maxPerDay: 2);
      String signature(List<LessonEntity> lessons) =>
          (List.of(lessons)..sort((a, b) => a.id.compareTo(b.id)))
              .map((l) => '${l.id}:${l.dayIndex}:${l.periodIndex}')
              .join(',');

      final first = scenario.generator(seed: 42).generate();
      final second = scenario.generator(seed: 42).generate();

      expect(signature(first), signature(second));
    });
  });

  group('Auto-fix never accepts consecutiveness violations', () {
    test('pinned gap cannot be resolved and is reported as hard', () {
      final scenario = _Scenario(
        lessonCount: 2,
        maxPerDay: 2,
        policy: SubjectConsecutiveness.consecutive,
      );
      final state = scenario.placeSubject([(0, 0), (0, 2)], pinned: true);
      final generator = scenario.generator();
      final diagnostics = generator.diagnose(state);

      final result = scenario.autoFix().execute(
            initialSchedule: state,
            initialDiagnostics: diagnostics,
          );

      expect(result.isResolved, isFalse);
      expect(
        result.diagnostics.any((d) =>
            d.isHard && d.reason is NonConsecutiveSubjectPeriodsConflict),
        isTrue,
      );
    });

    test('movable gap is repaired without leaving a violation', () {
      final scenario = _Scenario(
        lessonCount: 2,
        maxPerDay: 2,
        policy: SubjectConsecutiveness.consecutive,
      );
      final state = scenario.placeSubject([(0, 0), (0, 2)]);
      final generator = scenario.generator();

      final result = scenario.autoFix().execute(
            initialSchedule: state,
            initialDiagnostics: generator.diagnose(state),
          );

      expect(result.isResolved, isTrue);
      expect(generator.calculateCost(result.schedule), 0);
    });
  });
}

/// صف واحد، 5 أيام × 4 حصص، ومادة واحدة بعدد حصص محدد، والباقي حصص فارغة.
class _Scenario {
  _Scenario({
    required this.lessonCount,
    this.maxPerDay,
    this.policy = SubjectConsecutiveness.any,
    this.preferEarly = false,
    this.subjectAllowedPeriods = const [],
    this.teacherAllowedPeriods = const [],
    this.teacherUnavailableDays = const [],
  }) {
    teacher = TeacherEntity(
      id: 1,
      name: 'Teacher',
      specialization: '',
      maxLessonsPerWeek: 30,
      maxLessonsPerDay: 4,
      unavailableDays: teacherUnavailableDays,
      allowedPeriods: teacherAllowedPeriods,
    );
    subject = SubjectEntity(
      id: 1,
      name: 'Arabic',
      lessonsPerWeek: lessonCount,
      preferEarlyPeriods: preferEarly,
      allowedPeriods: subjectAllowedPeriods,
      consecutiveness: policy,
    );
    lessons = [
      for (var i = 0; i < lessonCount; i++)
        LessonEntity(
          id: i + 1,
          teacher: teacher,
          subject: subject,
          classroom: classroom,
          isPinned: false,
        ),
      for (var i = lessonCount; i < days * periods; i++)
        LessonEntity(id: i + 1, classroom: classroom, isPinned: false),
    ];
  }

  static const int days = 5;
  static const int periods = 4;

  final int lessonCount;
  final int? maxPerDay;
  final SubjectConsecutiveness policy;
  final bool preferEarly;
  final List<int> subjectAllowedPeriods;
  final List<int> teacherAllowedPeriods;
  final List<int> teacherUnavailableDays;

  final classroom = ClassroomEntity(id: 1, name: 'Class', grade: 'Grade 1');
  final settings = AppSettingsEntity(
    periodsPerDay: periods,
    daysPerWeek: days,
    schoolName: '',
    principalName: '',
    exportPageSize: 'A4',
    exportOrientation: 'Portrait',
    exportAutoScale: true,
  );
  late final TeacherEntity teacher;
  late final SubjectEntity subject;
  late final List<LessonEntity> lessons;

  List<SubjectConstraintEntity> get constraints => maxPerDay == null
      ? const []
      : [
          SubjectConstraintEntity(
            grade: 'Grade 1',
            subjectName: 'Arabic',
            maxPeriodsPerDay: maxPerDay!,
          ),
        ];

  TimetableGenerator generator({int? seed}) {
    return TimetableGenerator(
      teachers: [teacher],
      subjects: [subject],
      classrooms: [classroom],
      settings: settings,
      existingLessons: lessons,
      subjectConstraints: constraints,
      seed: seed,
      timeBudget: const Duration(seconds: 20),
    );
  }

  SmartAutoFixUseCase autoFix() {
    return SmartAutoFixUseCase(
      teachers: [teacher],
      subjects: [subject],
      classrooms: [classroom],
      settings: settings,
      subjectLessons: lessons,
      subjectConstraints: constraints,
    );
  }

  /// يضع حصص المادة في الخانات المحددة (يوم، حصة) ويملأ الباقي بالحصص الفارغة.
  List<LessonEntity> placeSubject(
    List<(int, int)> slots, {
    bool pinned = false,
  }) {
    final used = <int>{for (final slot in slots) slot.$1 * 100 + slot.$2};
    final free = <int>[
      for (var day = 0; day < days; day++)
        for (var period = 0; period < periods; period++)
          if (!used.contains(day * 100 + period)) day * 100 + period,
    ];
    var subjectIndex = 0;
    var freeIndex = 0;
    return [
      for (final lesson in lessons)
        if (lesson.subject != null)
          LessonEntity(
            id: lesson.id,
            teacher: lesson.teacher,
            subject: lesson.subject,
            classroom: lesson.classroom,
            dayIndex: slots[subjectIndex].$1,
            periodIndex: slots[subjectIndex++].$2,
            isPinned: pinned,
          )
        else
          LessonEntity(
            id: lesson.id,
            classroom: lesson.classroom,
            dayIndex: free[freeIndex] ~/ 100,
            periodIndex: free[freeIndex++] % 100,
            isPinned: false,
          ),
    ];
  }

  List<LessonEntity> subjectLessons(List<LessonEntity> schedule) =>
      schedule.where((lesson) => lesson.subject != null).toList();

  List<int> countsByDay(List<LessonEntity> schedule) {
    final counts = List<int>.filled(days, 0);
    for (final lesson in subjectLessons(schedule)) {
      counts[lesson.dayIndex!]++;
    }
    return counts;
  }

  Map<int, List<int>> periodsByDay(List<LessonEntity> schedule) {
    final result = <int, List<int>>{};
    for (final lesson in subjectLessons(schedule)) {
      result.putIfAbsent(lesson.dayIndex!, () => <int>[]).add(
            lesson.periodIndex!,
          );
    }
    for (final periods in result.values) {
      periods.sort();
    }
    return result;
  }
}
