import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/pre_validation_engine.dart';
import 'package:jadwal_v2/core/exceptions/conflict_reason.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';

void main() {
  group('PreValidationEngine', () {
    test('Should return GenericSolverFailure when assigned lessons exceed classroom capacity', () {
      final settings = AppSettingsEntity(daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportAutoScale: true, exportOrientation: 'Landscape', exportPageSize: 'A4'); // Capacity = 35
      final classroom = ClassroomEntity(id: 1, name: 'Grade 1', grade: '1');
      final subject = SubjectEntity(id: 1, name: 'Math', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false);

      final lessons = List.generate(36, (index) => LessonEntity(
        id: index,
        classroom: classroom,
        subject: subject,
        isPinned: false,
      ));

      final engine = PreValidationEngine(
        existingLessons: lessons,
        teachers: [],
        classrooms: [classroom],
        settings: settings,
        subjects: [subject],
      );

      final conflicts = engine.validateAll();
      expect(conflicts.length, greaterThan(0));
      expect(conflicts.any((c) => c is GenericSolverFailure && c.details.contains('36')), isTrue);
    });

    test('Should return GenericSolverFailure when assigned lessons are less than classroom capacity', () {
      final settings = AppSettingsEntity(daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportAutoScale: true, exportOrientation: 'Landscape', exportPageSize: 'A4'); // Capacity = 35
      final classroom = ClassroomEntity(id: 1, name: 'Grade 1', grade: '1');
      final subject = SubjectEntity(id: 1, name: 'Math', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false);

      final lessons = List.generate(34, (index) => LessonEntity(
        id: index,
        classroom: classroom,
        subject: subject,
        isPinned: false,
      ));

      final engine = PreValidationEngine(
        existingLessons: lessons,
        teachers: [],
        classrooms: [classroom],
        settings: settings,
        subjects: [subject],
      );

      final conflicts = engine.validateAll();
      expect(conflicts.length, greaterThan(0));
      expect(conflicts.any((c) => c is GenericSolverFailure && c.details.contains('34')), isTrue);
    });

    test('Should return empty list when assigned lessons perfectly match classroom capacity', () {
      final settings = AppSettingsEntity(daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportAutoScale: true, exportOrientation: 'Landscape', exportPageSize: 'A4'); // Capacity = 35
      final classroom = ClassroomEntity(id: 1, name: 'Grade 1', grade: '1');
      final subject = SubjectEntity(id: 1, name: 'Math', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false);

      final subjects = List.generate(7, (i) => SubjectEntity(id: i+1, name: 'Subj$i', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false));
      final lessons = [];
      for(int i=0; i<7; i++) {
        for(int j=0; j<5; j++) {
           lessons.add(LessonEntity(
            id: i*5 + j,
            classroom: classroom,
            subject: subjects[i],
            isPinned: false,
          ));
        }
      }

      final engine = PreValidationEngine(
        existingLessons: lessons.cast<LessonEntity>(),
        teachers: [],
        classrooms: [classroom],
        settings: settings,
        subjects: subjects,
      );

      final conflicts = engine.validateAll();
      expect(conflicts, isEmpty);
    });
  });
}
