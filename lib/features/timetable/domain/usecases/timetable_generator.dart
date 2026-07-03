import '../../../../core/exceptions/unsolvable_timetable_exception.dart';
import '../models/timetable_dto.dart';

class _TimeSlot {
  final int day;
  final int period;
  final int score;

  _TimeSlot(this.day, this.period, this.score);
}

class TimetableGenerator {
  final List<TeacherDto> teachers;
  final List<SubjectDto> subjects;
  final List<ClassroomDto> classrooms;
  final AppSettingsDto settings;
  final List<LessonDto> existingLessons;
  late final Stopwatch _stopwatch;

  // Caches for O(1) lookup
  final Map<int, Set<int>> _teacherScheduleCache = {}; // teacherId -> Set of (day * 100 + period)
  final Map<int, Map<int, int>> _teacherDailyLessons = {}; // teacherId -> {day -> count}
  final Map<int, Set<int>> _classroomScheduleCache = {}; // classroomId -> Set of (day * 100 + period)
  final Map<int, Set<String>> _classroomSubjectCache = {}; // classroomId -> Set of (day_subjectId)

  // Tracking best state
  int _maxAssignedCount = 0;
  List<LessonDto> _bestState = [];

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

    // Clear caches
    _teacherScheduleCache.clear();
    _teacherDailyLessons.clear();
    _classroomScheduleCache.clear();
    _classroomSubjectCache.clear();
    _maxAssignedCount = 0;
    _bestState = [];

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

    // Initialize cache with pinned lessons
    for (var lesson in pinnedLessons) {
      if (lesson.dayIndex != null && lesson.periodIndex != null) {
        _addToCache(lesson, lesson.dayIndex!, lesson.periodIndex!);
      }
    }

    bool success = _backtrack(unpinnedLessons, 0, currentAssignment, maxDays, maxPeriods);

    _stopwatch.stop();

    if (success) {
      return currentAssignment;
    } else {
      // Restore the best partial assignment found before timeout
      List<LessonDto> fallbackAssignment = List.from(_bestState);

      // Rebuild caches for the best state
      _teacherScheduleCache.clear();
      _teacherDailyLessons.clear();
      _classroomScheduleCache.clear();
      _classroomSubjectCache.clear();
      for (var l in fallbackAssignment) {
        if (l.dayIndex != null && l.periodIndex != null) {
          _addToCache(l, l.dayIndex!, l.periodIndex!);
        }
      }

      // Post-Redistribution Phase & Fallback
      for (var unpinned in unpinnedLessons) {
        if (!fallbackAssignment.any((assigned) => assigned.id == unpinned.id)) {

          // Phase 1: Try Swapping/Redistribution
          bool swapped = _tryRedistribution(unpinned, fallbackAssignment, maxDays, maxPeriods);
          if (swapped) continue;

          // Phase 2: Ultimate Fallback -> Temporarily set teacher to null to bypass constraints

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

  int _scoreTimeSlot(LessonDto lesson, int day, int period, int maxPeriods) {
    int score = 0;

    if (lesson.teacher == null) return 0;
    int tId = lesson.teacher!.id;

    // Check for isolated periods (gaps) and consecutive lessons
    bool hasLessonBefore = period > 0 && (_teacherScheduleCache[tId]?.contains(day * 100 + (period - 1)) ?? false);
    bool hasLessonAfter = period < maxPeriods - 1 && (_teacherScheduleCache[tId]?.contains(day * 100 + (period + 1)) ?? false);

    if (hasLessonBefore || hasLessonAfter) {
      score += 10; // Rewards contiguous blocks
    } else {
      score -= 5; // Penalizes isolated periods
    }

    // Penalize long consecutive chains (more than 2 contiguous lessons already)
    if (hasLessonBefore) {
      bool hasLessonTwoBefore = period > 1 && (_teacherScheduleCache[tId]?.contains(day * 100 + (period - 2)) ?? false);
      if (hasLessonTwoBefore) {
        score -= 15; // Strong penalty for 3+ consecutive lessons
      }
    }

    return score;
  }

  bool _tryRedistribution(LessonDto lesson, List<LessonDto> currentAssignment, int maxDays, int maxPeriods) {
    if (lesson.teacher == null) return false;

    // Try to find an existing assigned lesson that we can swap out
    // to make room for this current unassigned lesson.
    for (int i = 0; i < currentAssignment.length; i++) {
      var assignedLesson = currentAssignment[i];

      // Skip pinned lessons or lessons from different classrooms/subjects if not relevant
      if (assignedLesson.isPinned) continue;

      int oldDay = assignedLesson.dayIndex!;
      int oldPeriod = assignedLesson.periodIndex!;

      // Remove assignedLesson temporarily
      _removeFromCache(assignedLesson, oldDay, oldPeriod);
      currentAssignment.removeAt(i);
      assignedLesson.dayIndex = null;
      assignedLesson.periodIndex = null;

      // Check if removing it makes room for our target 'lesson'
      bool placedLesson = false;
      int? targetDay;
      int? targetPeriod;

      for (int d = 0; d < maxDays && !placedLesson; d++) {
        for (int p = 0; p < maxPeriods && !placedLesson; p++) {
          if (_isValidPlacement(lesson, d, p)) {
            targetDay = d;
            targetPeriod = p;
            placedLesson = true;
          }
        }
      }

      if (placedLesson) {
        lesson.dayIndex = targetDay;
        lesson.periodIndex = targetPeriod;
        _addToCache(lesson, targetDay!, targetPeriod!);
        currentAssignment.add(lesson);

        // Now try to find a new spot for the previously assignedLesson
        bool placedAssigned = false;
        for (int d = 0; d < maxDays && !placedAssigned; d++) {
          for (int p = 0; p < maxPeriods && !placedAssigned; p++) {
            if (_isValidPlacement(assignedLesson, d, p)) {
              assignedLesson.dayIndex = d;
              assignedLesson.periodIndex = p;
              _addToCache(assignedLesson, d, p);
              currentAssignment.add(assignedLesson);
              placedAssigned = true;
            }
          }
        }

        if (placedAssigned) {
          return true; // Redistribution successful
        }

        // If we couldn't place assignedLesson, revert changes
        _removeFromCache(lesson, targetDay, targetPeriod);
        currentAssignment.removeLast(); // removes 'lesson'
        lesson.dayIndex = null;
        lesson.periodIndex = null;
      }

      // Revert removal of assignedLesson
      assignedLesson.dayIndex = oldDay;
      assignedLesson.periodIndex = oldPeriod;
      _addToCache(assignedLesson, oldDay, oldPeriod);
      currentAssignment.insert(i, assignedLesson);
    }

    return false;
  }

  bool _backtrack(List<LessonDto> unpinnedLessons, int index, List<LessonDto> currentAssignment, int maxDays, int maxPeriods) {
    // Track best state in case of failure/timeout
    if (index > _maxAssignedCount) {
      _maxAssignedCount = index;
      _bestState = List.from(currentAssignment.map((l) => LessonDto(
        id: l.id,
        teacher: l.teacher,
        subject: l.subject,
        classroom: l.classroom,
        dayIndex: l.dayIndex,
        periodIndex: l.periodIndex,
        isPinned: l.isPinned,
      )));
    }

    // Failsafe: Timeout after 10 seconds
    if (_stopwatch.elapsedMilliseconds > 10000) {
      return false; // Return false instead of throwing to use Fallback
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

    List<_TimeSlot> validSlots = [];

    for (int day = 0; day < maxDays; day++) {
      if (lesson.teacher != null && lesson.teacher!.unavailableDays.contains(day)) {
        continue;
      }

      for (int period in periodOrder) {
        if (_isValidPlacement(lesson, day, period)) {
          int score = _scoreTimeSlot(lesson, day, period, maxPeriods);
          validSlots.add(_TimeSlot(day, period, score));
        }
      }
    }

    // Sort slots by score descending
    validSlots.sort((a, b) => b.score.compareTo(a.score));

    for (var slot in validSlots) {
      int day = slot.day;
      int period = slot.period;

      lesson.dayIndex = day;
      lesson.periodIndex = period;
      currentAssignment.add(lesson);
      _addToCache(lesson, day, period);

      if (_backtrack(unpinnedLessons, index + 1, currentAssignment, maxDays, maxPeriods)) {
        return true;
      }

      // Backtrack
      _removeFromCache(lesson, day, period);
      currentAssignment.removeLast();
      lesson.dayIndex = null;
      lesson.periodIndex = null;
    }

    return false; // Could not place this lesson
  }

  bool _isValidPlacement(LessonDto lesson, int day, int period) {
    int timeKey = day * 100 + period;

    // 1. Teacher conflict (same period)
    if (lesson.teacher != null) {
      if (_teacherScheduleCache[lesson.teacher!.id]?.contains(timeKey) ?? false) {
        return false;
      }
    }

    // 2. Classroom conflict (same period)
    if (lesson.classroom != null) {
      if (_classroomScheduleCache[lesson.classroom!.id]?.contains(timeKey) ?? false) {
        return false;
      }
    }

    // 3. Teacher daily limit
    if (lesson.teacher != null) {
      int teacherLessonsToday = _teacherDailyLessons[lesson.teacher!.id]?[day] ?? 0;
      if (teacherLessonsToday >= lesson.teacher!.maxLessonsPerDay) {
        return false;
      }
    }

    // 4. Same subject on the same day for a classroom
    if (lesson.classroom != null && lesson.subject != null) {
      String subjectKey = "${day}_${lesson.subject!.id}";
      if (_classroomSubjectCache[lesson.classroom!.id]?.contains(subjectKey) ?? false) {
        return false;
      }
    }

    return true;
  }

  void _addToCache(LessonDto lesson, int day, int period) {
    int timeKey = day * 100 + period;

    if (lesson.teacher != null) {
      int tId = lesson.teacher!.id;
      _teacherScheduleCache.putIfAbsent(tId, () => {}).add(timeKey);
      _teacherDailyLessons.putIfAbsent(tId, () => {});
      _teacherDailyLessons[tId]![day] = (_teacherDailyLessons[tId]![day] ?? 0) + 1;
    }

    if (lesson.classroom != null) {
      int cId = lesson.classroom!.id;
      _classroomScheduleCache.putIfAbsent(cId, () => {}).add(timeKey);

      if (lesson.subject != null) {
        String subjectKey = "${day}_${lesson.subject!.id}";
        _classroomSubjectCache.putIfAbsent(cId, () => {}).add(subjectKey);
      }
    }
  }

  void _removeFromCache(LessonDto lesson, int day, int period) {
    int timeKey = day * 100 + period;

    if (lesson.teacher != null) {
      int tId = lesson.teacher!.id;
      _teacherScheduleCache[tId]?.remove(timeKey);
      if (_teacherDailyLessons[tId] != null && _teacherDailyLessons[tId]![day] != null) {
        _teacherDailyLessons[tId]![day] = _teacherDailyLessons[tId]![day]! - 1;
      }
    }

    if (lesson.classroom != null) {
      int cId = lesson.classroom!.id;
      _classroomScheduleCache[cId]?.remove(timeKey);

      if (lesson.subject != null) {
        String subjectKey = "${day}_${lesson.subject!.id}";
        _classroomSubjectCache[cId]?.remove(subjectKey);
      }
    }
  }
}
