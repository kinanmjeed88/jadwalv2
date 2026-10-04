import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/core/entities/subject_constraint_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/features/management/domain/services/lesson_assignment_planner.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/pre_validation_engine.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/smart_auto_fix_usecase.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';

void main() {
  final defaultSettings = AppSettingsEntity(
    periodsPerDay: 7,
    daysPerWeek: 5,
    exportPageSize: 'A4',
    exportOrientation: 'Landscape',
    exportAutoScale: true,
    schoolName: 'مدرسة الاختبار',
    principalName: 'المدير',
  );

  List<TeacherEntity> buildTeachers(int count) {
    return List<TeacherEntity>.generate(
      count,
      (i) => TeacherEntity(
        id: i + 1,
        name: 'معلم ${i + 1}',
        specialization: '',
        maxLessonsPerWeek: 40,
        maxLessonsPerDay: 7,
        unavailableDays: const [],
        allowedPeriods: const [],
      ),
    );
  }

  (List<SubjectEntity>, List<LessonEntity>) buildLessonsForClassroom({
    required ClassroomEntity classroom,
    required List<TeacherEntity> teachers,
    required List<int> subjectWeeklyCounts,
  }) {
    final subjects = <SubjectEntity>[];
    final lessons = <LessonEntity>[];
    var lessonId = 1;

    for (var i = 0; i < subjectWeeklyCounts.length; i++) {
      final count = subjectWeeklyCounts[i];
      final subject = SubjectEntity(
        id: i + 1,
        name: 'مادة ${i + 1}',
        lessonsPerWeek: count,
        preferEarlyPeriods: false,
        allowedPeriods: const [],
      );
      subjects.add(subject);
      final teacher = teachers[i % teachers.length];
      for (var k = 0; k < count; k++) {
        lessons.add(
          LessonEntity(
            id: lessonId++,
            teacher: teacher,
            subject: subject,
            classroom: classroom,
            isPinned: false,
          ),
        );
      }
    }
    return (subjects, lessons);
  }

  group('PreValidationEngine with variable weekly loads', () {
    test('accepts 31 lessons when classroom weeklyTarget is 31', () {
      final teachers = buildTeachers(7);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس الابتدائي أ',
        grade: 'الصف السادس',
        weeklyTarget: 31,
        dailyPeriods: const <int>[7, 6, 6, 6, 6],
      );
      // 7 subjects: 5+5+5+5+5+3+3 = 31 lessons
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 3, 3],
      );

      final engine = PreValidationEngine(
        existingLessons: lessons,
        teachers: teachers,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        subjects: subjects,
      );

      expect(engine.validateAll(), isEmpty);
    });

    test('rejects 30 lessons when classroom weeklyTarget is 31', () {
      final teachers = buildTeachers(6);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس الابتدائي أ',
        grade: 'الصف السادس',
        weeklyTarget: 31,
        dailyPeriods: const <int>[7, 6, 6, 6, 6],
      );
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 5],
      );

      final engine = PreValidationEngine(
        existingLessons: lessons,
        teachers: teachers,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        subjects: subjects,
      );

      final errors = engine.validateAll();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('31'));
    });

    test('rejects invalid dailyPeriods sum in PreValidationEngine', () {
      final teachers = buildTeachers(7);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس الابتدائي أ',
        grade: 'الصف السادس',
        weeklyTarget: 31,
        dailyPeriods: const <int>[6, 6, 6, 6, 6], // sum = 30 != 31
      );
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 3, 3],
      );

      final engine = PreValidationEngine(
        existingLessons: lessons,
        teachers: teachers,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        subjects: subjects,
      );

      final errors = engine.validateAll();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('خطأ في توزيع الحصص'));
    });
  });

  group('TimetableGenerator with 31 and 33 lessons', () {
    test('generates valid schedule for 31 lessons (Sunday = 7, Mon-Thu = 6)',
        () {
      final teachers = buildTeachers(7);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس الابتدائي أ',
        grade: 'الصف السادس',
        weeklyTarget: 31,
        dailyPeriods: const <int>[7, 6, 6, 6, 6],
      );
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 3, 3],
      );

      final generator = TimetableGenerator(
        teachers: teachers,
        subjects: subjects,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        existingLessons: lessons,
      );

      final generated = generator.generate();
      expect(generated.length, 31);
      expect(generator.calculateCost(generated), lessThan(1000));

      final countsPerDay = List<int>.filled(5, 0);
      for (final lesson in generated) {
        expect(lesson.dayIndex, isNotNull);
        expect(lesson.periodIndex, isNotNull);
        final d = lesson.dayIndex!;
        final p = lesson.periodIndex!;
        countsPerDay[d]++;
        if (d == 0) {
          expect(p, inInclusiveRange(0, 6));
        } else {
          expect(p, inInclusiveRange(0, 5));
        }
      }
      expect(countsPerDay, <int>[7, 6, 6, 6, 6]);
    });

    test('generates valid schedule for 31 lessons custom Tuesday = 7', () {
      final teachers = buildTeachers(7);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس الابتدائي ب',
        grade: 'الصف السادس',
        weeklyTarget: 31,
        dailyPeriods: const <int>[6, 6, 7, 6, 6],
      );
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 3, 3],
      );

      final generator = TimetableGenerator(
        teachers: teachers,
        subjects: subjects,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        existingLessons: lessons,
      );

      final generated = generator.generate();
      expect(generated.length, 31);
      expect(generator.calculateCost(generated), lessThan(1000));

      final countsPerDay = List<int>.filled(5, 0);
      for (final lesson in generated) {
        final d = lesson.dayIndex!;
        final p = lesson.periodIndex!;
        countsPerDay[d]++;
        if (d == Weekday.tuesday.indexPosition) {
          expect(p, inInclusiveRange(0, 6));
        } else {
          expect(p, inInclusiveRange(0, 5));
        }
      }
      expect(countsPerDay, <int>[6, 6, 7, 6, 6]);
    });

    test('generates valid schedule for 33 lessons (Sun/Mon/Tue = 7, Wed/Thu = 6)',
        () {
      final teachers = buildTeachers(7);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس العلمي أ',
        grade: 'السادس العلمي',
        weeklyTarget: 33,
        dailyPeriods: const <int>[7, 7, 7, 6, 6],
      );
      // 7 subjects: 5+5+5+5+5+4+4 = 33 lessons
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 4, 4],
      );

      final generator = TimetableGenerator(
        teachers: teachers,
        subjects: subjects,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        existingLessons: lessons,
      );

      final generated = generator.generate();
      expect(generated.length, 33);
      expect(generator.calculateCost(generated), lessThan(1000));

      final countsPerDay = List<int>.filled(5, 0);
      for (final lesson in generated) {
        final d = lesson.dayIndex!;
        final p = lesson.periodIndex!;
        countsPerDay[d]++;
        if (d < 3) {
          expect(p, inInclusiveRange(0, 6));
        } else {
          expect(p, inInclusiveRange(0, 5));
        }
      }
      expect(countsPerDay, <int>[7, 7, 7, 6, 6]);
    });
  });

  group('SmartAutoFixUseCase with 31 lessons daily profile', () {
    test('repairs hard conflict without placing lessons outside dailyPeriods',
        () {
      final teachers = buildTeachers(7);
      final classroom = ClassroomEntity(
        id: 1,
        name: 'السادس الابتدائي أ',
        grade: 'الصف السادس',
        weeklyTarget: 31,
        dailyPeriods: const <int>[7, 6, 6, 6, 6],
      );
      final (subjects, lessons) = buildLessonsForClassroom(
        classroom: classroom,
        teachers: teachers,
        subjectWeeklyCounts: const <int>[5, 5, 5, 5, 5, 3, 3],
      );

      final generator = TimetableGenerator(
        teachers: teachers,
        subjects: subjects,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        existingLessons: lessons,
        subjectConstraints: const <SubjectConstraintEntity>[],
      );

      final validSchedule = generator.generate();

      // Introduce a hard conflict: move a Monday lesson into period 6 (invalid on Monday where dailyPeriods[1] == 6)
      final mondayLesson =
          validSchedule.firstWhere((l) => l.dayIndex == 1 && l.periodIndex == 5);
      mondayLesson.periodIndex = 6;

      final initialDiagnostics = generator.diagnose(validSchedule);
      expect(initialDiagnostics.where((d) => d.isHard), isNotEmpty);

      final autoFix = SmartAutoFixUseCase(
        teachers: teachers,
        subjects: subjects,
        classrooms: <ClassroomEntity>[classroom],
        settings: defaultSettings,
        subjectLessons: validSchedule,
        subjectConstraints: const <SubjectConstraintEntity>[],
      );

      final fixed = autoFix.execute(
        initialSchedule: validSchedule,
        initialDiagnostics: initialDiagnostics,
      );

      expect(fixed.isResolved, isTrue);
      for (final lesson in fixed.schedule) {
        final d = lesson.dayIndex!;
        final p = lesson.periodIndex!;
        expect(p, lessThan(classroom.dailyPeriods![d]));
      }
    });
  });

  group('LessonAssignmentPlanner with WeeklyLoadPolicy', () {
    test('respects officialPlan and classroom weeklyOverride capacities', () {
      final settings = AppSettings()
        ..periodsPerDay = 7
        ..daysPerWeek = 5;
      final teacher = Teacher()
        ..id = 1
        ..name = 'معلم'
        ..maxLessonsPerWeek = 40
        ..maxLessonsPerDay = 7;
      final sixthPrimary = Classroom()
        ..id = 1
        ..name = 'السادس أ'
        ..grade = 'الصف السادس الابتدائي';

      final existing30Lessons = List<Lesson>.generate(30, (index) {
        final s = Subject()
          ..id = index + 100
          ..name = 'مادة $index'
          ..lessonsPerWeek = 1;
        return Lesson()
          ..id = index + 1
          ..classroom.value = sixthPrimary
          ..subject.value = s
          ..teacher.value = teacher;
      });

      final extraSubject = Subject()
        ..id = 1
        ..name = 'مادة إضافية'
        ..lessonsPerWeek = 1;

      // Under uniform30, adding the 31st lesson fails (max capacity = 30)
      final uniformConfig = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.primary,
        weeklyLoadMode: WeeklyLoadMode.uniform30,
      );
      final planUnderUniform = LessonAssignmentPlanner.plan(
        teacher: teacher,
        subjects: <Subject>[extraSubject],
        classrooms: <Classroom>[sixthPrimary],
        existingLessons: existing30Lessons,
        settings: settings,
        appConfig: uniformConfig,
      );
      expect(planUnderUniform.isSuccess, isFalse);
      expect(planUnderUniform.errorMessage, contains('30 حصة'));

      // Under officialPlan, 6th primary has capacity 31, so adding the 31st lesson succeeds
      final officialConfig = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.primary,
        weeklyLoadMode: WeeklyLoadMode.officialPlan,
      );
      final planUnderOfficial = LessonAssignmentPlanner.plan(
        teacher: teacher,
        subjects: <Subject>[extraSubject],
        classrooms: <Classroom>[sixthPrimary],
        existingLessons: existing30Lessons,
        settings: settings,
        appConfig: officialConfig,
      );
      expect(planUnderOfficial.isSuccess, isTrue);
      expect(planUnderOfficial.pairsToCreate.length, 1);
    });
  });
}
