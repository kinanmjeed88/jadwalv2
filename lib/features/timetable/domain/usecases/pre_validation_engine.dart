import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/exceptions/unsolvable_timetable_exception.dart';

class PreValidationEngine {
  /// Validates the pool of unassigned lessons against teacher constraints.
  /// Throws [UnsolvableTimetableException] if any constraint is inherently unsolvable.
  static void validate(List<LessonEntity> lessons, List<TeacherEntity> teachers) {
    // Check if any teacher is assigned more lessons than their weekly max capacity.

    // Group lessons by teacher ID
    final Map<int, int> teacherLessonCount = {};
    for (final lesson in lessons) {
      if (lesson.teacher != null) {
        teacherLessonCount[lesson.teacher!.id] = (teacherLessonCount[lesson.teacher!.id] ?? 0) + 1;
      }
    }

    // Validate against teacher capacity
    for (final teacher in teachers) {
      final assignedCount = teacherLessonCount[teacher.id] ?? 0;
      if (assignedCount > teacher.maxLessonsPerWeek) {
        throw UnsolvableTimetableException(
          'خطأ في الإسناد: الأستاذ (${teacher.name}) تم إسناد $assignedCount حصص له، بينما الحد الأقصى المسموح به أسبوعياً هو ${teacher.maxLessonsPerWeek}. يرجى تقليل نصابه أو زيادة حده الأقصى.',
        );
      }
    }

    // We can add more pre-validation checks here in the future
    // e.g., Subject constraints, impossible day/period combos, etc.
  }
}
