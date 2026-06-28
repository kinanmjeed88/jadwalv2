import 'package:isar/isar.dart';

part 'teacher.g.dart';

@collection
class Teacher {
  Id id = Isar.autoIncrement;

  late String name;

  late String specialization;

  /// Maximum number of lessons the teacher can teach in a single day
  late int maxLessonsPerDay;

  /// Maximum number of lessons the teacher can teach in a week
  late int maxLessonsPerWeek;

  /// List of integers representing days of the week the teacher is unavailable
  /// (e.g., 0 for Sunday, 1 for Monday, etc.)
  List<int> unavailableDays = [];

  /// List of integers representing allowed periods for this teacher
  List<int> allowedPeriods = [];
}
