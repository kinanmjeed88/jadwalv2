import 'dart:math';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';
import '../../../../core/exceptions/unsolvable_timetable_exception.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';
import 'pre_validation_engine.dart';

class TimetableGenerator {
  final List<TeacherEntity> teachers;
  final List<SubjectEntity> subjects;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;
  final List<LessonEntity> existingLessons;
  final List<SubjectConstraintEntity> subjectConstraints;

  TimetableGenerator({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
    this.subjectConstraints = const [],
  });

  int _getMaxAllowedSubjectPerDay(int subjectId, int classroomId) {
    if (subjectConstraints.isEmpty) return 1;

    final subject = subjects.firstWhere((s) => s.id == subjectId, orElse: () => subjects.first);
    final classroom = classrooms.firstWhere((c) => c.id == classroomId, orElse: () => classrooms.first);

    for (var constraint in subjectConstraints) {
      if (constraint.grade == classroom.grade && constraint.subjectName == subject.name) {
        return constraint.maxPeriodsPerDay;
      }
    }
    return 1;
  }

  void _runPreValidation() {
    final engine = PreValidationEngine(
      existingLessons: existingLessons,
      teachers: teachers,
      classrooms: classrooms,
      settings: settings,
      subjects: subjects,
      subjectConstraints: subjectConstraints,
    );
    final errors = engine.validateAll();
    if (errors.isNotEmpty) {
      throw UnsolvableTimetableException(errors.join('\n\n'));
    }
  }

  /// Generates the timetable using Simulated Annealing (SA)
  List<LessonEntity> generate() {
    _runPreValidation();
    final stopwatch = Stopwatch()..start();
    final random = Random();
    int maxDays = settings.daysPerWeek;
    int maxPeriods = settings.periodsPerDay;

    // Group lessons by classroom
    Map<int, List<LessonEntity>> classroomLessons = {};
    for (var lesson in existingLessons) {
      if (lesson.classroom != null) {
        classroomLessons.putIfAbsent(lesson.classroom!.id, () => []).add(lesson);
      }
    }

    // 1. Initial State Allocation (Greedy/Random Allocation)
    List<LessonEntity> currentSchedule = [];

    for (var classroomId in classroomLessons.keys) {
      var lessons = classroomLessons[classroomId]!;
      List<LessonEntity> unpinned = [];

      // Track occupied slots for this classroom
      Set<int> occupiedSlots = {};

      for (var lesson in lessons) {
        if (lesson.isPinned && lesson.dayIndex != null && lesson.periodIndex != null) {
          currentSchedule.add(lesson);
          occupiedSlots.add(lesson.dayIndex! * 100 + lesson.periodIndex!);
        } else {
          unpinned.add(lesson);
        }
      }

      // Assign unpinned lessons to random available slots to avoid clustering
      List<int> availableSlots = [];
      for (int d = 0; d < maxDays; d++) {
        for (int p = 0; p < maxPeriods; p++) {
          int slot = d * 100 + p;
          if (!occupiedSlots.contains(slot)) {
            availableSlots.add(slot);
          }
        }
      }
      availableSlots.shuffle(random);

      int unpinnedIndex = 0;
      while (unpinnedIndex < unpinned.length && unpinnedIndex < availableSlots.length) {
        var lesson = unpinned[unpinnedIndex];
        int slot = availableSlots[unpinnedIndex];
        lesson.dayIndex = slot ~/ 100;
        lesson.periodIndex = slot % 100;
        currentSchedule.add(lesson);
        unpinnedIndex++;
      }

      // If there are still unpinned lessons (more lessons than slots),
      // place them in (0,0) to prevent data loss (Zero Data Loss constraint).
      while (unpinnedIndex < unpinned.length) {
        var lesson = unpinned[unpinnedIndex];
        lesson.dayIndex = 0;
        lesson.periodIndex = 0;
        currentSchedule.add(lesson);
        unpinnedIndex++;
      }
    }

    // Lessons without a classroom (if any) are added randomly
    var orphanLessons = existingLessons.where((l) => l.classroom == null).toList();
    for (var l in orphanLessons) {
      if (l.isPinned && l.dayIndex != null && l.periodIndex != null) {
        currentSchedule.add(l);
      } else {
        l.dayIndex = random.nextInt(maxDays);
        l.periodIndex = random.nextInt(maxPeriods);
        currentSchedule.add(l);
      }
    }

    // Helper: Clone state
    List<LessonEntity> cloneState(List<LessonEntity> source) {
      return source.map((l) => LessonEntity(
        id: l.id,
        teacher: l.teacher,
        subject: l.subject,
        classroom: l.classroom,
        dayIndex: l.dayIndex,
        periodIndex: l.periodIndex,
        isPinned: l.isPinned,
      )).toList();
    }

    int currentCost = _calculateCost(currentSchedule, maxDays, maxPeriods);
    List<LessonEntity> bestSchedule = cloneState(currentSchedule);
    int bestCost = currentCost;

    // 4. Simulated Annealing Core Loop
    double temp = 5000.0;
    const double coolingRate = 0.999;

    // Stop if temp < 0.1 or approaching 60-second timeout limit
    while (temp >= 0.1 && stopwatch.elapsedMilliseconds < 59000) {
      // If we reach a perfect score, break early
      if (bestCost == 0) {
        break;
      }

      // 3. Neighborhood Function (Move or Swap)
      List<LessonEntity> neighbor = cloneState(currentSchedule);

      // Group neighbor by classroom id to mutate
      Map<int, List<LessonEntity>> neighborClassrooms = {};
      for (var l in neighbor) {
        if (l.classroom != null) {
          neighborClassrooms.putIfAbsent(l.classroom!.id, () => []).add(l);
        }
      }

      // Filter out classrooms with 0 unpinned lessons
      List<int> validClassroomIds = neighborClassrooms.keys.where((id) {
        return neighborClassrooms[id]!.where((l) => !l.isPinned).isNotEmpty;
      }).toList();

      if (validClassroomIds.isNotEmpty) {
        int randomClassroomId = validClassroomIds[random.nextInt(validClassroomIds.length)];
        var classroomLessons = neighborClassrooms[randomClassroomId]!;
        List<LessonEntity> unpinnedClassroomLessons = classroomLessons.where((l) => !l.isPinned).toList();

        // Pick a random unpinned lesson
        LessonEntity targetLesson = unpinnedClassroomLessons[random.nextInt(unpinnedClassroomLessons.length)];

        // Pick a random destination slot
        int newDay = random.nextInt(maxDays);
        int newPeriod = random.nextInt(maxPeriods);

        // Check if destination slot is occupied by another lesson in the SAME classroom
        // We can only swap if it's unpinned.
        var occupyingLessonOpt = classroomLessons.where((l) => l.dayIndex == newDay && l.periodIndex == newPeriod);

        if (occupyingLessonOpt.isNotEmpty) {
          var occupyingLesson = occupyingLessonOpt.first;
          if (!occupyingLesson.isPinned) {
            // Swap
            int? oldDay = targetLesson.dayIndex;
            int? oldPeriod = targetLesson.periodIndex;

            targetLesson.dayIndex = newDay;
            targetLesson.periodIndex = newPeriod;

            occupyingLesson.dayIndex = oldDay;
            occupyingLesson.periodIndex = oldPeriod;
          }
          // If it's pinned, we don't mutate (invalid move, try next iteration)
        } else {
          // Destination is free for this classroom, just move
          targetLesson.dayIndex = newDay;
          targetLesson.periodIndex = newPeriod;
        }
      }

      int neighborCost = _calculateCost(neighbor, maxDays, maxPeriods);
      int deltaCost = neighborCost - currentCost;

      if (deltaCost < 0) {
        // Better state, accept unconditionally
        currentSchedule = neighbor;
        currentCost = neighborCost;
        if (currentCost < bestCost) {
          bestSchedule = cloneState(currentSchedule);
          bestCost = currentCost;
        }
      } else {
        // Worse state, accept with probability
        double p = exp(-deltaCost / temp);
        if (random.nextDouble() < p) {
          currentSchedule = neighbor;
          currentCost = neighborCost;
        }
      }

      temp *= coolingRate;
    }

    stopwatch.stop();
    if (bestCost > 0) {
      List<ConflictReason> conflicts = _getConflicts(bestSchedule, maxDays, maxPeriods);
      throw TimetableGenerationException(conflicts);
    }
    return bestSchedule;
  }

  List<ConflictReason> _getConflicts(List<LessonEntity> state, int maxDays, int maxPeriods) {
    List<ConflictReason> conflicts = [];

    Map<int, Set<int>> teacherSlots = {};
    Map<int, Map<int, int>> teacherDailyCounts = {};
    Map<int, Map<int, Map<int, int>>> classroomDailySubjectsCounts = {};
    Map<int, Map<int, Map<int, List<int>>>> classroomDailySubjectsPeriods = {};
    Map<int, Set<int>> classroomSlots = {};

    for (var lesson in state) {
      if (lesson.dayIndex == null || lesson.periodIndex == null) continue;

      int day = lesson.dayIndex!;
      int period = lesson.periodIndex!;
      int timeKey = day * 100 + period;

      if (lesson.classroom != null) {
        int cId = lesson.classroom!.id;
        if (classroomSlots.containsKey(cId) && classroomSlots[cId]!.contains(timeKey)) {
          conflicts.add(ClassroomTimeSlotConflict(lesson.classroom!.name, day, period));
        } else {
          classroomSlots.putIfAbsent(cId, () => {}).add(timeKey);
        }
      }

      if (lesson.teacher != null) {
        int tId = lesson.teacher!.id;
        String tName = lesson.teacher!.name;

        if (teacherSlots.containsKey(tId) && teacherSlots[tId]!.contains(timeKey)) {
          conflicts.add(TeacherTimeSlotConflict(tName, day, period));
        } else {
          teacherSlots.putIfAbsent(tId, () => {}).add(timeKey);
        }

        teacherDailyCounts.putIfAbsent(tId, () => {});
        teacherDailyCounts[tId]![day] = (teacherDailyCounts[tId]![day] ?? 0) + 1;

        if (teacherDailyCounts[tId]![day]! > lesson.teacher!.maxLessonsPerDay) {
          conflicts.add(TeacherLoadExceeded(tName, teacherDailyCounts[tId]![day]!, lesson.teacher!.maxLessonsPerDay));
        }

        if (lesson.teacher!.unavailableDays.contains(day)) {
          conflicts.add(TeacherUnavailableDayConflict(tName, day));
        }

        if (lesson.teacher!.allowedPeriods.isNotEmpty && !lesson.teacher!.allowedPeriods.contains(period)) {
          conflicts.add(TeacherNotAllowedPeriodConflict(tName, period));
        }
      }

      if (lesson.subject != null && lesson.classroom != null) {
        int sId = lesson.subject!.id;
        int cId = lesson.classroom!.id;
        String sName = lesson.subject!.name;
        String cName = lesson.classroom!.name;

        classroomDailySubjectsCounts.putIfAbsent(cId, () => {});
        classroomDailySubjectsCounts[cId]!.putIfAbsent(day, () => {});

        classroomDailySubjectsPeriods.putIfAbsent(cId, () => {});
        classroomDailySubjectsPeriods[cId]!.putIfAbsent(day, () => {});
        classroomDailySubjectsPeriods[cId]![day]!.putIfAbsent(sId, () => []);

        int maxAllowed = _getMaxAllowedSubjectPerDay(sId, cId);
        int currentCount = classroomDailySubjectsCounts[cId]![day]![sId] ?? 0;

        if (currentCount >= maxAllowed) {
          conflicts.add(SubjectMaxPerDayExceeded(sName, cName, day, maxAllowed, currentCount + 1));
        } else {
          classroomDailySubjectsCounts[cId]![day]![sId] = currentCount + 1;
          classroomDailySubjectsPeriods[cId]![day]![sId]!.add(period);
        }

        if (lesson.subject!.allowedPeriods.isNotEmpty && !lesson.subject!.allowedPeriods.contains(period)) {
          conflicts.add(SubjectNotAllowedPeriodConflict(sName, period));
        }
      }
    }

    for (var cId in classroomDailySubjectsPeriods.keys) {
      for (var day in classroomDailySubjectsPeriods[cId]!.keys) {
        for (var sId in classroomDailySubjectsPeriods[cId]![day]!.keys) {
          var periods = classroomDailySubjectsPeriods[cId]![day]![sId]!;
          if (periods.length > 1) {
            periods.sort();
            for (int i = 0; i < periods.length - 1; i++) {
              if (periods[i + 1] - periods[i] != 1) {
                String sName = subjects.firstWhere((s) => s.id == sId, orElse: () => subjects.first).name;
                String cName = classrooms.firstWhere((c) => c.id == cId, orElse: () => classrooms.first).name;
                conflicts.add(NonConsecutiveSubjectPeriodsConflict(sName, cName, day));
              }
            }
          }
        }
      }
    }

    return conflicts.toSet().toList();
  }

  // 2. The Cost Function (Penalty Calculation)
  int _calculateCost(List<LessonEntity> state, int maxDays, int maxPeriods) {
    int cost = 0;

    // teacherId -> set of (day * 100 + period)
    Map<int, Set<int>> teacherSlots = {};
    // teacherId -> map of {day -> count}
    Map<int, Map<int, int>> teacherDailyCounts = {};

    // classroomId -> map of {day -> map of {subjectId -> count}}
    Map<int, Map<int, Map<int, int>>> classroomDailySubjectsCounts = {};
    // classroomId -> map of {day -> map of {subjectId -> list of periods}}
    Map<int, Map<int, Map<int, List<int>>>> classroomDailySubjectsPeriods = {};

    // classroomId -> set of (day * 100 + period)
    Map<int, Set<int>> classroomSlots = {};

    for (var lesson in state) {
      if (lesson.dayIndex == null || lesson.periodIndex == null) continue;

      int day = lesson.dayIndex!;
      int period = lesson.periodIndex!;
      int timeKey = day * 100 + period;

      // Hard Constraint: Classroom Clash (Multiple lessons in same period)
      if (lesson.classroom != null) {
        int cId = lesson.classroom!.id;
        if (classroomSlots.containsKey(cId) && classroomSlots[cId]!.contains(timeKey)) {
          cost += 1000;
        } else {
          classroomSlots.putIfAbsent(cId, () => {}).add(timeKey);
        }
      }

      if (lesson.teacher != null) {
        int tId = lesson.teacher!.id;

        // Hard Constraint: Teacher Clash
        if (teacherSlots.containsKey(tId) && teacherSlots[tId]!.contains(timeKey)) {
          cost += 1000;
        } else {
          teacherSlots.putIfAbsent(tId, () => {}).add(timeKey);
        }

        // Hard Constraint: Teacher Daily Limit
        teacherDailyCounts.putIfAbsent(tId, () => {});
        teacherDailyCounts[tId]![day] = (teacherDailyCounts[tId]![day] ?? 0) + 1;

        if (teacherDailyCounts[tId]![day]! > lesson.teacher!.maxLessonsPerDay) {
          cost += 1000;
        }

        // Teacher unavailable days
        if (lesson.teacher!.unavailableDays.contains(day)) {
          cost += 1000;
        }

        // Teacher allowed periods
        if (lesson.teacher!.allowedPeriods.isNotEmpty && !lesson.teacher!.allowedPeriods.contains(period)) {
          cost += 1000;
        }
      }

      // Soft Constraint / Hard Constraint: Subject Spread & Limits
      if (lesson.classroom != null && lesson.subject != null) {
        int cId = lesson.classroom!.id;
        int sId = lesson.subject!.id;

        classroomDailySubjectsCounts.putIfAbsent(cId, () => {});
        classroomDailySubjectsCounts[cId]!.putIfAbsent(day, () => {});

        classroomDailySubjectsPeriods.putIfAbsent(cId, () => {});
        classroomDailySubjectsPeriods[cId]!.putIfAbsent(day, () => {});
        classroomDailySubjectsPeriods[cId]![day]!.putIfAbsent(sId, () => []);

        int maxAllowed = _getMaxAllowedSubjectPerDay(sId, cId);
        int currentCount = classroomDailySubjectsCounts[cId]![day]![sId] ?? 0;

        if (currentCount >= maxAllowed) {
          cost += 1000; // Hard Constraint: Exceeded max allowed per day
        } else {
          classroomDailySubjectsCounts[cId]![day]![sId] = currentCount + 1;
          classroomDailySubjectsPeriods[cId]![day]![sId]!.add(period);
        }

        // Subject allowed periods
        if (lesson.subject!.allowedPeriods.isNotEmpty && !lesson.subject!.allowedPeriods.contains(period)) {
          cost += 1000; // Treated as hard constraint
        }
      }
    }

    // Soft Constraint: Encourage consecutive periods for multiple subject lessons in a day
    for (var cId in classroomDailySubjectsPeriods.keys) {
      for (var day in classroomDailySubjectsPeriods[cId]!.keys) {
        for (var sId in classroomDailySubjectsPeriods[cId]![day]!.keys) {
          var periods = classroomDailySubjectsPeriods[cId]![day]![sId]!;
          if (periods.length > 1) {
            periods.sort();
            for (int i = 0; i < periods.length - 1; i++) {
              if (periods[i + 1] - periods[i] != 1) {
                cost += 50; // Soft penalty for non-consecutive periods of the same subject in the same day
              }
            }
          }
        }
      }
    }

    return cost;
  }
}
