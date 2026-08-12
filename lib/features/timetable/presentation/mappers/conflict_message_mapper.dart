import '../../../../core/exceptions/conflict_reason.dart';

class ConflictMessageMapper {
  static String toArabicMessage(ConflictReason reason) {
    if (reason is TeacherLoadExceeded) {
      return 'المعلم "${reason.teacherName}" تجاوز الحد الأقصى (${reason.maxLoad} حصة)، بينما المطلوب (${reason.currentLoad} حصة).';
    } else if (reason is InsufficientDaysForSubject) {
      return 'مادة "${reason.subjectName}" تحتاج ${reason.requiredLessons} حصص وعدد الأيام المتاحة ${reason.availableDays} فقط.';
    } else if (reason is TeacherTimeSlotConflict) {
      return 'تعارض في وقت المعلم "${reason.teacherName}" يوم ${reason.day + 1} الحصة ${reason.period + 1}.';
    } else if (reason is UnassignedSubject) {
      return 'المادة "${reason.subjectName}": ${reason.details}';
    } else if (reason is GenericSolverFailure) {
      return 'خطأ عام في التوليد: ${reason.details}';
    }
    return 'سبب غير معروف';
  }
}
