import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/core/entities/subject_constraint_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/exceptions/timetable_generation_exception.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/smart_auto_fix_usecase.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';

void main() {
  group('SubjectConsecutiveness', () {
    test('uses any for new subjects and unknown backup values', () {
      expect(Subject().consecutiveness, SubjectConsecutiveness.any);
      expect(
        subjectConsecutivenessFromStorage(null),
        SubjectConsecutiveness.any,
      );
      expect(
        subjectConsecutivenessFromStorage('future-value'),
        SubjectConsecutiveness.any,
      );
      expect(
        subjectConsecutivenessFromStorage('consecutive'),
        SubjectConsecutiveness.consecutive,
      );
    });
  });

  group('TimetableGenerator consecutiveness policy', () {
    test('charges and diagnoses non-consecutive lessons only when required',
        () {
      final teacher = _teacher(maxLessonsPerDay: 3);
      final classroom = _classroom();
      final constraint = _subjectConstraint();
      final consecutiveSubject = _subject(
        consecutiveness: SubjectConsecutiveness.consecutive,
      );
      final anySubject = _subject(
        consecutiveness: SubjectConsecutiveness.any,
      );

      final consecutiveLessons = [
        _lesson(1, teacher, consecutiveSubject, classroom, 0, 0),
        _lesson(2, teacher, consecutiveSubject, classroom, 0, 2),
      ];
      final consecutiveGenerator = _generator(
        subjects: [consecutiveSubject],
        lessons: consecutiveLessons,
        subjectConstraints: [constraint],
      );

      expect(consecutiveGenerator.calculateCost(consecutiveLessons), 50);
      final consecutiveDiagnostics = consecutiveGenerator.diagnose(
        consecutiveLessons,
      );
      final spreadDiagnostic = consecutiveDiagnostics.singleWhere(
        (diagnostic) =>
            diagnostic.reason is NonConsecutiveSubjectPeriodsConflict,
      );
      expect(spreadDiagnostic.lessonIds, containsAll(<int>[1, 2]));
      expect(spreadDiagnostic.isHard, isFalse);

      final anyLessons = [
        _lesson(1, teacher, anySubject, classroom, 0, 0),
        _lesson(2, teacher, anySubject, classroom, 0, 2),
      ];
      final anyGenerator = _generator(
        subjects: [anySubject],
        lessons: anyLessons,
        subjectConstraints: [constraint],
      );

      expect(anyGenerator.calculateCost(anyLessons), 0);
      expect(
        anyGenerator.diagnose(anyLessons).where(
              (diagnostic) =>
                  diagnostic.reason is NonConsecutiveSubjectPeriodsConflict,
            ),
        isEmpty,
      );
    });
  });

  group('SmartAutoFixUseCase', () {
    test('resolves a targeted teacher clash without moving a pinned lesson',
        () {
      final teacher = _teacher(maxLessonsPerDay: 3);
      final subject = _subject();
      final classroom = _classroom();
      final settings = _settings(daysPerWeek: 1, periodsPerDay: 2);
      final constraint = _subjectConstraint();
      final pinned = _lesson(
        1,
        teacher,
        subject,
        classroom,
        0,
        0,
        isPinned: true,
      );
      final movable = _lesson(2, teacher, subject, classroom, 0, 0);
      final initialSchedule = [pinned, movable];
      final generator = _generator(
        settings: settings,
        subjects: [subject],
        lessons: initialSchedule,
        subjectConstraints: [constraint],
      );
      final diagnostics = generator.diagnose(initialSchedule);

      expect(
        diagnostics.any(
          (diagnostic) =>
              diagnostic.reason is TeacherTimeSlotConflict && diagnostic.isHard,
        ),
        isTrue,
      );

      final useCase = SmartAutoFixUseCase(
        teachers: [teacher],
        subjects: [subject],
        classrooms: [classroom],
        settings: settings,
        subjectLessons: initialSchedule,
        subjectConstraints: [constraint],
      );
      final progress = <String>[];
      final result = useCase.execute(
        initialSchedule: initialSchedule,
        initialDiagnostics: diagnostics,
        onProgress: (attempt, total) => progress.add('$attempt/$total'),
      );

      expect(progress, isNotEmpty);
      expect(progress.first, '1/3');
      expect(result.isResolved, isTrue);
      expect(
        result.schedule.firstWhere((lesson) => lesson.id == 1).dayIndex,
        0,
      );
      expect(
        result.schedule.firstWhere((lesson) => lesson.id == 1).periodIndex,
        0,
      );
      final moved = result.schedule.firstWhere((lesson) => lesson.id == 2);
      expect(moved.isPinned, isFalse);
      expect(moved.periodIndex, 1);
      expect(
        result.diagnostics.any(
          (diagnostic) => diagnostic.isHard,
        ),
        isFalse,
      );
    });
  });
}

AppSettingsEntity _settings({int daysPerWeek = 5, int periodsPerDay = 3}) {
  return AppSettingsEntity(
    periodsPerDay: periodsPerDay,
    daysPerWeek: daysPerWeek,
    schoolName: '',
    principalName: '',
    exportPageSize: 'A4',
    exportOrientation: 'Portrait',
    exportAutoScale: true,
  );
}

TeacherEntity _teacher({required int maxLessonsPerDay}) {
  return TeacherEntity(
    id: 1,
    name: 'Teacher',
    specialization: '',
    maxLessonsPerWeek: 20,
    maxLessonsPerDay: maxLessonsPerDay,
    unavailableDays: const [],
    allowedPeriods: const [],
  );
}

SubjectEntity _subject({
  SubjectConsecutiveness consecutiveness = SubjectConsecutiveness.any,
}) {
  return SubjectEntity(
    id: 1,
    name: 'Math',
    lessonsPerWeek: 2,
    preferEarlyPeriods: false,
    allowedPeriods: const [],
    consecutiveness: consecutiveness,
  );
}

ClassroomEntity _classroom() {
  return ClassroomEntity(id: 1, name: 'Class', grade: 'Grade 1');
}

SubjectConstraintEntity _subjectConstraint() {
  return SubjectConstraintEntity(
    grade: 'Grade 1',
    subjectName: 'Math',
    maxPeriodsPerDay: 2,
  );
}

LessonEntity _lesson(
  int id,
  TeacherEntity teacher,
  SubjectEntity subject,
  ClassroomEntity classroom,
  int day,
  int period, {
  bool isPinned = false,
}) {
  return LessonEntity(
    id: id,
    teacher: teacher,
    subject: subject,
    classroom: classroom,
    dayIndex: day,
    periodIndex: period,
    isPinned: isPinned,
  );
}

TimetableGenerator _generator({
  AppSettingsEntity? settings,
  required List<SubjectEntity> subjects,
  required List<LessonEntity> lessons,
  List<SubjectConstraintEntity> subjectConstraints = const [],
}) {
  return TimetableGenerator(
    teachers: [lessons.first.teacher!],
    subjects: subjects,
    classrooms: [lessons.first.classroom!],
    settings: settings ?? _settings(),
    existingLessons: lessons,
    subjectConstraints: subjectConstraints,
  );
}
