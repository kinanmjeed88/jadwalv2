import '../models/subject_constraint.dart';

class SubjectConstraintEntity {
  final String grade;
  final String subjectName;
  final int maxPeriodsPerDay;

  SubjectConstraintEntity({
    required this.grade,
    required this.subjectName,
    required this.maxPeriodsPerDay,
  });

  factory SubjectConstraintEntity.fromIsar(SubjectConstraint constraint) {
    return SubjectConstraintEntity(
      grade: constraint.grade,
      subjectName: constraint.subjectName,
      maxPeriodsPerDay: constraint.maxPeriodsPerDay,
    );
  }
}
