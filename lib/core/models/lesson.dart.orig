import 'package:isar/isar.dart';
import 'teacher.dart';
import 'subject.dart';
import 'classroom.dart';

part 'lesson.g.dart';

@collection
class Lesson {
  Id id = Isar.autoIncrement;

  final teacher = IsarLink<Teacher>();
  final subject = IsarLink<Subject>();
  final classroom = IsarLink<Classroom>();

  /// Day of the week (0 = Sunday, 4 = Thursday)
  /// If null, the lesson is unassigned
  int? dayIndex;

  /// Period number (e.g., 1 for first period, 2 for second)
  /// If null, the lesson is unassigned
  int? periodIndex;

  /// True if the lesson could not be assigned by the algorithm
  bool get isUnassigned => dayIndex == null || periodIndex == null;
}
