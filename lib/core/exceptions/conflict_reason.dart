import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';

@immutable
sealed class ConflictReason extends Equatable {
  const ConflictReason();
}

class TeacherLoadExceeded extends ConflictReason {
  final String teacherName;
  final int currentLoad;
  final int maxLoad;

  const TeacherLoadExceeded(this.teacherName, this.currentLoad, this.maxLoad);

  @override
  List<Object> get props => [teacherName, currentLoad, maxLoad];
}

class InsufficientDaysForSubject extends ConflictReason {
  final String subjectName;
  final int requiredLessons;
  final int availableDays;

  const InsufficientDaysForSubject(this.subjectName, this.requiredLessons, this.availableDays);

  @override
  List<Object> get props => [subjectName, requiredLessons, availableDays];
}

class TeacherTimeSlotConflict extends ConflictReason {
  final String teacherName;
  final int day;
  final int period;

  const TeacherTimeSlotConflict(this.teacherName, this.day, this.period);

  @override
  List<Object> get props => [teacherName, day, period];
}

class UnassignedSubject extends ConflictReason {
  final String subjectName;
  final String details;

  const UnassignedSubject(this.subjectName, this.details);

  @override
  List<Object> get props => [subjectName, details];
}

class GenericSolverFailure extends ConflictReason {
  final String details;

  const GenericSolverFailure(this.details);

  @override
  List<Object> get props => [details];
}
