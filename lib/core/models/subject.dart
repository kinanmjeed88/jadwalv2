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

  /// Constraint: Specific allowed periods for this subject.
  /// If empty, it means there are no constraints and it can be placed anywhere.
  /// Example: [0, 1] means it must be placed in the 1st or 2nd period.
  List<int> allowedPeriods = [];
}
