import 'dart:math';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';
import '../../../../core/exceptions/conflict_reason.dart';
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

  List<LessonEntity> cloneState(List<LessonEntity> state) {
    return state.map((l) => l.clone()).toList();
  }

  int _getMaxAllowedSubjectPerDay(int subjectId, int classroomId) {
    var subject = subjects.firstWhere((s) => s.id == subjectId, orElse: () => subjects.first);
    var classroom = classrooms.firstWhere((c) => c.id == classroomId, orElse: () => classrooms.first);

    for (var constraint in subjectConstraints) {
      if (constraint.grade == classroom.grade && constraint.subjectName == subject.name) {
        return constraint.maxPeriodsPerDay;
      }
    }
    return 1;
  }

  List<LessonEntity> generate() {
    // 1. Run Pre-Validation
    final preValidationEngine = PreValidationEngine(
      existingLessons: existingLessons,
      teachers: teachers,
      classrooms: classrooms,
      settings: settings,
      subjects: subjects,
      subjectConstraints: subjectConstraints,
    );

    final validationConflicts = preValidationEngine.validateAll();
    if (validationConflicts.isNotEmpty) {
      throw TimetableGenerationException(validationConflicts);
    }

    int maxDays = settings.daysPerWeek;
    int maxPeriods = settings.periodsPerDay;

    List<LessonEntity> currentSchedule = cloneState(existingLessons);

    // Initial greedy assignment for unpinned/unassigned lessons
    Map<int, List<int>> classroomFreeSlots = {};
    for (var c in classrooms) {
      classroomFreeSlots[c.id] = List.generate(maxDays * maxPeriods, (i) => i);
    }

    for (var lesson in currentSchedule) {
      if (lesson.isPinned && lesson.dayIndex != null && lesson.periodIndex != null) {
        int timeKey = lesson.dayIndex! * maxPeriods + lesson.periodIndex!;
        if (lesson.classroom != null) {
          classroomFreeSlots[lesson.classroom!.id]?.remove(timeKey);
        }
      }
    }

    final random = Random();
    for (var lesson in currentSchedule) {
      if (!lesson.isPinned && (lesson.dayIndex == null || lesson.periodIndex == null)) {
        if (lesson.classroom != null && classroomFreeSlots.containsKey(lesson.classroom!.id)) {
           var freeSlots = classroomFreeSlots[lesson.classroom!.id]!;
           if (freeSlots.isNotEmpty) {
             int randIndex = random.nextInt(freeSlots.length);
             int slot = freeSlots.removeAt(randIndex);
             lesson.dayIndex = slot ~/ maxPeriods;
             lesson.periodIndex = slot % maxPeriods;
           }
        }
      }
    }

    int currentCost = _calculateCost(currentSchedule, maxDays, maxPeriods);
    List<LessonEntity> bestSchedule = cloneState(currentSchedule);
    int bestCost = currentCost;

    double temp = 1000.0;
    double coolingRate = 0.99;
    int maxIterations = 5000;

    final stopwatch = Stopwatch()..start();
    int iteration = 0;

    while (temp > 1 && bestCost > 0 && iteration < maxIterations && stopwatch.elapsedMilliseconds < 5000) {
      iteration++;
      List<LessonEntity> neighbor = cloneState(currentSchedule);

      // Mutate: Swap two random unpinned lessons within the SAME classroom
      // (because swapping between classrooms breaks the exact classroom required lessons)
      Map<int, List<LessonEntity>> neighborClassrooms = {};
      for (var l in neighbor) {
        if (l.classroom != null) {
          neighborClassrooms.putIfAbsent(l.classroom!.id, () => []).add(l);
        }
      }

      List<int> validClassroomIds = neighborClassrooms.keys.where((id) {
        return neighborClassrooms[id]!.where((l) => !l.isPinned).isNotEmpty;
      }).toList();

      if (validClassroomIds.isNotEmpty) {
        int randomClassroomId = validClassroomIds[random.nextInt(validClassroomIds.length)];
        var classroomLessons = neighborClassrooms[randomClassroomId]!;
        List<LessonEntity> unpinnedClassroomLessons = classroomLessons.where((l) => !l.isPinned).toList();

        LessonEntity targetLesson = unpinnedClassroomLessons[random.nextInt(unpinnedClassroomLessons.length)];

        int newDay = random.nextInt(maxDays);
        int newPeriod = random.nextInt(maxPeriods);

        var occupyingLessonOpt = classroomLessons.where((l) => l.dayIndex == newDay && l.periodIndex == newPeriod);

        if (occupyingLessonOpt.isNotEmpty) {
          var occupyingLesson = occupyingLessonOpt.first;
          if (!occupyingLesson.isPinned) {
            int? oldDay = targetLesson.dayIndex;
            int? oldPeriod = targetLesson.periodIndex;

            targetLesson.dayIndex = newDay;
            targetLesson.periodIndex = newPeriod;

            occupyingLesson.dayIndex = oldDay;
            occupyingLesson.periodIndex = oldPeriod;
          }
        } else {
          targetLesson.dayIndex = newDay;
          targetLesson.periodIndex = newPeriod;
        }
      }

      int neighborCost = _calculateCost(neighbor, maxDays, maxPeriods);
      int deltaCost = neighborCost - currentCost;

      if (deltaCost < 0) {
        currentSchedule = neighbor;
        currentCost = neighborCost;
        if (currentCost < bestCost) {
          bestSchedule = cloneState(currentSchedule);
          bestCost = currentCost;
        }
      } else {
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
      if (conflicts.isEmpty) {
        conflicts.add(const GenericSolverFailure('تعذر الوصول إلى جدول خالي من التعارضات (تكلفة > 0)'));
      }
      throw TimetableGenerationException(conflicts);
    }
    return bestSchedule;
  }

  List<ConflictReason> _getConflicts(List<LessonEntity> state, int maxDays, int maxPeriods) {
    List<ConflictReason> conflicts = [];

    Map<int, Set<int>> teacherSlots = {};
    Map<int, Map<int, int>> teacherDailyCounts = {};
    Map<int, Map<int, Map<int, int>>> classroomDailySubjectsCounts = {};
    Map<int, Set<int>> classroomSlots = {};

    for (var lesson in state) {
      if (lesson.dayIndex == null || lesson.periodIndex == null) continue;

      int day = lesson.dayIndex!;
      int period = lesson.periodIndex!;
      int timeKey = day * 100 + period;

      if (lesson.classroom != null) {
        int cId = lesson.classroom!.id;
        if (classroomSlots.containsKey(cId) && classroomSlots[cId]!.contains(timeKey)) {
          conflicts.add(GenericSolverFailure('تعارض في الفصل "${lesson.classroom!.name}": أكثر من حصة في اليوم ${day + 1} الحصة ${period + 1}'));
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
          conflicts.add(GenericSolverFailure('تجاوز الحد الأقصى اليومي للمعلم "$tName" في اليوم ${day + 1}'));
        }

        if (lesson.teacher!.unavailableDays.contains(day)) {
          conflicts.add(GenericSolverFailure('المعلم "$tName" غير متوفر في اليوم ${day + 1} وتم تعيين حصة له'));
        }
      }

      if (lesson.subject != null && lesson.classroom != null) {
        int sId = lesson.subject!.id;
        int cId = lesson.classroom!.id;
        String sName = lesson.subject!.name;

        classroomDailySubjectsCounts.putIfAbsent(cId, () => {});
        classroomDailySubjectsCounts[cId]!.putIfAbsent(day, () => {});

        int maxAllowed = _getMaxAllowedSubjectPerDay(sId, cId);
        int currentCount = classroomDailySubjectsCounts[cId]![day]![sId] ?? 0;

        if (currentCount >= maxAllowed) {
          conflicts.add(GenericSolverFailure('تجاوز الحد الأقصى ($maxAllowed حصص) لمادة "$sName" في اليوم ${day + 1} للفصل "${lesson.classroom!.name}"'));
        } else {
          classroomDailySubjectsCounts[cId]![day]![sId] = currentCount + 1;
        }
      }
    }

    return conflicts.toSet().toList();
  }

  int _calculateCost(List<LessonEntity> state, int maxDays, int maxPeriods) {
    int cost = 0;

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
          cost += 1000;
        } else {
          classroomSlots.putIfAbsent(cId, () => {}).add(timeKey);
        }
      }

      if (lesson.teacher != null) {
        int tId = lesson.teacher!.id;

        if (teacherSlots.containsKey(tId) && teacherSlots[tId]!.contains(timeKey)) {
          cost += 1000;
        } else {
          teacherSlots.putIfAbsent(tId, () => {}).add(timeKey);
        }

        teacherDailyCounts.putIfAbsent(tId, () => {});
        teacherDailyCounts[tId]![day] = (teacherDailyCounts[tId]![day] ?? 0) + 1;

        if (teacherDailyCounts[tId]![day]! > lesson.teacher!.maxLessonsPerDay) {
          cost += 1000;
        }

        if (lesson.teacher!.unavailableDays.contains(day)) {
          cost += 1000;
        }

        if (lesson.teacher!.allowedPeriods.isNotEmpty && !lesson.teacher!.allowedPeriods.contains(period)) {
          cost += 1000;
        }
      }

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
          cost += 1000;
        } else {
          classroomDailySubjectsCounts[cId]![day]![sId] = currentCount + 1;
          classroomDailySubjectsPeriods[cId]![day]![sId]!.add(period);
        }

        if (lesson.subject!.allowedPeriods.isNotEmpty && !lesson.subject!.allowedPeriods.contains(period)) {
          cost += 1000;
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
                cost += 50;
              }
            }
          }
        }
      }
    }

    return cost;
  }
}
