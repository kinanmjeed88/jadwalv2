import '../models/classroom.dart';

class ClassroomEntity {
  final int id;
  final String name;
  final String grade;

  ClassroomEntity({
    required this.id,
    required this.name,
    required this.grade,
  });

  factory ClassroomEntity.fromIsar(Classroom classroom) {
    return ClassroomEntity(
      id: classroom.id,
      name: classroom.name,
      grade: classroom.grade,
    );
  }
}
