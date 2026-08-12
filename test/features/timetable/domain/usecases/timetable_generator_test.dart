import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/entities/app_settings_entity.dart';
import 'package:jadwal_v2/core/entities/classroom_entity.dart';
import 'package:jadwal_v2/core/entities/lesson_entity.dart';
import 'package:jadwal_v2/core/entities/subject_entity.dart';
import 'package:jadwal_v2/core/entities/teacher_entity.dart';
import 'package:jadwal_v2/core/exceptions/conflict_reason.dart';
import 'package:jadwal_v2/core/exceptions/timetable_generation_exception.dart';
import 'package:jadwal_v2/features/timetable/domain/usecases/timetable_generator.dart';

void main() {
  group('TimetableGenerator Tests', () {
    test('Throws TeacherLoadExceeded when a teacher has more lessons than max capacity', () {
      final settings = AppSettingsEntity(daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportAutoScale: true, exportOrientation: 'Landscape', exportPageSize: 'A4');
      final teacher = TeacherEntity(id: 1, name: 'أحمد', maxLessonsPerDay: 4, maxLessonsPerWeek: 20, allowedPeriods: [], specialization: '', unavailableDays: []);
      final classroom = ClassroomEntity(id: 1, name: 'الصف الأول', grade: 'الأول');
      final subjects = List.generate(7, (i) => SubjectEntity(id: i+1, name: 'مادة $i', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false));

      final lessons = <LessonEntity>[];
      for(int i=0; i<7; i++) {
        for(int j=0; j<5; j++) {
           lessons.add(LessonEntity(
            id: i*5 + j,
            classroom: classroom,
            subject: subjects[i],
            teacher: teacher, // All 35 lessons assigned to 'أحمد' (who has max 20)
            isPinned: false,
          ));
        }
      }

      final generator = TimetableGenerator(
        teachers: [teacher],
        subjects: subjects,
        classrooms: [classroom],
        settings: settings,
        existingLessons: lessons,
      );

      try {
         generator.generate();
         fail('Expected TimetableGenerationException');
      } on TimetableGenerationException catch(e) {
         expect(e.reasons.any((r) => r is TeacherLoadExceeded), isTrue, reason: 'Expected TeacherLoadExceeded in reasons: ${e.reasons}');
      }
    });

    test('Throws InsufficientDaysForSubject when subject required > (max per day * days)', () {
      final settings = AppSettingsEntity(daysPerWeek: 5, periodsPerDay: 7, schoolName: '', principalName: '', exportAutoScale: true, exportOrientation: 'Landscape', exportPageSize: 'A4');
      final teacher = TeacherEntity(id: 1, name: 'أحمد', maxLessonsPerDay: 10, maxLessonsPerWeek: 50, allowedPeriods: [], specialization: '', unavailableDays: []);
      final classroom = ClassroomEntity(id: 1, name: 'الصف الأول', grade: 'الأول');
      final subjectMath = SubjectEntity(id: 1, name: 'الرياضيات', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false); // requires 8
      final subjectOther = SubjectEntity(id: 2, name: 'أخرى', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false); // requires 27

      final lessons = <LessonEntity>[];
      for (int i = 0; i < 8; i++) {
        lessons.add(LessonEntity(id: i + 1, teacher: teacher, subject: subjectMath, classroom: classroom, isPinned: false));
      }
      for (int i = 0; i < 27; i++) {
        lessons.add(LessonEntity(id: i + 9, teacher: teacher, subject: subjectOther, classroom: classroom, isPinned: false));
      }

      final generator = TimetableGenerator(
        teachers: [teacher],
        subjects: [subjectMath, subjectOther],
        classrooms: [classroom],
        settings: settings,
        existingLessons: lessons,
      );

      try {
         generator.generate();
         fail('Expected TimetableGenerationException');
      } on TimetableGenerationException catch(e) {
         expect(e.reasons.any((r) => r is InsufficientDaysForSubject), isTrue, reason: 'Expected InsufficientDaysForSubject in reasons: ${e.reasons}');
      }
    });

    test('Throws TimetableGenerationException when PreValidationEngine finds classroom capacity error', () {
       final teacher2 = TeacherEntity(id: 2, name: 'خالد', maxLessonsPerDay: 2, maxLessonsPerWeek: 4, allowedPeriods: [0], specialization: '', unavailableDays: []);
       final subject = SubjectEntity(id: 1, name: 'عربي', allowedPeriods: [], lessonsPerWeek: 5, preferEarlyPeriods: false);
       final classroom = ClassroomEntity(id: 1, name: 'الصف الأول', grade: 'الأول');

       final settings4 = AppSettingsEntity(daysPerWeek: 3, periodsPerDay: 1, schoolName: '', principalName: '', exportAutoScale: true, exportOrientation: 'Landscape', exportPageSize: 'A4'); // cap is 3
       final lessons4 = [
         LessonEntity(id: 1, teacher: teacher2, subject: subject, classroom: classroom, isPinned: false),
         LessonEntity(id: 2, teacher: teacher2, subject: subject, classroom: classroom, isPinned: false),
         LessonEntity(id: 3, teacher: teacher2, subject: subject, classroom: classroom, isPinned: false),
         LessonEntity(id: 4, teacher: teacher2, subject: subject, classroom: classroom, isPinned: false),
       ];

       final generator4 = TimetableGenerator(
        teachers: [teacher2],
        subjects: [subject],
        classrooms: [classroom],
        settings: settings4,
        existingLessons: lessons4,
      );

      expect(
        () => generator4.generate(),
        throwsA(isA<TimetableGenerationException>()),
      );
    });
  });
}
