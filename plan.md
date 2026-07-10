1. **Validation Layer Implementation**:
   - Create `lib/features/timetable/domain/usecases/pre_validation_engine.dart` containing `PreValidationEngine` class.
   - Inject `List<LessonEntity> lessons`, `List<TeacherEntity> teachers`, `List<ClassroomEntity> classrooms`, `AppSettingsEntity settings`.
   - Method `List<String> validateAll()` returns a list of specific Arabic error messages (Classroom Capacity & Teacher Capacity).
   - If `validateAll()` returns non-empty list, we join errors and throw `UnsolvableTimetableException(errors.join('\n\n'))`.

2. **Integration in Generator**:
   - In `timetable_generator.dart`, remove the current inline `_validateInputsBeforeGeneration`.
   - Call `PreValidationEngine(teachers: teachers, classrooms: classrooms, settings: settings, existingLessons: existingLessons).validateAll()`.
   - If errors exist, throw `UnsolvableTimetableException`.

3. **Real-Time Assignment Validation in Provider**:
   - In `timetable_provider.dart`, inside `assignLessonsToPool`:
     - Update the teacher capacity check to be more specific and include available days checking.
     - E.g. `maxCapacity = (settings.daysPerWeek - activeUnavailableDays) * teacher.maxLessonsPerDay` and `maxLessonsPerWeek`.
     - Update message: "تحذير: لا يمكن إسناد هذه المادة. المعلم [name] سيصل إلى [X] حصة، مما يتجاوز حده المسموح ([Y] حصة)."
     - Add Classroom real-time check: `int classAssigned = allLessons.where((l) => l.classroom.value?.id == classroom.id).length;`
     - If `classAssigned + subject.lessonsPerWeek > settings.daysPerWeek * settings.periodsPerDay`, return false with message.

4. **Verify and Analyze**:
   - Run `flutter analyze` and `flutter test`.

5. **Submit**.
