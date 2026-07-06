import '../models/subject.dart';

class SubjectEntity {
  final int id;
  final String name;
  final int lessonsPerWeek;
  final bool preferEarlyPeriods;
  final List<int> allowedPeriods;

  SubjectEntity({
    required this.id,
    required this.name,
    required this.lessonsPerWeek,
    required this.preferEarlyPeriods,
    required this.allowedPeriods,
  });

  factory SubjectEntity.fromIsar(Subject subject) {
    return SubjectEntity(
      id: subject.id,
      name: subject.name,
      lessonsPerWeek: subject.lessonsPerWeek,
      preferEarlyPeriods: subject.preferEarlyPeriods,
      allowedPeriods: List.from(subject.allowedPeriods),
    );
  }
}
