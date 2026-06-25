import 'package:isar/isar.dart';

part 'settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  /// Default number of periods per day (e.g., 7)
  late int periodsPerDay;

  /// Number of days in the week (typically 5 for Sun-Thu)
  int daysPerWeek = 5;
}
