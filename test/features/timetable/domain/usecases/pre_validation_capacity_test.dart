import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/core/entities/subject_constraint_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/pre_validation_engine.dart';

/// الفحص المسبق يرفض فقط الاستحالات المثبتة رياضيًا.
void main() {
  test('subject allowed periods smaller than the weekly load are rejected', () {
    final errors = _validate(
      lessonCount: 6,
      maxPerDay: 2,
      subjectAllowedPeriods: const [0],
    );

    expect(
      errors.where((e) => e.contains('"Arabic"') && e.contains('تسمح بـ 5')),
      hasLength(1),
    );
  });

  test('consecutive with no adjacent allowed periods caps one per day', () {
    final errors = _validate(
      lessonCount: 6,
      maxPerDay: 2,
      subjectAllowedPeriods: const [0, 2],
      policy: SubjectConsecutiveness.consecutive,
    );

    expect(
      errors.any((e) => e.contains('متتالي') && e.contains('تسمح بـ 5')),
      isTrue,
    );

    // The same allowed periods are fine for nonConsecutive and any.
    expect(
      _validate(
        lessonCount: 6,
        maxPerDay: 2,
        subjectAllowedPeriods: const [0, 2],
        policy: SubjectConsecutiveness.nonConsecutive,
      ),
      isEmpty,
    );
    expect(
      _validate(
        lessonCount: 6,
        maxPerDay: 2,
        subjectAllowedPeriods: const [0, 2],
      ),
      isEmpty,
    );
  });

  test(
    'nonConsecutive with only adjacent allowed periods caps one per day',
    () {
      final errors = _validate(
        lessonCount: 10,
        maxPerDay: 2,
        subjectAllowedPeriods: const [0, 1],
        policy: SubjectConsecutiveness.nonConsecutive,
      );

      expect(errors.any((e) => e.contains('غير متتالي')), isTrue);
      expect(
        _validate(
          lessonCount: 10,
          maxPerDay: 2,
          subjectAllowedPeriods: const [0, 1],
          policy: SubjectConsecutiveness.consecutive,
        ),
        isEmpty,
      );
    },
  );

  test('teacher days off reduce the eligible days for the subject', () {
    // 5 lessons, max 1 per day, teacher off on Sunday: only 4 days remain.
    final errors = _validate(
      lessonCount: 5,
      maxPerDay: 1,
      teacherUnavailableDays: const [0],
    );

    expect(
      errors.any((e) => e.contains('"Arabic"') && e.contains('(4)')),
      isTrue,
    );
  });

  test('balanced minimum per day must fit on every eligible day', () {
    // 11 lessons on 5 days need at least 2 per day, but Thursday has 1 period.
    final errors = _validate(
      lessonCount: 11,
      maxPerDay: 3,
      dailyPeriods: const [6, 6, 6, 6, 1],
    );

    expect(
      errors.any((e) => e.contains('الخميس') && e.contains('2 حصة على الأقل')),
      isTrue,
    );
  });

  test('teacher allowed periods smaller than the load are rejected', () {
    final teacher = _teacher(allowedPeriods: const [0]);
    final subject = _subject();
    final classA = ClassroomEntity(id: 1, name: 'A', grade: 'G1');
    final classB = ClassroomEntity(id: 2, name: 'B', grade: 'G1');
    final lessons = <LessonEntity>[
      ..._groupWithFiller(classA, teacher, subject, 3, 1),
      ..._groupWithFiller(classB, teacher, subject, 3, 100),
    ];

    final errors = PreValidationEngine(
      existingLessons: lessons,
      teachers: [teacher],
      classrooms: [classA, classB],
      settings: _settings(),
      subjects: [subject],
    ).validateAll();

    expect(
      errors.where((e) => e.contains('"Teacher"') && e.contains('تسمح بـ 5')),
      hasLength(1),
    );
  });

  test('a feasible configuration produces no new errors', () {
    expect(
      _validate(
        lessonCount: 6,
        maxPerDay: 2,
        subjectAllowedPeriods: const [0, 1, 2],
        teacherAllowedPeriods: const [0, 1, 2, 3],
        policy: SubjectConsecutiveness.consecutive,
      ),
      isEmpty,
    );
  });

  test('the legacy max-per-week message is unchanged and not duplicated', () {
    final errors = _validate(lessonCount: 6, maxPerDay: 1);

    expect(errors, hasLength(1));
    expect(
      errors.single,
      'استحالة رياضية: الصف "Class" مطلوب له 6 حصص لمادة "Arabic" أسبوعياً، ولكن الحد الأقصى المسموح يومياً هو 1 حصة، مما يجعل الحد الأقصى الأسبوعي 5 حصة فقط (في 5 أيام).',
    );
  });
}

List<String> _validate({
  required int lessonCount,
  required int maxPerDay,
  List<int> subjectAllowedPeriods = const [],
  List<int> teacherAllowedPeriods = const [],
  List<int> teacherUnavailableDays = const [],
  SubjectConsecutiveness policy = SubjectConsecutiveness.any,
  List<int>? dailyPeriods,
}) {
  final teacher = _teacher(
    allowedPeriods: teacherAllowedPeriods,
    unavailableDays: teacherUnavailableDays,
  );
  final subject = _subject(
    allowedPeriods: subjectAllowedPeriods,
    policy: policy,
  );
  final classroom = ClassroomEntity(
    id: 1,
    name: 'Class',
    grade: 'G1',
    dailyPeriods: dailyPeriods,
  );
  final capacity = dailyPeriods == null
      ? 5 * 4
      : dailyPeriods.fold<int>(0, (sum, value) => sum + value);
  final lessons = <LessonEntity>[
    for (var i = 0; i < lessonCount; i++)
      LessonEntity(
        id: i + 1,
        teacher: teacher,
        subject: subject,
        classroom: classroom,
        isPinned: false,
      ),
    for (var i = lessonCount; i < capacity; i++)
      LessonEntity(id: i + 1, classroom: classroom, isPinned: false),
  ];

  return PreValidationEngine(
    existingLessons: lessons,
    teachers: [teacher],
    classrooms: [classroom],
    settings: _settings(),
    subjects: [subject],
    subjectConstraints: [
      SubjectConstraintEntity(
        grade: 'G1',
        subjectName: 'Arabic',
        maxPeriodsPerDay: maxPerDay,
      ),
    ],
  ).validateAll();
}

List<LessonEntity> _groupWithFiller(
  ClassroomEntity classroom,
  TeacherEntity teacher,
  SubjectEntity subject,
  int count,
  int firstId,
) {
  return [
    for (var i = 0; i < count; i++)
      LessonEntity(
        id: firstId + i,
        teacher: teacher,
        subject: subject,
        classroom: classroom,
        isPinned: false,
      ),
    for (var i = count; i < 20; i++)
      LessonEntity(id: firstId + i, classroom: classroom, isPinned: false),
  ];
}

AppSettingsEntity _settings() {
  return AppSettingsEntity(
    periodsPerDay: 4,
    daysPerWeek: 5,
    schoolName: '',
    principalName: '',
    exportPageSize: 'A4',
    exportOrientation: 'Portrait',
    exportAutoScale: true,
  );
}

TeacherEntity _teacher({
  List<int> allowedPeriods = const [],
  List<int> unavailableDays = const [],
}) {
  return TeacherEntity(
    id: 1,
    name: 'Teacher',
    specialization: '',
    maxLessonsPerWeek: 30,
    maxLessonsPerDay: 5,
    unavailableDays: unavailableDays,
    allowedPeriods: allowedPeriods,
  );
}

SubjectEntity _subject({
  List<int> allowedPeriods = const [],
  SubjectConsecutiveness policy = SubjectConsecutiveness.any,
}) {
  return SubjectEntity(
    id: 1,
    name: 'Arabic',
    lessonsPerWeek: 6,
    preferEarlyPeriods: false,
    allowedPeriods: allowedPeriods,
    consecutiveness: policy,
  );
}
