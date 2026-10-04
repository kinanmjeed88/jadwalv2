import '../models/weekly_load_policy.dart';
import 'string_utils.dart';

/// Fallback used when a lesson's display value is missing.
const String timetableDisplayFallback = '-';

/// Canonical day-index labels shared by timetable UI, PDF and Excel.
/// Keep the persisted Sunday-first indices defined by [Weekday].
List<String> timetableDayLabels(int daysPerWeek) => List<String>.unmodifiable(
      Weekday.workingDays(daysPerWeek).map((day) => day.arabicLabel),
    );

/// Returns a safe, trimmed display value for a timetable cell segment.
String normalizeTimetableDisplayValue(
  String? value, {
  String fallback = timetableDisplayFallback,
}) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

/// Returns the first visible name token while handling null and whitespace safely.
String firstTimetableName(
  String? fullName, {
  String fallback = timetableDisplayFallback,
}) {
  final normalized = fullName?.trim() ?? '';
  if (normalized.isEmpty) return fallback;

  return normalized.split(RegExp(r'\s+')).first;
}

/// Returns the canonical subject display value used by every renderer.
String timetableSubjectDisplayName(String? subjectName) {
  return normalizeTimetableDisplayValue(
    (subjectName ?? '').cleanSubjectName(),
  );
}

/// Builds the single-line label shared by the UI, PDF, and Excel renderers.
///
/// The subject is cleaned using the existing subject-name rule. The companion
/// value can be a teacher name for a classroom timetable or a classroom name
/// for a teacher timetable.
String formatTimetableCellLabel({
  required String? subjectName,
  required String? companionName,
}) {
  final subject = timetableSubjectDisplayName(subjectName);
  final companion = normalizeTimetableDisplayValue(companionName);
  return '$subject | $companion';
}
