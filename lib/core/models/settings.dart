import 'package:isar/isar.dart';

part 'settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  /// Default number of periods per day (e.g., 7)
  late int periodsPerDay;

  /// Number of days in the week (typically 5 for Sun-Thu)
  int daysPerWeek = 5;

  /// Page size for PDF export (e.g., "A4", "A3", "Custom")
  String exportPageSize = "A4";

  /// Orientation for PDF export (e.g., "Portrait", "Landscape")
  String exportOrientation = "Landscape";

  /// If true, the table auto-scales to fit the page during export
  bool exportAutoScale = true;
}
