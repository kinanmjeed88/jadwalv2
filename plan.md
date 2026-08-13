1. **Domain Layer:**
   - Delete `UnsolvableTimetableException`.
   - Create `TimetableGenerationException` and `ConflictReason` sealed class as specified with exclusive sub-types.
2. **Generators & Validations:**
   - Modify `PreValidationEngine` to collect errors, construct the `ConflictReason` models, and throw `TimetableGenerationException` when validation fails. Ensure all checks run to gather all errors (Collect-All).
   - Modify `TimetableGenerator`'s `_getConflicts` to return `List<ConflictReason>`, then update `generate()` to throw `TimetableGenerationException` populated with those reasons.
3. **Presentation Layer:**
   - Create `ConflictMessageMapper` class in presentation to map `ConflictReason` objects to localized Arabic Strings.
   - Update `timetable_page.dart` inside the `catch` block (and ONLY inside the catch block) to build an `AlertDialog` using `ConstrainedBox` (maxHeight 60% of screen height) containing a `SingleChildScrollView` displaying errors translated by `ConflictMessageMapper` as bullet points.
4. **Testing:**
   - Create tests for `ConflictMessageMapper`.
   - Create tests for `PreValidationEngine` ensuring `Collect-All` behavior is preserved and it maps errors to correct `ConflictReason` sub-types.
5. **Clean up & Pre-commit check:**
   - Ensure `flutter analyze` and `flutter test` pass before proceeding to submission.
