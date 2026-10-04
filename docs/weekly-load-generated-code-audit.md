# Classroom generated-code audit

Scope: `classroom.dart` and `classroom.g.dart` at 7591c6d, unchanged by this audit.

- `weeklyLessonsOverride`: nullable Dart int; Isar long; writer.writeLong and
  reader.readLongOrNull at offset 3; deserializeProp case 3 matches.
- `dailyPeriodsOverride`: nullable List<int> (non-null elements); Isar longList;
  writer.writeLongList and reader.readLongList at offset 0; deserializeProp case
  0 matches. Size estimator includes 3 bytes plus 8 bytes per element.
- Existing grade/name use offsets 1/2 consistently in serializer, deserializer,
  property reader and size estimator. Query helpers address properties by name.
- Collection name, collection ID, object ID and attach behavior are unchanged.
- Computed hasWeeklyOverride/weeklyOverride are ignored, not persisted twice.
- The real old-schema database reopen/edit/reopen test verifies persistence and
  null defaults, not merely JSON conversion.

The file is **not a complete fresh generator output**: filter/sort/distinct/
property query helpers for the two new fields are absent. Production code reads
and writes those fields on Classroom objects and does not call query helpers for
these fields (verified by source search). This does not affect the collection
schema or serialization; no generated change is required for existing usage.
A future feature querying these properties should regenerate with the project's
compatible generator toolchain. No build_runner step was added to CI, and no
schema/generated file was changed during this audit.
