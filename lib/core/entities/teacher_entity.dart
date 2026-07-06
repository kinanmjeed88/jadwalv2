import '../models/teacher.dart';

class TeacherEntity {
  final int id;
  final String name;
  final String specialization;
  final int maxLessonsPerDay;
  final int maxLessonsPerWeek;
  final List<int> unavailableDays;
  final List<int> allowedPeriods;

  TeacherEntity({
    required this.id,
    required this.name,
    required this.specialization,
    required this.maxLessonsPerDay,
    required this.maxLessonsPerWeek,
    required this.unavailableDays,
    required this.allowedPeriods,
  });

  factory TeacherEntity.fromIsar(Teacher teacher) {
    return TeacherEntity(
      id: teacher.id,
      name: teacher.name,
      specialization: teacher.specialization,
      maxLessonsPerDay: teacher.maxLessonsPerDay,
      maxLessonsPerWeek: teacher.maxLessonsPerWeek,
      unavailableDays: List.from(teacher.unavailableDays),
      allowedPeriods: List.from(teacher.allowedPeriods),
    );
  }
}
