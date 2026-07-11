import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';

class PreValidationEngine {
  final List<LessonEntity> existingLessons;
  final List<TeacherEntity> teachers;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;

  PreValidationEngine({
    required this.existingLessons,
    required this.teachers,
    required this.classrooms,
    required this.settings,
  });

  List<String> validateAll() {
    List<String> errors = [];

    // 1. Classroom Capacity Validation (Exact Match)
    int maxClassroomCapacity = settings.periodsPerDay * settings.daysPerWeek;

    for (var classroom in classrooms) {
      int assignedLessons = existingLessons.where((l) => l.classroom?.id == classroom.id).length;
      if (assignedLessons > maxClassroomCapacity) {
        errors.add('استحالة رياضية: الصف "${classroom.name}" مُسند إليه $assignedLessons حصة، بينما سعة الجدول الأسبوعي هي $maxClassroomCapacity حصة فقط (أيام الدوام × الحصص اليومية). الحل: تقليل حصص الصف أو زيادة أيام/حصص الدوام.');
      } else if (assignedLessons < maxClassroomCapacity) {
        errors.add('نقص في بيانات الإسناد: الصف "${classroom.name}" مسند إليه $assignedLessons حصة فقط، بينما المطلوب لملء جدوله الأسبوعي هو $maxClassroomCapacity حصة. يرجى إسناد المواد الناقصة لهذا الصف قبل توليد الجدول.');
      }
    }

    // 2. Teacher Capacity Validation
    for (var teacher in teachers) {
      int assignedLessons = existingLessons.where((l) => l.teacher?.id == teacher.id).length;

      int activeUnavailableDays = teacher.unavailableDays.where((day) => day < settings.daysPerWeek).length;
      int availableDays = settings.daysPerWeek - activeUnavailableDays;

      int maxCapacityDays = teacher.maxLessonsPerDay * availableDays;
      int absoluteMaxCapacity = teacher.maxLessonsPerWeek < maxCapacityDays ? teacher.maxLessonsPerWeek : maxCapacityDays;

      if (assignedLessons > absoluteMaxCapacity) {
        errors.add('استحالة رياضية: المعلم "${teacher.name}" مطلوب منه $assignedLessons حصة. لكن حده الأقصى أو أيام تفرغه تسمح له بتدريس $absoluteMaxCapacity حصة فقط كحد أقصى. الحل: رفع الحد الأقصى للمعلم، تقليل إجازاته، أو نقل بعض حصصه لمعلم آخر.');
      }
    }

    return errors;
  }
}
