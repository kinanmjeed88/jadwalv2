import 'dart:math';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';
import '../../../../core/models/subject_consecutiveness.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';
import 'pre_validation_engine.dart';

class _GenerationAttemptResult {
  final List<LessonEntity> schedule;
  final int cost;

  _GenerationAttemptResult(this.schedule, this.cost);
}

class _ScoredLesson {
  final LessonEntity lesson;
  final int score;
  final int originalIndex;

  _ScoredLesson(this.lesson, this.score, this.originalIndex);
}

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

    final subject = subjects.firstWhere((s) => s.id == subjectId,
        orElse: () => subjects.first);
    final classroom = classrooms.firstWhere((c) => c.id == classroomId,
        orElse: () => classrooms.first);

    for (var constraint in subjectConstraints) {
      if (constraint.grade == classroom.grade &&
          constraint.subjectName == subject.name) {
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
      final reasons =
          errors.map((error) => GenericSolverFailure(error)).toList();
      throw TimetableGenerationException(reasons);
    }
  }

  static const int _maxRetries = 10;
  static const int _timeBudgetMilliseconds = 59000;
  static const int _initialTopK = 3;

  /// Generates the timetable using multi-start Simulated Annealing (SA).
  List<LessonEntity> generate() {
    _runPreValidation();

    final stopwatch = Stopwatch()..start();
    final maxDays = settings.daysPerWeek;
    final maxPeriods = settings.periodsPerDay;

    List<LessonEntity>? bestFailedSchedule;
    var bestFailedCost = 1 << 62;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0 &&
          stopwatch.elapsedMilliseconds >= _timeBudgetMilliseconds) {
        break;
      }

      final result = _generateAttempt(
        maxDays: maxDays,
        maxPeriods: maxPeriods,
        random: Random(),
        stopwatch: stopwatch,
      );

      if (result.cost == 0) {
        stopwatch.stop();
        return result.schedule;
      }

      if (bestFailedSchedule == null || result.cost < bestFailedCost) {
        bestFailedSchedule = _cloneState(result.schedule);
        bestFailedCost = result.cost;
      }

      if (stopwatch.elapsedMilliseconds >= _timeBudgetMilliseconds) {
        break;
      }
    }

    stopwatch.stop();
    final failedSchedule = bestFailedSchedule ?? _cloneState(existingLessons);
    final diagnostics =
        _getConflictDiagnostics(failedSchedule, maxDays, maxPeriods);
    final failedCost = bestFailedSchedule == null
        ? _calculateCost(failedSchedule, maxDays, maxPeriods)
        : bestFailedCost;
    throw TimetableGenerationException(
      diagnostics.map((diagnostic) => diagnostic.reason).toList(),
      diagnostics: diagnostics,
      bestSchedule: _snapshot(failedSchedule),
      bestCost: failedCost,
    );
  }

  _GenerationAttemptResult _generateAttempt({
    required int maxDays,
    required int maxPeriods,
    required Random random,
    required Stopwatch stopwatch,
  }) {
    var currentSchedule = _buildInitialSchedule(
      maxDays: maxDays,
      maxPeriods: maxPeriods,
      random: random,
    );

    var currentCost = _calculateCost(currentSchedule, maxDays, maxPeriods);
    var bestSchedule = _cloneState(currentSchedule);
    var bestCost = currentCost;

    // 4. Simulated Annealing Core Loop
    double temp = 5000.0;
    const double coolingRate = 0.999;

    // Stop if temp < 0.1 or the shared generation deadline is reached.
    while (temp >= 0.1 &&
        stopwatch.elapsedMilliseconds < _timeBudgetMilliseconds) {
      // If we reach a perfect score, break early.
      if (bestCost == 0) {
        break;
      }

      // 3. Neighborhood Function (Move or Swap)
      final neighbor = _cloneState(currentSchedule);

      // Group neighbor by classroom id to mutate.
      final Map<int, List<LessonEntity>> neighborClassrooms = {};
      for (var lesson in neighbor) {
        if (lesson.classroom != null) {
          neighborClassrooms
              .putIfAbsent(lesson.classroom!.id, () => [])
              .add(lesson);
        }
      }

      // Filter out classrooms with 0 unpinned lessons.
      final validClassroomIds = neighborClassrooms.keys.where((id) {
        return neighborClassrooms[id]!.where((l) => !l.isPinned).isNotEmpty;
      }).toList();

      if (validClassroomIds.isNotEmpty) {
        final randomClassroomId =
            validClassroomIds[random.nextInt(validClassroomIds.length)];
        final classroomLessons = neighborClassrooms[randomClassroomId]!;
        final unpinnedClassroomLessons =
            classroomLessons.where((l) => !l.isPinned).toList();

        // Pick a random unpinned lesson.
        final targetLesson = unpinnedClassroomLessons[
            random.nextInt(unpinnedClassroomLessons.length)];

        // Pick a random destination slot.
        final newDay = random.nextInt(maxDays);
        final newPeriod = random.nextInt(maxPeriods);

        // Check if destination slot is occupied by another lesson in the same
        // classroom. We can only swap if it is unpinned.
        final occupyingLessonOpt = classroomLessons
            .where((l) => l.dayIndex == newDay && l.periodIndex == newPeriod);

        if (occupyingLessonOpt.isNotEmpty) {
          final occupyingLesson = occupyingLessonOpt.first;
          if (!occupyingLesson.isPinned) {
            // Swap.
            final oldDay = targetLesson.dayIndex;
            final oldPeriod = targetLesson.periodIndex;

            targetLesson.dayIndex = newDay;
            targetLesson.periodIndex = newPeriod;

            occupyingLesson.dayIndex = oldDay;
            occupyingLesson.periodIndex = oldPeriod;
          }
          // If it is pinned, do not mutate; try the next iteration.
        } else {
          // Destination is free for this classroom, just move.
          targetLesson.dayIndex = newDay;
          targetLesson.periodIndex = newPeriod;
        }
      }

      final neighborCost = _calculateCost(neighbor, maxDays, maxPeriods);
      final deltaCost = neighborCost - currentCost;

      if (deltaCost < 0) {
        // Better state, accept unconditionally.
        currentSchedule = neighbor;
        currentCost = neighborCost;
        if (currentCost < bestCost) {
          bestSchedule = _cloneState(currentSchedule);
          bestCost = currentCost;
        }
      } else {
        // Worse state, accept with probability.
        final probability = exp(-deltaCost / temp);
        if (random.nextDouble() < probability) {
          currentSchedule = neighbor;
          currentCost = neighborCost;
        }
      }

      temp *= coolingRate;
    }

    return _GenerationAttemptResult(bestSchedule, bestCost);
  }

  List<LessonEntity> _buildInitialSchedule({
    required int maxDays,
    required int maxPeriods,
    required Random random,
  }) {
    // Each attempt owns this complete working graph. The caller's lessons are
    // never mutated while initialization or annealing is in progress.
    final workingLessons = _cloneState(existingLessons);
    final List<LessonEntity> currentSchedule = [];

    final Map<int, List<LessonEntity>> classroomLessons = {};
    for (var lesson in workingLessons) {
      if (lesson.classroom != null) {
        classroomLessons
            .putIfAbsent(lesson.classroom!.id, () => [])
            .add(lesson);
      }
    }

    for (var classroomId in classroomLessons.keys) {
      final lessons = classroomLessons[classroomId]!;
      final pinned = lessons
          .where((lesson) =>
              lesson.isPinned &&
              lesson.dayIndex != null &&
              lesson.periodIndex != null)
          .toList();
      final unpinned =
          lessons.where((lesson) => !pinned.contains(lesson)).toList();

      currentSchedule.addAll(pinned);

      final occupiedSlots = <int>{
        for (var lesson in pinned) lesson.dayIndex! * 100 + lesson.periodIndex!,
      };
      final availableSlots = <int>[];
      for (var day = 0; day < maxDays; day++) {
        for (var period = 0; period < maxPeriods; period++) {
          final slot = day * 100 + period;
          if (!occupiedSlots.contains(slot)) {
            availableSlots.add(slot);
          }
        }
      }

      final orderedLessons = _orderLessonsByRestriction(
        unpinned,
        maxDays: maxDays,
        maxPeriods: maxPeriods,
      );

      var assignedIndex = 0;
      while (
          assignedIndex < orderedLessons.length && availableSlots.isNotEmpty) {
        final lesson = orderedLessons[assignedIndex];
        final slot = _chooseInitialSlot(
          lesson,
          availableSlots,
          currentSchedule,
          random: random,
        );
        lesson.dayIndex = slot ~/ 100;
        lesson.periodIndex = slot % 100;
        currentSchedule.add(lesson);
        availableSlots.remove(slot);
        assignedIndex++;
      }

      // If there are still unpinned lessons (more lessons than slots), place
      // them in (0,0) to preserve the existing zero-data-loss behavior.
      while (assignedIndex < orderedLessons.length) {
        final lesson = orderedLessons[assignedIndex];
        lesson.dayIndex = 0;
        lesson.periodIndex = 0;
        currentSchedule.add(lesson);
        assignedIndex++;
      }
    }

    // Lessons without a classroom are initialized with the same hard-first
    // ordering, while allowing different teachers to share a slot.
    final orphanLessons =
        workingLessons.where((lesson) => lesson.classroom == null).toList();
    final pinnedOrphans = orphanLessons
        .where((lesson) =>
            lesson.isPinned &&
            lesson.dayIndex != null &&
            lesson.periodIndex != null)
        .toList();
    final unpinnedOrphans = orphanLessons
        .where((lesson) => !pinnedOrphans.contains(lesson))
        .toList();
    currentSchedule.addAll(pinnedOrphans);

    final orphanSlots = [
      for (var day = 0; day < maxDays; day++)
        for (var period = 0; period < maxPeriods; period++) day * 100 + period,
    ];
    final orderedOrphans = _orderLessonsByRestriction(
      unpinnedOrphans,
      maxDays: maxDays,
      maxPeriods: maxPeriods,
    );
    for (var lesson in orderedOrphans) {
      if (orphanSlots.isEmpty) {
        lesson.dayIndex = 0;
        lesson.periodIndex = 0;
      } else {
        final slot = _chooseInitialSlot(
          lesson,
          orphanSlots,
          currentSchedule,
          random: random,
        );
        lesson.dayIndex = slot ~/ 100;
        lesson.periodIndex = slot % 100;
      }
      currentSchedule.add(lesson);
    }

    return currentSchedule;
  }

  List<LessonEntity> _orderLessonsByRestriction(
    List<LessonEntity> lessons, {
    required int maxDays,
    required int maxPeriods,
  }) {
    final scored = [
      for (var index = 0; index < lessons.length; index++)
        _ScoredLesson(
          lessons[index],
          _restrictionScore(
            lessons[index],
            maxDays: maxDays,
            maxPeriods: maxPeriods,
          ),
          index,
        ),
    ];

    scored.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder == 0
          ? a.originalIndex.compareTo(b.originalIndex)
          : scoreOrder;
    });
    return scored.map((item) => item.lesson).toList();
  }

  int _restrictionScore(
    LessonEntity lesson, {
    required int maxDays,
    required int maxPeriods,
  }) {
    var score = 0;
    final teacher = lesson.teacher;
    final subject = lesson.subject;

    Set<int>? constrainedPeriods;
    if (teacher != null && teacher.allowedPeriods.isNotEmpty) {
      constrainedPeriods = teacher.allowedPeriods
          .where((period) => period >= 0 && period < maxPeriods)
          .toSet();
    }
    if (subject != null && subject.allowedPeriods.isNotEmpty) {
      final subjectPeriods = subject.allowedPeriods
          .where((period) => period >= 0 && period < maxPeriods)
          .toSet();
      constrainedPeriods = constrainedPeriods == null
          ? subjectPeriods
          : constrainedPeriods.intersection(subjectPeriods);
    }
    if (constrainedPeriods != null) {
      score +=
          (maxPeriods - constrainedPeriods.length).clamp(0, maxPeriods) * 1000;
      if (constrainedPeriods.isEmpty) {
        score += 100000;
      }
    }

    if (teacher != null) {
      final blockedDays = teacher.unavailableDays
          .where((day) => day >= 0 && day < maxDays)
          .length;
      score += blockedDays * 500;
      score += max(0, 10 - teacher.maxLessonsPerDay) * 20;
      score += max(0, 10 - teacher.maxLessonsPerWeek) * 5;
    }

    if (subject != null) {
      score += subject.lessonsPerWeek * 10;
      if (lesson.classroom != null) {
        final maxAllowed =
            _getMaxAllowedSubjectPerDay(subject.id, lesson.classroom!.id);
        score += max(0, maxPeriods - maxAllowed) * 100;
      }
      if (subject.preferEarlyPeriods) {
        score += 1;
      }
    }

    return score;
  }

  int _chooseInitialSlot(
    LessonEntity lesson,
    List<int> availableSlots,
    List<LessonEntity> assignedLessons, {
    required Random random,
  }) {
    final scoredSlots = [
      for (var slot in availableSlots)
        MapEntry(
          slot,
          _initialSlotPenalty(
            lesson,
            slot ~/ 100,
            slot % 100,
            assignedLessons,
          ),
        ),
    ];

    scoredSlots.sort((a, b) {
      final penaltyOrder = a.value.compareTo(b.value);
      return penaltyOrder == 0 ? a.key.compareTo(b.key) : penaltyOrder;
    });

    final topCount = min(_initialTopK, scoredSlots.length);
    return scoredSlots[random.nextInt(topCount)].key;
  }

  int _initialSlotPenalty(
    LessonEntity lesson,
    int day,
    int period,
    List<LessonEntity> assignedLessons,
  ) {
    var penalty = 0;
    final teacher = lesson.teacher;
    final subject = lesson.subject;

    if (teacher != null) {
      if (assignedLessons.any((assigned) =>
          assigned.teacher?.id == teacher.id &&
          assigned.dayIndex == day &&
          assigned.periodIndex == period)) {
        penalty += 100000;
      }
      if (teacher.unavailableDays.contains(day)) {
        penalty += 100000;
      }
      if (teacher.allowedPeriods.isNotEmpty &&
          !teacher.allowedPeriods.contains(period)) {
        penalty += 100000;
      }
      final dailyLoad = assignedLessons
          .where((assigned) =>
              assigned.teacher?.id == teacher.id && assigned.dayIndex == day)
          .length;
      if (dailyLoad >= teacher.maxLessonsPerDay) {
        penalty += 1000 * (dailyLoad - teacher.maxLessonsPerDay + 1);
      }
    }

    if (subject != null &&
        subject.allowedPeriods.isNotEmpty &&
        !subject.allowedPeriods.contains(period)) {
      penalty += 100000;
    }

    if (subject != null && lesson.classroom != null) {
      final classroomId = lesson.classroom!.id;
      final subjectId = subject.id;
      final sameSubjectPeriods = assignedLessons
          .where((assigned) =>
              assigned.classroom?.id == classroomId &&
              assigned.subject?.id == subjectId &&
              assigned.dayIndex == day &&
              assigned.periodIndex != null)
          .map((assigned) => assigned.periodIndex!)
          .toList();
      final maxAllowed = _getMaxAllowedSubjectPerDay(subjectId, classroomId);
      if (sameSubjectPeriods.length >= maxAllowed) {
        penalty += 1000;
      }
      if (sameSubjectPeriods.isNotEmpty &&
          !sameSubjectPeriods
              .any((existingPeriod) => (existingPeriod - period).abs() == 1)) {
        penalty += 50;
      }
    }

    if (subject?.preferEarlyPeriods == true) {
      penalty += period;
    }
    return penalty;
  }

  List<LessonEntity> _cloneState(List<LessonEntity> source) {
    return source
        .map(
          (lesson) => LessonEntity(
            id: lesson.id,
            teacher: lesson.teacher,
            subject: lesson.subject,
            classroom: lesson.classroom,
            dayIndex: lesson.dayIndex,
            periodIndex: lesson.periodIndex,
            isPinned: lesson.isPinned,
          ),
        )
        .toList();
  }

  List<ConflictDiagnostic> diagnose(List<LessonEntity> state) {
    return _getConflictDiagnostics(
      state,
      settings.daysPerWeek,
      settings.periodsPerDay,
    );
  }

  int calculateCost(List<LessonEntity> state) {
    return _calculateCost(state, settings.daysPerWeek, settings.periodsPerDay);
  }

  TimetableScheduleSnapshot snapshot(List<LessonEntity> state) {
    return _snapshot(state);
  }

  // ⚠️ عقد معماري: أي تعديل هنا يجب أن ينعكس في الدالة المقابلة.
  // كل شرط يرفع التكلفة (cost > 0) يجب أن يقابله إضافة تعارض (conflict.add) مماثل.
  List<ConflictDiagnostic> _getConflictDiagnostics(
      List<LessonEntity> state, int maxDays, int maxPeriods) {
    final diagnostics = <ConflictDiagnostic>[];

    final classroomSlotOwners = <int, Map<int, int>>{};
    final teacherSlotOwners = <int, Map<int, int>>{};
    final teacherDailyLessons = <int, Map<int, List<int>>>{};
    final classroomDailySubjectLessons =
        <int, Map<int, Map<int, List<LessonEntity>>>>{};
    final classroomDailySubjectCounts = <int, Map<int, Map<int, int>>>{};

    void addDiagnostic(
      ConflictReason reason, {
      List<int> lessonIds = const [],
      bool isHard = true,
    }) {
      diagnostics.add(
        ConflictDiagnostic(
          reason: reason,
          lessonIds: lessonIds,
          isHard: isHard,
        ),
      );
    }

    for (final lesson in state) {
      if (lesson.dayIndex == null || lesson.periodIndex == null) continue;

      final day = lesson.dayIndex!;
      final period = lesson.periodIndex!;
      final timeKey = day * 100 + period;

      if (lesson.classroom != null) {
        final classroomId = lesson.classroom!.id;
        final owners = classroomSlotOwners.putIfAbsent(classroomId, () => {});
        final previousOwner = owners[timeKey];
        if (previousOwner != null) {
          addDiagnostic(
            ClassroomTimeSlotConflict(lesson.classroom!.name, day, period),
            lessonIds: [previousOwner, lesson.id],
          );
        } else {
          owners[timeKey] = lesson.id;
        }
      }

      if (lesson.teacher != null) {
        final teacherId = lesson.teacher!.id;
        final slotOwners = teacherSlotOwners.putIfAbsent(teacherId, () => {});
        final previousOwner = slotOwners[timeKey];
        if (previousOwner != null) {
          addDiagnostic(
            TeacherTimeSlotConflict(lesson.teacher!.name, day, period),
            lessonIds: [previousOwner, lesson.id],
          );
        } else {
          slotOwners[timeKey] = lesson.id;
        }

        final dailyLessons = teacherDailyLessons
            .putIfAbsent(teacherId, () => {})
            .putIfAbsent(day, () => []);
        dailyLessons.add(lesson.id);
        if (dailyLessons.length > lesson.teacher!.maxLessonsPerDay) {
          addDiagnostic(
            TeacherLoadExceeded(
              lesson.teacher!.name,
              dailyLessons.length,
              lesson.teacher!.maxLessonsPerDay,
            ),
            lessonIds: List<int>.from(dailyLessons),
          );
        }

        if (lesson.teacher!.unavailableDays.contains(day)) {
          addDiagnostic(
            TeacherUnavailableDayConflict(lesson.teacher!.name, day),
            lessonIds: [lesson.id],
          );
        }

        if (lesson.teacher!.allowedPeriods.isNotEmpty &&
            !lesson.teacher!.allowedPeriods.contains(period)) {
          addDiagnostic(
            TeacherNotAllowedPeriodConflict(lesson.teacher!.name, period),
            lessonIds: [lesson.id],
          );
        }
      }

      if (lesson.subject != null && lesson.classroom != null) {
        final subjectId = lesson.subject!.id;
        final classroomId = lesson.classroom!.id;
        final subjectCounts = classroomDailySubjectCounts
            .putIfAbsent(classroomId, () => {})
            .putIfAbsent(day, () => {});
        final currentCount = subjectCounts[subjectId] ?? 0;
        final maxAllowed = _getMaxAllowedSubjectPerDay(subjectId, classroomId);
        final subjectLessons = classroomDailySubjectLessons
            .putIfAbsent(classroomId, () => {})
            .putIfAbsent(day, () => {})
            .putIfAbsent(subjectId, () => []);

        if (currentCount >= maxAllowed) {
          addDiagnostic(
            SubjectMaxPerDayExceeded(
              lesson.subject!.name,
              lesson.classroom!.name,
              day,
              maxAllowed,
              currentCount + 1,
            ),
            lessonIds: [
              ...subjectLessons.map((scheduledLesson) => scheduledLesson.id),
              lesson.id,
            ],
          );
        } else {
          subjectCounts[subjectId] = currentCount + 1;
          subjectLessons.add(lesson);
        }

        if (lesson.subject!.allowedPeriods.isNotEmpty &&
            !lesson.subject!.allowedPeriods.contains(period)) {
          addDiagnostic(
            SubjectNotAllowedPeriodConflict(lesson.subject!.name, period),
            lessonIds: [lesson.id],
          );
        }
      }
    }

    for (final classroomEntry in classroomDailySubjectLessons.entries) {
      for (final dayEntry in classroomEntry.value.entries) {
        for (final subjectLessons in dayEntry.value.values) {
          if (subjectLessons.length < 2) continue;

          subjectLessons.sort(
            (a, b) => a.periodIndex!.compareTo(b.periodIndex!),
          );
          final subject = subjectLessons.first.subject;
          if (subject == null ||
              subject.consecutiveness != SubjectConsecutiveness.consecutive) {
            continue;
          }

          for (var index = 0; index < subjectLessons.length - 1; index++) {
            final first = subjectLessons[index];
            final second = subjectLessons[index + 1];
            if (second.periodIndex! - first.periodIndex! != 1) {
              addDiagnostic(
                NonConsecutiveSubjectPeriodsConflict(
                  subject.name,
                  classrooms
                      .firstWhere(
                        (classroom) => classroom.id == classroomEntry.key,
                        orElse: () => classrooms.first,
                      )
                      .name,
                  dayEntry.key,
                ),
                lessonIds: [first.id, second.id],
                isHard: false,
              );
            }
          }
        }
      }
    }

    final finalCost = _calculateCost(state, maxDays, maxPeriods);
    if (finalCost > 0 && diagnostics.isEmpty) {
      addDiagnostic(
        const GenericSolverFailure(
          'توجد تعارضات خفية في توزيع الحصص أو قيود المعلمين لم يتم تحديدها بدقة.',
        ),
      );
    }

    final unique = <String, ConflictDiagnostic>{};
    for (final diagnostic in diagnostics) {
      final key =
          '${diagnostic.reason}|${diagnostic.lessonIds}|${diagnostic.isHard}';
      unique[key] = diagnostic;
    }
    return unique.values.toList();
  }

  TimetableScheduleSnapshot _snapshot(List<LessonEntity> state) {
    return TimetableScheduleSnapshot(
      state
          .map(
            (lesson) => LessonPlacement(
              lessonId: lesson.id,
              dayIndex: lesson.dayIndex,
              periodIndex: lesson.periodIndex,
            ),
          )
          .toList(growable: false),
    );
  }

  // 2. The Cost Function (Penalty Calculation)
  // ⚠️ عقد معماري: أي تعديل هنا يجب أن ينعكس في الدالة المقابلة.
  // كل شرط يرفع التكلفة (cost > 0) يجب أن يقابله إضافة تعارض (conflict.add) مماثل.
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
        if (classroomSlots.containsKey(cId) &&
            classroomSlots[cId]!.contains(timeKey)) {
          cost += 1000;
        } else {
          classroomSlots.putIfAbsent(cId, () => {}).add(timeKey);
        }
      }

      if (lesson.teacher != null) {
        int tId = lesson.teacher!.id;

        // Hard Constraint: Teacher Clash
        if (teacherSlots.containsKey(tId) &&
            teacherSlots[tId]!.contains(timeKey)) {
          cost += 1000;
        } else {
          teacherSlots.putIfAbsent(tId, () => {}).add(timeKey);
        }

        // Hard Constraint: Teacher Daily Limit
        teacherDailyCounts.putIfAbsent(tId, () => {});
        teacherDailyCounts[tId]![day] =
            (teacherDailyCounts[tId]![day] ?? 0) + 1;

        if (teacherDailyCounts[tId]![day]! > lesson.teacher!.maxLessonsPerDay) {
          cost += 1000;
        }

        // Teacher unavailable days
        if (lesson.teacher!.unavailableDays.contains(day)) {
          cost += 1000;
        }

        // Teacher allowed periods
        if (lesson.teacher!.allowedPeriods.isNotEmpty &&
            !lesson.teacher!.allowedPeriods.contains(period)) {
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
        if (lesson.subject!.allowedPeriods.isNotEmpty &&
            !lesson.subject!.allowedPeriods.contains(period)) {
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
              final subject = subjects.firstWhere(
                (s) => s.id == sId,
                orElse: () => subjects.first,
              );
              if (subject.consecutiveness ==
                      SubjectConsecutiveness.consecutive &&
                  periods[i + 1] - periods[i] != 1) {
                cost +=
                    50; // Soft penalty for non-consecutive periods of the same subject in the same day
              }
            }
          }
        }
      }
    }

    return cost;
  }
}
