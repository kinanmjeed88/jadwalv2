import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
sealed class ConflictReason extends Equatable {
  const ConflictReason();

  @override
  List<Object?> get props => [];
}

@immutable
class TeacherLoadExceeded extends ConflictReason {
  final String teacherName;
  final int currentLoad;
  final int maxLoad;

  const TeacherLoadExceeded(this.teacherName, this.currentLoad, this.maxLoad);

  @override
  List<Object?> get props => [teacherName, currentLoad, maxLoad];
}

@immutable
class InsufficientDaysForSubject extends ConflictReason {
  final String subjectName;
  final int requiredLessons;
  final int availableDays;

  const InsufficientDaysForSubject(this.subjectName, this.requiredLessons, this.availableDays);

  @override
  List<Object?> get props => [subjectName, requiredLessons, availableDays];
}

@immutable
class TeacherTimeSlotConflict extends ConflictReason {
  final String teacherName;
  final int day;
  final int period;

  const TeacherTimeSlotConflict(this.teacherName, this.day, this.period);

  @override
  List<Object?> get props => [teacherName, day, period];
}

@immutable
class UnassignedSubject extends ConflictReason {
  final String subjectName;
  final String details;

  const UnassignedSubject(this.subjectName, this.details);

  @override
  List<Object?> get props => [subjectName, details];
}

@immutable
class GenericSolverFailure extends ConflictReason {
  final String details;

  const GenericSolverFailure(this.details);

  @override
  List<Object?> get props => [details];
}

@immutable
class ClassroomTimeSlotConflict extends ConflictReason {
  final String classroomName;
  final int day;
  final int period;

  const ClassroomTimeSlotConflict(this.classroomName, this.day, this.period);

  @override
  List<Object?> get props => [classroomName, day, period];
}

@immutable
class TeacherUnavailableDayConflict extends ConflictReason {
  final String teacherName;
  final int day;

  const TeacherUnavailableDayConflict(this.teacherName, this.day);

  @override
  List<Object?> get props => [teacherName, day];
}

@immutable
class TeacherNotAllowedPeriodConflict extends ConflictReason {
  final String teacherName;
  final int period;

  const TeacherNotAllowedPeriodConflict(this.teacherName, this.period);

  @override
  List<Object?> get props => [teacherName, period];
}

@immutable
class SubjectMaxPerDayExceeded extends ConflictReason {
  final String subjectName;
  final String classroomName;
  final int day;
  final int maxAllowed;
  final int currentCount;

  const SubjectMaxPerDayExceeded(this.subjectName, this.classroomName, this.day, this.maxAllowed, this.currentCount);

  @override
  List<Object?> get props => [subjectName, classroomName, day, maxAllowed, currentCount];
}

@immutable
class SubjectNotAllowedPeriodConflict extends ConflictReason {
  final String subjectName;
  final int period;

  const SubjectNotAllowedPeriodConflict(this.subjectName, this.period);

  @override
  List<Object?> get props => [subjectName, period];
}

@immutable
class NonConsecutiveSubjectPeriodsConflict extends ConflictReason {
  final String subjectName;
  final String classroomName;
  final int day;

  const NonConsecutiveSubjectPeriodsConflict(this.subjectName, this.classroomName, this.day);

  @override
  List<Object?> get props => [subjectName, classroomName, day];
}

class TimetableGenerationException implements Exception {
  final List<ConflictReason> reasons;

  TimetableGenerationException(this.reasons);
}
