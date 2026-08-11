1.  **Update Database Layer (Isar):**
    *   Create a new collection `SubjectConstraint` to store per-grade, per-subject daily constraints (`maxPeriodsPerDay`).
    *   Update `database_provider.dart` to open the database with the new schema.
    *   Create entity and mapper classes for `SubjectConstraint` (`SubjectConstraintEntity`).
    *   Run `build_runner` to generate Isar boilerplate.
2.  **Update Timetable Generator Engine:**
    *   Inject `subjectConstraints` into `TimetableGenerator`.
    *   Update `_calculateCost` to apply dynamic maximum period constraints based on the new configurations. Add soft constraints to prioritize consecutive periods for duplicated subjects in the same day.
    *   Update `_getConflicts` to respect dynamic constraints instead of the strict one-per-day rule.
3.  **Update Pre-Validation Engine:**
    *   Update `PreValidationEngine` to accept `subjectConstraints`.
    *   Add validation to catch "mathematical impossibilities" early: e.g., if total weekly lessons assigned for a subject exceed `maxPeriodsPerDay * daysPerWeek`.
4.  **Update Timetable State & Provider:**
    *   Inject constraints into the isolate generator payload.
    *   Update manual swap and move validations (`moveLessonToEmpty`, `swapLessons`) in `timetable_provider.dart` to check against dynamic subject daily limits rather than the strict single period per day constraint.
5.  **Update Management UI:**
    *   Create a new UI page `SubjectConstraintsPage` allowing users to configure constraints by grade and subject.
    *   Add a tab in `ManagementPage` to route to the newly created constraints configuration page.
6.  **Pre-commit & Tests:**
    *   Write a unit test for `PreValidationEngine` verifying the new max constraint validation.
    *   Run all tests, including generator tests, to assure stability and backward compatibility.
    *   Follow `pre_commit_instructions` and finalize the solution.
