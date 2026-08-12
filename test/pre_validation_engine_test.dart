import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/subject_constraint_entity.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/pre_validation_engine.dart';

void main() {
  test('PreValidationEngine checks for subject constraints over max limit', () {
    final settings = AppSettingsEntity(
      periodsPerDay: 7,
      daysPerWeek: 5,
      schoolName: 'Test',
      principalName: 'Test',
      exportPageSize: 'A4',
      exportOrientation: 'Portrait',
      exportAutoScale: true,
    );

    final classroom = ClassroomEntity(id: 1, name: 'Grade 1', grade: 'Grade 1');
    final subject = SubjectEntity(id: 1, name: 'Arabic', lessonsPerWeek: 6, preferEarlyPeriods: false, allowedPeriods: []);
    final teacher = TeacherEntity(id: 1, name: 'T1', specialization: 'Gen', maxLessonsPerDay: 4, maxLessonsPerWeek: 20, unavailableDays: [], allowedPeriods: []);

    // 6 lessons assigned
    final lessons = List<LessonEntity>.generate(6, (i) => LessonEntity(
      id: i,
      teacher: teacher,
      classroom: classroom,
      subject: subject,
      isPinned: false,
    ));

    // Fill the rest up to 35 (capacity)
    final otherSubject = SubjectEntity(id: 2, name: 'Other', lessonsPerWeek: 29, preferEarlyPeriods: false, allowedPeriods: []);
    final otherLessons = List<LessonEntity>.generate(29, (i) => LessonEntity(
      id: i + 6,
      teacher: teacher,
      classroom: classroom,
      subject: otherSubject,
      isPinned: false,
    ));

    final existingLessons = [...lessons, ...otherLessons];

    final constraints = [
      SubjectConstraintEntity(grade: 'Grade 1', subjectName: 'Arabic', maxPeriodsPerDay: 1)
    ];

    final engine = PreValidationEngine(
      existingLessons: existingLessons,
      teachers: [teacher],
      classrooms: [classroom],
      settings: settings,
      subjects: [subject, otherSubject],
      subjectConstraints: constraints,
    );

    final errors = engine.validateAll();

    // Max per day is 1. Days per week is 5. Total max per week = 5.
    // 6 lessons were assigned.
    expect(errors.isNotEmpty, isTrue);
    expect(errors.first.contains('استحالة رياضية: الصف "Grade 1" مطلوب له 6 حصص لمادة "Arabic" أسبوعياً، ولكن الحد الأقصى المسموح يومياً هو 1 حصة، مما يجعل الحد الأقصى الأسبوعي 5 حصة فقط'), isTrue);
  });
}
