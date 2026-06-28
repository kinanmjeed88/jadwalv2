import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';

class TimetableGenerator {
  final List<Teacher> teachers;
  final List<Subject> subjects;
  final List<Classroom> classrooms;
  final AppSettings settings;
  final List<Lesson>
      existingLessons; // Kept for any pre-assigned lessons if needed

  TimetableGenerator({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
  });

  /// Generates the timetable and returns a list of lessons.
  List<Lesson> generate() {
    int maxDays = settings.daysPerWeek;
    int maxPeriods = settings.periodsPerDay;

    // Use existing lessons as the pool. Reset their day and period indexes.
    List<Lesson> pool = List.from(existingLessons);
    for (var l in pool) {
      l.dayIndex = null;
      l.periodIndex = null;
    }

    List<Lesson> generatedLessons = [];

    for (var lesson in pool) {
      bool placed = false;

      List<int> periodOrder = List.generate(maxPeriods, (index) => index);
      if (lesson.subject.value?.preferEarlyPeriods ?? false) {
        // Prefer periods 0, 1
        periodOrder =
            [0, 1, 2, 3, 4, 5, 6, 7].where((p) => p < maxPeriods).toList();
      }

      // Filter periodOrder by allowedPeriods if constraints exist
      if (lesson.subject.value != null &&
          lesson.subject.value!.allowedPeriods.isNotEmpty) {
        periodOrder = periodOrder
            .where((p) => lesson.subject.value!.allowedPeriods.contains(p))
            .toList();
      }

      // Hard constraint: Filter periodOrder by Teacher's allowedPeriods
      if (lesson.teacher.value != null &&
          lesson.teacher.value!.allowedPeriods.isNotEmpty) {
        periodOrder = periodOrder
            .where((p) => lesson.teacher.value!.allowedPeriods.contains(p))
            .toList();
      }

      for (int day = 0; day < maxDays; day++) {
        if (placed) break;

        // Check teacher unavailability
        if (lesson.teacher.value != null &&
            lesson.teacher.value!.unavailableDays.contains(day)) {
          continue;
        }

        // Check teacher daily limit
        int teacherLessonsToday = generatedLessons
            .where((l) =>
                l.teacher.value?.id == lesson.teacher.value?.id &&
                l.dayIndex == day)
            .length;

        if (lesson.teacher.value != null &&
            teacherLessonsToday >= lesson.teacher.value!.maxLessonsPerDay) {
          continue;
        }

        // HARD CONSTRAINT: Prevent multiple lessons of the same subject on the same day for a classroom
        // Unless we explicitly support double-periods, which we don't handle here yet.
        bool subjectAlreadyOnDay = generatedLessons.any((l) =>
            l.classroom.value?.id == lesson.classroom.value?.id &&
            l.subject.value?.id == lesson.subject.value?.id &&
            l.dayIndex == day);
        if (subjectAlreadyOnDay) {
          continue;
        }

        for (int period in periodOrder) {
          // Check teacher conflict
          bool teacherConflict = lesson.teacher.value != null &&
              generatedLessons.any((l) =>
                  l.teacher.value?.id == lesson.teacher.value?.id &&
                  l.dayIndex == day &&
                  l.periodIndex == period);

          // Check classroom conflict
          bool classroomConflict = generatedLessons.any((l) =>
              l.classroom.value?.id == lesson.classroom.value?.id &&
              l.dayIndex == day &&
              l.periodIndex == period);

          if (!teacherConflict && !classroomConflict) {
            lesson.dayIndex = day;
            lesson.periodIndex = period;
            placed = true;
            break;
          }
        }
      }

      generatedLessons.add(lesson);
    }

    return generatedLessons;
  }
}
