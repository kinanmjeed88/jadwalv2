# Weekday identity stabilization

Baseline: b803ee2323523c359f4c75cc33b0c36dd3f07c65.

## Canonical persisted mapping

`Weekday` in `lib/core/models/weekly_load_policy.dart` remains unchanged:
0 Sunday / الأحد, 1 Monday / الإثنين, 2 Tuesday / الثلاثاء,
3 Wednesday / الأربعاء, 4 Thursday / الخميس, 5 Friday / الجمعة,
6 Saturday / السبت. Six working days are Sunday–Friday; seven add Saturday.

## Consumer audit

- Classroom custom-day chips and preview already use `Weekday.workingDays`,
  `indexPosition`, and `arabicLabel`; no remapping needed.
- `DailyDistribution` and `EffectiveWeeklyConfig.weekdayPeriods` already use
  the same enum for index ↔ weekday conversion.
- Both timetable views, both PDF table layouts, and Excel now use
  `timetableDayLabels` in the existing shared display utility. It delegates to
  `Weekday.workingDays`, eliminating the swapped Friday/Saturday arrays.
- Teacher availability now uses Weekday too, including six/seven-day settings;
  saved unavailable-day values remain unchanged. Previously the UI only named
  the first five days.
- Lessons, teacher availability, generator, prevalidation, smart repair,
  interaction index, and backup/restore store/use integer indices without any
  independent Friday/Saturday conversion. No persistence or scheduling rewrite.
- The unused `AppConstants.daysOfWeek` is a historical five-day constant whose
  labels agree with the first five canonical days. It has no production callers;
  its public const API is preserved, not repurposed as a configurable calendar.
- Tracked `.dart.orig` files are historical backups, not compiled Dart sources;
  their five-day lists were not edited.

## Regression coverage

- Fixed literal expectations for all seven indices, especially Friday=5 and
  Saturday=6, independent of the enum under test.
- Shared UI/PDF/Excel adapter checked for six and seven working days.
- Friday/Saturday extra-day customization checked through effective config,
  index/map round-trip, classroom DTO and interaction capacity and detail labels.
- Wiring guard ensures all three renderers consume the tested adapter and do
  not reintroduce private Friday/Saturday label arrays.
- Actual XLSX generation and decoding from persisted Isar classroom/lesson data
  checks lesson cells against literal day headings for six and seven days.
- Existing uniform30 SmartAutoFix behavior and legacy Isar upgrade tests remain
  unchanged. No Isar schema or generated production file changed in this fix.

The unrelated First Run wording change was reverted to «أو حذفها».
