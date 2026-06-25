import 'package:isar/isar.dart';

part 'subject.g.dart';

@collection
class Subject {
  Id id = Isar.autoIncrement;

  late String name;

  /// Number of lessons per week required for each class
  late int lessonsPerWeek;

  /// If true, the algorithm should prioritize placing these lessons
  /// in the early periods of the day (e.g., Mathematics, Physics)
  bool preferEarlyPeriods = false;
}
