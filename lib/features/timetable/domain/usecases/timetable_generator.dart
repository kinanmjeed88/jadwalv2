import '../../../../core/exceptions/unsolvable_timetable_exception.dart';
import '../models/timetable_dto.dart';

class TimetableGenerator {
  final List<TeacherDto> teachers;
  final List<SubjectDto> subjects;
  final List<ClassroomDto> classrooms;
  final AppSettingsDto settings;
  final List<LessonDto> existingLessons;
  late final Stopwatch _stopwatch;

  TimetableGenerator({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
  });

  /// Generates the timetable and returns a list of lessons.
  List<LessonDto> generate() {
    _stopwatch = Stopwatch()..start();

    int maxDays = settings.daysPerWeek;
    int maxPeriods = settings.periodsPerDay;

    // Use existing lessons as the pool.
    List<LessonDto> pool = List.from(existingLessons);
    List<LessonDto> unpinnedLessons = [];
    List<LessonDto> pinnedLessons = [];

    // Separate pinned and unpinned lessons. Also reset unpinned ones.
    for (var l in pool) {
      if (l.isPinned && l.dayIndex != null && l.periodIndex != null) {
        pinnedLessons.add(l);
      } else {
        l.dayIndex = null;
        l.periodIndex = null;
        unpinnedLessons.add(l);
      }
    }

    // Sort unpinned lessons using Minimum Remaining Values (MRV) heuristic.
    // Hard-to-place lessons first.
    unpinnedLessons.sort((a, b) {
      int scoreA = _calculateConstraintScore(a, maxDays, maxPeriods);
      int scoreB = _calculateConstraintScore(b, maxDays, maxPeriods);
      // Lower score means fewer remaining values -> harder to place.
      return scoreA.compareTo(scoreB);
    });

    List<LessonDto> currentAssignment = List.from(pinnedLessons);

    bool success = _backtrack(unpinnedLessons, 0, currentAssignment, maxDays, maxPeriods);

    _stopwatch.stop();

    if (success) {
      return currentAssignment;
    } else {
      // Fallback: For unassigned lessons, attempt to place them temporally with teacher = null
      List<LessonDto> fallbackAssignment = List.from(currentAssignment);
      for (var unpinned in unpinnedLessons) {
        if (!fallbackAssignment.any((assigned) => assigned.id == unpinned.id)) {
          // Temporarily set teacher to null to bypass teacher constraints

          unpinned.teacher = null;

          bool placedTemporally = false;
          // Find first available slot where classroom doesn't have a conflict
          for (int d = 0; d < maxDays && !placedTemporally; d++) {
            for (int p = 0; p < maxPeriods && !placedTemporally; p++) {
              bool classroomBusy = fallbackAssignment.any((l) => l.classroom?.id == unpinned.classroom?.id && l.dayIndex == d && l.periodIndex == p);
              bool subjectAlreadyOnDay = fallbackAssignment.any((l) => l.classroom?.id == unpinned.classroom?.id && l.subject?.id == unpinned.subject?.id && l.dayIndex == d);

              if (!classroomBusy && !subjectAlreadyOnDay) {
                unpinned.dayIndex = d;
                unpinned.periodIndex = p;
                placedTemporally = true;
              }
            }
          }

          if (!placedTemporally) {
            unpinned.dayIndex = null;
            unpinned.periodIndex = null;
          }

          fallbackAssignment.add(unpinned);
        }
      }
      return fallbackAssignment;
    }
  }

  int _calculateConstraintScore(LessonDto lesson, int maxDays, int maxPeriods) {
    int score = maxDays * maxPeriods;

    // Teacher unavailable days
    if (lesson.teacher != null) {
      score -= (lesson.teacher!.unavailableDays.length * maxPeriods).toInt();
    }

    // Subject allowed periods
    if (lesson.subject != null && lesson.subject!.allowedPeriods.isNotEmpty) {
      int restrictedPeriods = maxPeriods - lesson.subject!.allowedPeriods.where((p) => p < maxPeriods).length;
      score -= (maxDays * restrictedPeriods).toInt();
    }

    // Teacher allowed periods
    if (lesson.teacher != null && lesson.teacher!.allowedPeriods.isNotEmpty) {
      int restrictedPeriods = maxPeriods - lesson.teacher!.allowedPeriods.where((p) => p < maxPeriods).length;
      score -= (maxDays * restrictedPeriods).toInt();
    }

    // Teacher max lessons per week constraint
    if (lesson.teacher != null) {
      // If teacher has low maxLessonsPerWeek relative to what they teach, they are restricted
      score += (lesson.teacher!.maxLessonsPerWeek).toInt();
    }

    return score;
  }

  bool _backtrack(List<LessonDto> unpinnedLessons, int index, List<LessonDto> currentAssignment, int maxDays, int maxPeriods) {
    // Failsafe: Timeout after 10 seconds
    if (_stopwatch.elapsedMilliseconds > 10000) {
      throw UnsolvableTimetableException('انتهى الوقت (Timeout) المخصص لحل الجدول. يرجى تخفيف القيود.');
    }

    if (index >= unpinnedLessons.length) {
      return true; // All lessons placed
    }

    LessonDto lesson = unpinnedLessons[index];

    List<int> periodOrder = List.generate(maxPeriods, (i) => i);
    if (lesson.subject?.preferEarlyPeriods ?? false) {
      periodOrder = [0, 1, 2, 3, 4, 5, 6, 7].where((p) => p < maxPeriods).toList();
    }

    if (lesson.subject != null && lesson.subject!.allowedPeriods.isNotEmpty) {
      periodOrder = periodOrder.where((p) => lesson.subject!.allowedPeriods.contains(p)).toList();
    }

    if (lesson.teacher != null && lesson.teacher!.allowedPeriods.isNotEmpty) {
      periodOrder = periodOrder.where((p) => lesson.teacher!.allowedPeriods.contains(p)).toList();
    }

    for (int day = 0; day < maxDays; day++) {
      if (lesson.teacher != null && lesson.teacher!.unavailableDays.contains(day)) {
        continue;
      }

      for (int period in periodOrder) {
        if (_isValidPlacement(lesson, day, period, currentAssignment)) {
          lesson.dayIndex = day;
          lesson.periodIndex = period;
          currentAssignment.add(lesson);

          if (_backtrack(unpinnedLessons, index + 1, currentAssignment, maxDays, maxPeriods)) {
            return true;
          }

          // Backtrack
          currentAssignment.removeLast();
          lesson.dayIndex = null;
          lesson.periodIndex = null;
        }
      }
    }

    return false; // Could not place this lesson
  }

  bool _isValidPlacement(LessonDto lesson, int day, int period, List<LessonDto> currentAssignment) {
    // 1. Teacher conflict (same period)
    bool teacherConflict = lesson.teacher != null && currentAssignment.any((l) =>
        l.teacher?.id == lesson.teacher?.id &&
        l.dayIndex == day &&
        l.periodIndex == period);
    if (teacherConflict) return false;

    // 2. Classroom conflict (same period)
    bool classroomConflict = currentAssignment.any((l) =>
        l.classroom?.id == lesson.classroom?.id &&
        l.dayIndex == day &&
        l.periodIndex == period);
    if (classroomConflict) return false;

    // 3. Teacher daily limit
    if (lesson.teacher != null) {
      int teacherLessonsToday = currentAssignment.where((l) =>
          l.teacher?.id == lesson.teacher?.id &&
          l.dayIndex == day).length;
      if (teacherLessonsToday >= lesson.teacher!.maxLessonsPerDay) {
        return false;
      }
    }

    // 4. Same subject on the same day for a classroom
    bool subjectAlreadyOnDay = currentAssignment.any((l) =>
        l.classroom?.id == lesson.classroom?.id &&
        l.subject?.id == lesson.subject?.id &&
        l.dayIndex == day);
    if (subjectAlreadyOnDay) return false;

    return true;
  }
}
