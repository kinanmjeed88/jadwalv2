import '../models/settings.dart';

class AppSettingsEntity {
  final int periodsPerDay;
  final int daysPerWeek;
  final String schoolName;
  final String principalName;
  final String exportPageSize;
  final String exportOrientation;
  final bool exportAutoScale;
  final double? customPageWidth;
  final double? customPageHeight;

  AppSettingsEntity({
    required this.periodsPerDay,
    required this.daysPerWeek,
    required this.schoolName,
    required this.principalName,
    required this.exportPageSize,
    required this.exportOrientation,
    required this.exportAutoScale,
    this.customPageWidth,
    this.customPageHeight,
  });

  factory AppSettingsEntity.fromIsar(AppSettings settings) {
    return AppSettingsEntity(
      periodsPerDay: settings.periodsPerDay,
      daysPerWeek: settings.daysPerWeek,
      schoolName: settings.schoolName,
      principalName: settings.principalName,
      exportPageSize: settings.exportPageSize,
      exportOrientation: settings.exportOrientation,
      exportAutoScale: settings.exportAutoScale,
      customPageWidth: settings.customPageWidth,
      customPageHeight: settings.customPageHeight,
    );
  }
}
