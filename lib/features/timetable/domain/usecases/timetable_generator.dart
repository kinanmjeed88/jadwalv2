import 'dart:math';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';
import '../../../../core/models/subject_consecutiveness.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';
import '../services/scheduling_rules.dart';
import 'pre_validation_engine.dart';

/// تقييم جدول بمكوّنين منفصلين.
///
/// * [violationCost]: مخالفات القيود الإجبارية (1000 لكل مخالفة). الجدول صالح
///   فقط إذا كانت صفرًا.
/// * [preferenceCost]: التفضيلات غير الإجبارية (وضع الحصص الإضافية بدءًا من
///   الأحد، وتفضيل الدروس المبكرة). لا تُفشل التوليد أبدًا.
class TimetableCostBreakdown {
  final int violationCost;
  final int preferenceCost;

  const TimetableCostBreakdown({
    required this.violationCost,
    required this.preferenceCost,
  });

  int get total => violationCost + preferenceCost;

  bool get isFeasible => violationCost == 0;

  /// مقارنة ترتيبية: الصلاحية أولًا ثم جودة التفضيلات.
  bool isBetterThan(TimetableCostBreakdown other) {
    if (violationCost != other.violationCost) {
      return violationCost < other.violationCost;
    }
    return preferenceCost < other.preferenceCost;
  }

  @override
  String toString() =>
      'TimetableCostBreakdown(violation: $violationCost, preference: $preferenceCost)';
}

class _GenerationAttemptResult {
  final List<LessonEntity> schedule;
  final TimetableCostBreakdown breakdown;

  _GenerationAttemptResult(this.schedule, this.breakdown);
}

class _ScoredLesson {
  final LessonEntity lesson;
  final int score;
  final int originalIndex;

  _ScoredLesson(this.lesson, this.score, this.originalIndex);
}

/// بيانات ثابتة لمجموعة (صف × مادة) طوال تشغيل المحرك.
class _SubjectGroup {
  final SubjectConsecutiveness policy;
  final int userMax;
  final SubjectWeeklyDistribution distribution;

  _SubjectGroup({
    required this.policy,
    required this.userMax,
    required this.distribution,
  });

  int get effectiveMax => distribution.effectiveMax(userMax);
}

class TimetableGenerator {
  final List<TeacherEntity> teachers;
  final List<SubjectEntity> subjects;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;
  final List<LessonEntity> existingLessons;
  final List<SubjectConstraintEntity> subjectConstraints;

  /// بذرة اختيارية للعشوائية (للاختبارات الحتمية فقط). عند غيابها يبقى السلوك
  /// الإنتاجي عشوائيًا كما كان.
  final int? seed;

  /// المهلة الإجمالية للتوليد. الافتراضي 59 ثانية كما كان سابقًا.
  final Duration timeBudget;

  TimetableGenerator({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
    this.subjectConstraints = const [],
    this.seed,
    this.timeBudget = const Duration(milliseconds: _defaultTimeBudgetMs),
  });

  static const int _hardPenalty = 1000;
  static const int _misplacedExtraPenalty = 10;
  static const int _earlyPeriodPenalty = 1;

  // ---------------------------------------------------------------------------
  // بيانات محسوبة مرة واحدة (كانت تُحسب بعمليات بحث خطية داخل دالة التكلفة).
  // ---------------------------------------------------------------------------

  /// أول قيد يطابق (الصف، المادة) هو المعتمد، كما في السلوك السابق.
  late final Map<String, int> _maxPerDayByKey = () {
    final result = <String, int>{};
    for (final constraint in subjectConstraints) {
      result.putIfAbsent(
        _constraintKey(constraint.grade, constraint.subjectName),
        () => constraint.maxPeriodsPerDay,
      );
    }
    return result;
  }();

  static String _constraintKey(String grade, String subjectName) =>
      '$grade\u001F$subjectName';

  late final Map<int, ClassroomEntity> _classroomsById = {
    for (final classroom in classrooms) classroom.id: classroom,
  };

  late final Map<int, SubjectEntity> _subjectsById = {
    for (final subject in subjects) subject.id: subject,
  };

  final Map<int, List<int>> _dailyPeriodsCache = <int, List<int>>{};

  /// classroomId -> subjectId -> group.
  final Map<int, Map<int, _SubjectGroup>> _groupCache =
      <int, Map<int, _SubjectGroup>>{};

  late final Map<int, Map<int, List<LessonEntity>>> _lessonsByGroup = () {
    final result = <int, Map<int, List<LessonEntity>>>{};
    for (final lesson in existingLessons) {
      final classroom = lesson.classroom;
      final subject = lesson.subject;
      if (classroom == null || subject == null) continue;
      result
          .putIfAbsent(classroom.id, () => <int, List<LessonEntity>>{})
          .putIfAbsent(subject.id, () => <LessonEntity>[])
          .add(lesson);
    }
    return result;
  }();

  /// الحد الأعلى اليومي الذي حدده المستخدم (أو الافتراضي حصة واحدة).
  int _userMaxPerDay(String grade, String subjectName) {
    if (subjectConstraints.isEmpty) return 1;
    return _maxPerDayByKey[_constraintKey(grade, subjectName)] ?? 1;
  }

  int _getMaxAllowedSubjectPerDay(int subjectId, int classroomId) {
    final group = _groupForIds(classroomId, subjectId);
    if (group != null) return group.effectiveMax;
    final classroom = _classroomsById[classroomId];
    final subject = _subjectsById[subjectId];
    if (classroom == null || subject == null) return 1;
    return _userMaxPerDay(classroom.grade, subject.name);
  }

  _SubjectGroup? _groupForIds(int classroomId, int subjectId) {
    final cached = _groupCache[classroomId]?[subjectId];
    if (cached != null) return cached;
    final sample = _lessonsByGroup[classroomId]?[subjectId];
    if (sample != null && sample.isNotEmpty) {
      return _groupFor(sample.first.classroom!, sample.first.subject!);
    }
    final classroom = _classroomsById[classroomId];
    final subject = _subjectsById[subjectId];
    if (classroom == null || subject == null) return null;
    return _groupFor(classroom, subject);
  }

  _SubjectGroup _groupFor(
    ClassroomEntity classroom,
    SubjectEntity subject, [
    List<LessonEntity>? fallbackLessons,
  ]) {
    final cached = _groupCache[classroom.id]?[subject.id];
    if (cached != null) return cached;

    final lessons = _lessonsByGroup[classroom.id]?[subject.id] ??
        fallbackLessons ??
        const <LessonEntity>[];
    final maxDays = settings.daysPerWeek;
    final dailyPeriods = _dailyPeriodsForClassroom(
        classroom.id, maxDays, settings.periodsPerDay);
    final profiles = [
      for (final lesson in lessons) _profileFor(lesson),
    ];
    final eligibleDays = SchedulingRules.eligibleDays(
      daysPerWeek: maxDays,
      periodsOnDay: (day) => day < dailyPeriods.length ? dailyPeriods[day] : 0,
      profiles: profiles,
    );
    final group = _SubjectGroup(
      policy: subject.consecutiveness,
      userMax: _userMaxPerDay(classroom.grade, subject.name),
      distribution: SubjectWeeklyDistribution.compute(
        lessonCount: lessons.length,
        eligibleDays: eligibleDays,
      ),
    );
    _groupCache.putIfAbsent(
        classroom.id, () => <int, _SubjectGroup>{})[subject.id] = group;
    return group;
  }

  static LessonPlacementProfile _profileFor(LessonEntity lesson) {
    return LessonPlacementProfile(
      teacherUnavailableDays: lesson.teacher?.unavailableDays ?? const <int>[],
      teacherAllowedPeriods: lesson.teacher?.allowedPeriods ?? const <int>[],
      subjectAllowedPeriods: lesson.subject?.allowedPeriods ?? const <int>[],
    );
  }

  List<int> _dailyPeriodsForClassroom(
    int classroomId,
    int maxDays,
    int fallbackMaxPeriods,
  ) {
    final cached = _dailyPeriodsCache[classroomId];
    if (cached != null) return cached;
    final classroom = _classroomsById[classroomId];
    final List<int> resolved;
    if (classroom != null) {
      resolved = classroom.resolveDailyPeriods(settings);
    } else {
      final safeDays = maxDays < 1 ? 5 : maxDays;
      resolved =
          List<int>.filled(safeDays, fallbackMaxPeriods, growable: false);
    }
    _dailyPeriodsCache[classroomId] = resolved;
    return resolved;
  }

  int _periodsForClassroomOnDay(
    int classroomId,
    int dayIndex,
    int maxDays,
    int fallbackMaxPeriods,
  ) {
    final daily =
        _dailyPeriodsForClassroom(classroomId, maxDays, fallbackMaxPeriods);
    if (dayIndex < 0 || dayIndex >= daily.length) {
      return 0;
    }
    return daily[dayIndex];
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
  static const int _defaultTimeBudgetMs = 59000;
  static const int _initialTopK = 3;
  static const int _polishMaxIterations = 3000;
  static const int _polishPatience = 900;

  int get _timeBudgetMilliseconds => timeBudget.inMilliseconds;

  /// Generates the timetable using multi-start Simulated Annealing (SA).
  ///
  /// ينجح التوليد عندما تخلو أفضل نسخة من أي مخالفة إجبارية، ثم تُحسَّن
  /// التفضيلات (الأحد للحصص الإضافية، الدروس المبكرة) دون كسر أي قيد إجباري.
  List<LessonEntity> generate() {
    _runPreValidation();

    final stopwatch = Stopwatch()..start();
    final maxDays = settings.daysPerWeek;
    final maxPeriods = settings.periodsPerDay;

    List<LessonEntity>? bestFailedSchedule;
    TimetableCostBreakdown? bestFailedBreakdown;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0 &&
          stopwatch.elapsedMilliseconds >= _timeBudgetMilliseconds) {
        break;
      }

      final result = _generateAttempt(
        maxDays: maxDays,
        maxPeriods: maxPeriods,
        random: Random(seed == null ? null : seed! + attempt),
        stopwatch: stopwatch,
      );

      if (result.breakdown.isFeasible) {
        stopwatch.stop();
        return result.schedule;
      }

      if (bestFailedBreakdown == null ||
          result.breakdown.isBetterThan(bestFailedBreakdown)) {
        bestFailedSchedule = _cloneState(result.schedule);
        bestFailedBreakdown = result.breakdown;
      }

      if (stopwatch.elapsedMilliseconds >= _timeBudgetMilliseconds) {
        break;
      }
    }

    stopwatch.stop();
    final failedSchedule = bestFailedSchedule ?? _cloneState(existingLessons);
    final diagnostics =
        _getConflictDiagnostics(failedSchedule, maxDays, maxPeriods);
    final failedCost = bestFailedBreakdown?.violationCost ??
        _calculateCost(failedSchedule, maxDays, maxPeriods);
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

    var currentEval = _evaluate(currentSchedule, maxDays, maxPeriods);
    var bestSchedule = _cloneState(currentSchedule);
    var bestEval = currentEval;

    // 4. Simulated Annealing Core Loop (minimizes violations + preferences).
    double temp = 5000.0;
    const double coolingRate = 0.999;

    // Stop when a valid schedule exists, temp < 0.1, or the shared deadline is
    // reached. Preferences are improved afterwards by a constraint-safe polish.
    while (temp >= 0.1 &&
        stopwatch.elapsedMilliseconds < _timeBudgetMilliseconds) {
      if (bestEval.isFeasible) {
        break;
      }

      // 3. Neighborhood Function (Move or Swap)
      final neighbor = _cloneState(currentSchedule);
      _applyRandomMove(neighbor, random, maxDays, maxPeriods);

      final neighborEval = _evaluate(neighbor, maxDays, maxPeriods);
      final deltaCost = neighborEval.total - currentEval.total;

      if (deltaCost < 0) {
        // Better state, accept unconditionally.
        currentSchedule = neighbor;
        currentEval = neighborEval;
      } else {
        // Worse state, accept with probability.
        final probability = exp(-deltaCost / temp);
        if (random.nextDouble() < probability) {
          currentSchedule = neighbor;
          currentEval = neighborEval;
        }
      }
      if (currentEval.isBetterThan(bestEval)) {
        bestSchedule = _cloneState(currentSchedule);
        bestEval = currentEval;
      }

      temp *= coolingRate;
    }

    if (bestEval.isFeasible && bestEval.preferenceCost > 0) {
      final polished = _polishPreferences(
        bestSchedule,
        bestEval,
        maxDays: maxDays,
        maxPeriods: maxPeriods,
        random: random,
        stopwatch: stopwatch,
      );
      bestSchedule = polished.schedule;
      bestEval = polished.breakdown;
    }

    return _GenerationAttemptResult(bestSchedule, bestEval);
  }

  /// حركة عشوائية داخل صف واحد (نقل أو تبديل حصة غير مقفلة).
  ///
  /// تعيد `true` إذا تغيّر الجدول.
  bool _applyRandomMove(
    List<LessonEntity> neighbor,
    Random random,
    int maxDays,
    int maxPeriods,
  ) {
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

    if (validClassroomIds.isEmpty) return false;

    final randomClassroomId =
        validClassroomIds[random.nextInt(validClassroomIds.length)];
    final classroomLessons = neighborClassrooms[randomClassroomId]!;
    final unpinnedClassroomLessons =
        classroomLessons.where((l) => !l.isPinned).toList();

    // Pick a random unpinned lesson.
    final targetLesson = unpinnedClassroomLessons[
        random.nextInt(unpinnedClassroomLessons.length)];

    // Pick a random destination slot within this classroom's daily profile.
    final dailyPeriods = _dailyPeriodsForClassroom(
      randomClassroomId,
      maxDays,
      maxPeriods,
    );
    final activeDays = <int>[
      for (var d = 0; d < maxDays; d++)
        if ((d < dailyPeriods.length ? dailyPeriods[d] : maxPeriods) > 0) d,
    ];

    if (activeDays.isEmpty) return false;

    final newDay = activeDays[random.nextInt(activeDays.length)];
    final periodsOnDay =
        newDay < dailyPeriods.length ? dailyPeriods[newDay] : maxPeriods;
    final newPeriod = random.nextInt(periodsOnDay);

    return _moveOrSwapWithinClassroom(
      classroomLessons,
      targetLesson,
      newDay,
      newPeriod,
    );
  }

  /// ينقل [target] إلى (يوم، حصة) داخل صفه، مع تبديل الحصة الموجودة هناك
  /// إن لم تكن مقفلة.
  bool _moveOrSwapWithinClassroom(
    List<LessonEntity> classroomLessons,
    LessonEntity target,
    int newDay,
    int newPeriod,
  ) {
    if (target.dayIndex == newDay && target.periodIndex == newPeriod) {
      return false;
    }
    // Check if destination slot is occupied by another lesson in the same
    // classroom. We can only swap if it is unpinned.
    LessonEntity? occupying;
    for (final lesson in classroomLessons) {
      if (!identical(lesson, target) &&
          lesson.dayIndex == newDay &&
          lesson.periodIndex == newPeriod) {
        occupying = lesson;
        break;
      }
    }

    if (occupying != null) {
      if (occupying.isPinned) {
        // If it is pinned, do not mutate; try the next iteration.
        return false;
      }
      final oldDay = target.dayIndex;
      final oldPeriod = target.periodIndex;
      target.dayIndex = newDay;
      target.periodIndex = newPeriod;
      occupying.dayIndex = oldDay;
      occupying.periodIndex = oldPeriod;
      return true;
    }

    // Destination is free for this classroom, just move.
    target.dayIndex = newDay;
    target.periodIndex = newPeriod;
    return true;
  }

  /// مرحلة تحسين التفضيلات بعد الوصول إلى جدول صالح.
  ///
  /// لا تقبل أي حركة تُنشئ مخالفة إجبارية، وتقبل الحركات التي لا تسوء فيها
  /// التفضيلات (للعبور بين الحلول المتكافئة).
  _GenerationAttemptResult _polishPreferences(
    List<LessonEntity> schedule,
    TimetableCostBreakdown breakdown, {
    required int maxDays,
    required int maxPeriods,
    required Random random,
    required Stopwatch stopwatch,
  }) {
    var current = _cloneState(schedule);
    var currentEval = breakdown;
    var sinceImprovement = 0;

    for (var iteration = 0;
        iteration < _polishMaxIterations &&
            currentEval.preferenceCost > 0 &&
            sinceImprovement < _polishPatience;
        iteration++) {
      if (stopwatch.elapsedMilliseconds >= _timeBudgetMilliseconds) break;

      final candidate = _cloneState(current);
      final moved = random.nextInt(4) == 0
          ? _applyRandomMove(candidate, random, maxDays, maxPeriods)
          : _applyTargetedPreferenceMove(
              candidate,
              random,
              maxDays,
              maxPeriods,
            );
      if (!moved) {
        sinceImprovement++;
        continue;
      }

      final candidateEval = _evaluate(candidate, maxDays, maxPeriods);
      if (candidateEval.isFeasible &&
          candidateEval.preferenceCost <= currentEval.preferenceCost) {
        sinceImprovement =
            candidateEval.preferenceCost < currentEval.preferenceCost
                ? 0
                : sinceImprovement + 1;
        current = candidate;
        currentEval = candidateEval;
      } else {
        sinceImprovement++;
      }
    }

    return _GenerationAttemptResult(current, currentEval);
  }

  /// حركة موجّهة لتفضيل واحد غير محقق: نقل حصة إضافية إلى يومها المستهدف،
  /// أو تقديم حصة مادة «مبكرة» إلى درس أسبق في اليوم نفسه.
  bool _applyTargetedPreferenceMove(
    List<LessonEntity> schedule,
    Random random,
    int maxDays,
    int maxPeriods,
  ) {
    final byClassroom = <int, List<LessonEntity>>{};
    // classroomId -> subjectId -> day -> lessons
    final groupDays = <int, Map<int, Map<int, List<LessonEntity>>>>{};
    final lateEarlyLessons = <LessonEntity>[];

    for (final lesson in schedule) {
      final classroom = lesson.classroom;
      if (classroom == null) continue;
      byClassroom.putIfAbsent(classroom.id, () => <LessonEntity>[]).add(lesson);
      final day = lesson.dayIndex;
      final period = lesson.periodIndex;
      final subject = lesson.subject;
      if (day == null || period == null || subject == null) continue;
      groupDays
          .putIfAbsent(
              classroom.id, () => <int, Map<int, List<LessonEntity>>>{})
          .putIfAbsent(subject.id, () => <int, List<LessonEntity>>{})
          .putIfAbsent(day, () => <LessonEntity>[])
          .add(lesson);
      if (subject.preferEarlyPeriods && period > 0 && !lesson.isPinned) {
        lateEarlyLessons.add(lesson);
      }
    }

    // Collect misplaced extras: (lesson on an over-target day, under-target day).
    final extraMoves = <MapEntry<LessonEntity, int>>[];
    groupDays.forEach((classroomId, subjectMap) {
      subjectMap.forEach((subjectId, dayMap) {
        final group = _groupForIds(classroomId, subjectId);
        if (group == null) return;
        final distribution = group.distribution;
        if (!distribution.isBalanced ||
            distribution.maxPerDay == distribution.minPerDay) {
          return;
        }
        final underDays = <int>[
          for (final day in distribution.eligibleDays)
            if ((dayMap[day]?.length ?? 0) < distribution.targetFor(day)) day,
        ];
        if (underDays.isEmpty) return;
        dayMap.forEach((day, lessons) {
          if (lessons.length <= distribution.targetFor(day)) return;
          for (final lesson in lessons) {
            if (lesson.isPinned) continue;
            for (final underDay in underDays) {
              extraMoves.add(MapEntry(lesson, underDay));
            }
          }
        });
      });
    });

    final useExtras = extraMoves.isNotEmpty &&
        (lateEarlyLessons.isEmpty || random.nextBool());
    if (useExtras) {
      final move = extraMoves[random.nextInt(extraMoves.length)];
      final lesson = move.key;
      final classroomId = lesson.classroom!.id;
      final periodsOnDay = _periodsForClassroomOnDay(
          classroomId, move.value, maxDays, maxPeriods);
      if (periodsOnDay <= 0) return false;
      return _moveOrSwapWithinClassroom(
        byClassroom[classroomId]!,
        lesson,
        move.value,
        random.nextInt(periodsOnDay),
      );
    }

    if (lateEarlyLessons.isEmpty) return false;
    final lesson = lateEarlyLessons[random.nextInt(lateEarlyLessons.length)];
    return _moveOrSwapWithinClassroom(
      byClassroom[lesson.classroom!.id]!,
      lesson,
      lesson.dayIndex!,
      random.nextInt(lesson.periodIndex!),
    );
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
      final dailyPeriods = _dailyPeriodsForClassroom(
        classroomId,
        maxDays,
        maxPeriods,
      );
      final maxClassroomPeriods =
          dailyPeriods.isEmpty ? maxPeriods : dailyPeriods.reduce(max);
      final availableSlots = <int>[];
      for (var day = 0; day < maxDays; day++) {
        final periodsOnDay =
            day < dailyPeriods.length ? dailyPeriods[day] : maxPeriods;
        for (var period = 0; period < periodsOnDay; period++) {
          final slot = day * 100 + period;
          if (!occupiedSlots.contains(slot)) {
            availableSlots.add(slot);
          }
        }
      }

      final orderedLessons = _orderLessonsByRestriction(
        unpinned,
        maxDays: maxDays,
        maxPeriods: maxClassroomPeriods,
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
        if (subject.consecutiveness != SubjectConsecutiveness.any) {
          score += 50;
        }
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
    // Hard constraints are a feasibility filter, not merely a weighted penalty.
    // If at least one valid slot remains, no invalid slot can be selected during
    // initialization. When none remains, retain the legacy fallback so the
    // search can report the impossible state through its normal cost/diagnostic
    // path instead of looping forever or silently dropping the lesson.
    final hardFeasibleSlots = availableSlots
        .where((slot) => _isHardFeasibleSlot(
              lesson,
              slot ~/ 100,
              slot % 100,
              assignedLessons,
            ))
        .toList();
    final candidateSlots =
        hardFeasibleSlots.isNotEmpty ? hardFeasibleSlots : availableSlots;

    final scoredSlots = [
      for (var slot in candidateSlots)
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

  bool _isHardFeasibleSlot(
    LessonEntity lesson,
    int day,
    int period,
    List<LessonEntity> assignedLessons,
  ) {
    final teacher = lesson.teacher;
    if (teacher != null) {
      if (assignedLessons.any((assigned) =>
          assigned.teacher?.id == teacher.id &&
          assigned.dayIndex == day &&
          assigned.periodIndex == period)) {
        return false;
      }
      if (teacher.unavailableDays.contains(day)) return false;
      if (!SchedulingRules.isPeriodAllowed(teacher.allowedPeriods, period)) {
        return false;
      }
    }

    final subject = lesson.subject;
    if (subject != null &&
        !SchedulingRules.isPeriodAllowed(subject.allowedPeriods, period)) {
      return false;
    }

    return true;
  }

  int _initialSlotPenalty(
    LessonEntity lesson,
    int day,
    int period,
    List<LessonEntity> assignedLessons,
  ) {
    const hardConflictPenalty = 100000;
    const dailyLimitPenalty = 10000;
    const consecutivenessPenalty = 10000;
    const targetDayPenalty = 300;

    var penalty = 0;
    final teacher = lesson.teacher;
    final subject = lesson.subject;

    if (!_isHardFeasibleSlot(lesson, day, period, assignedLessons)) {
      penalty += hardConflictPenalty;
    }

    if (teacher != null) {
      final dailyLoad = assignedLessons
          .where((assigned) =>
              assigned.teacher?.id == teacher.id && assigned.dayIndex == day)
          .length;
      if (dailyLoad >= teacher.maxLessonsPerDay) {
        // Keep daily load ahead of preferences, while still allowing a fallback
        // when every day is full.
        penalty +=
            dailyLimitPenalty * (dailyLoad - teacher.maxLessonsPerDay + 1);
      }
    }

    if (subject != null && lesson.classroom != null) {
      final classroom = lesson.classroom!;
      final group = _groupFor(classroom, subject);
      final sameSubjectPeriods = assignedLessons
          .where((assigned) =>
              assigned.classroom?.id == classroom.id &&
              assigned.subject?.id == subject.id &&
              assigned.dayIndex == day &&
              assigned.periodIndex != null)
          .map((assigned) => assigned.periodIndex!)
          .toList();

      if (sameSubjectPeriods.length >= group.effectiveMax) {
        penalty += dailyLimitPenalty;
      }

      // Consecutiveness is a hard rule: never prefer a slot that adds a gap
      // (consecutive) or an adjacency (non-consecutive). `any` stays neutral.
      final before = SchedulingRules.consecutivenessViolations(
        group.policy,
        sameSubjectPeriods,
      );
      final after = SchedulingRules.consecutivenessViolations(
        group.policy,
        [...sameSubjectPeriods, period],
      );
      if (after > before) {
        penalty += consecutivenessPenalty * (after - before);
      }

      // Weekly distribution: fill each day up to its target (base share plus
      // the extras that start from Sunday) before stacking another day.
      if (group.distribution.isBalanced &&
          sameSubjectPeriods.length >= group.distribution.targetFor(day)) {
        penalty += targetDayPenalty;
      }
    }

    if (subject?.preferEarlyPeriods == true) {
      // This remains a soft preference: it guides ordering only and never
      // removes a hard-feasible slot from the candidate set.
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

  /// تكلفة مخالفات القيود الإجبارية فقط (صفر = جدول صالح).
  int calculateCost(List<LessonEntity> state) {
    return _calculateCost(state, settings.daysPerWeek, settings.periodsPerDay);
  }

  /// تقييم كامل: المخالفات الإجبارية + التفضيلات.
  TimetableCostBreakdown evaluate(List<LessonEntity> state) {
    return _evaluate(state, settings.daysPerWeek, settings.periodsPerDay);
  }

  TimetableScheduleSnapshot snapshot(List<LessonEntity> state) {
    return _snapshot(state);
  }

  /// يجمع حصص كل مجموعة (صف × مادة) حسب اليوم.
  ///
  /// classroomId -> subjectId -> day -> lessons.
  Map<int, Map<int, Map<int, List<LessonEntity>>>> _groupLessonsByDay(
    List<LessonEntity> state,
  ) {
    final result = <int, Map<int, Map<int, List<LessonEntity>>>>{};
    for (final lesson in state) {
      final classroom = lesson.classroom;
      final subject = lesson.subject;
      if (classroom == null || subject == null) continue;
      // Groups whose lessons are all unassigned still carry a distribution.
      final dayMap = result
          .putIfAbsent(
              classroom.id, () => <int, Map<int, List<LessonEntity>>>{})
          .putIfAbsent(subject.id, () => <int, List<LessonEntity>>{});
      final day = lesson.dayIndex;
      if (day == null || lesson.periodIndex == null) continue;
      dayMap.putIfAbsent(day, () => <LessonEntity>[]).add(lesson);
    }
    return result;
  }

  /// مجموعة لا تظهر في الحصص الأصلية للمحرك (حالة خارجية): تُبنى من الحالة.
  _SubjectGroup _groupFromState(
    int classroomId,
    int subjectId,
    List<LessonEntity> state,
  ) {
    final groupLessons = state
        .where((lesson) =>
            lesson.classroom?.id == classroomId &&
            lesson.subject?.id == subjectId)
        .toList();
    final sample = groupLessons.first;
    return _groupFor(sample.classroom!, sample.subject!, groupLessons);
  }

  _SubjectGroup? _groupForState(
    int classroomId,
    int subjectId,
    Map<int, List<LessonEntity>> dayMap,
    List<LessonEntity> state,
  ) {
    final cached = _groupCache[classroomId]?[subjectId];
    if (cached != null) return cached;
    LessonEntity? sample;
    for (final lessons in dayMap.values) {
      if (lessons.isNotEmpty) {
        sample = lessons.first;
        break;
      }
    }
    sample ??= _lessonsByGroup[classroomId]?[subjectId]?.first;
    final classroom = sample?.classroom ?? _classroomsById[classroomId];
    final subject = sample?.subject ?? _subjectsById[subjectId];
    if (classroom == null || subject == null) return null;
    final fallback = state
        .where((lesson) =>
            lesson.classroom?.id == classroomId &&
            lesson.subject?.id == subjectId)
        .toList();
    return _groupFor(classroom, subject, fallback);
  }

  // ⚠️ عقد معماري: أي تعديل هنا يجب أن ينعكس في الدالة المقابلة.
  // كل شرط يرفع تكلفة المخالفات الإجبارية يجب أن يقابله تشخيص إجباري مماثل
  // (isHard: true). التفضيلات (الأحد/المبكر) لا تُفشل التوليد ولا تُشخَّص.
  List<ConflictDiagnostic> _getConflictDiagnostics(
      List<LessonEntity> state, int maxDays, int maxPeriods) {
    final diagnostics = <ConflictDiagnostic>[];

    final classroomSlotOwners = <int, Map<int, int>>{};
    final teacherSlotOwners = <int, Map<int, int>>{};
    final teacherDailyLessons = <int, Map<int, List<int>>>{};

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
        final allowedPeriodsOnDay = _periodsForClassroomOnDay(
          classroomId,
          day,
          maxDays,
          maxPeriods,
        );
        if (day < 0 ||
            day >= maxDays ||
            period < 0 ||
            period >= allowedPeriodsOnDay) {
          addDiagnostic(
            GenericSolverFailure(
              'الفصل \"${lesson.classroom!.name}\": الحصة ${period + 1} في اليوم ${day + 1} خارج التوزيع اليومي المعتمد للصف.',
            ),
            lessonIds: [lesson.id],
          );
        }

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

        if (!SchedulingRules.isPeriodAllowed(
            lesson.teacher!.allowedPeriods, period)) {
          addDiagnostic(
            TeacherNotAllowedPeriodConflict(lesson.teacher!.name, period),
            lessonIds: [lesson.id],
          );
        }
      }

      if (lesson.subject != null && lesson.classroom != null) {
        if (!SchedulingRules.isPeriodAllowed(
            lesson.subject!.allowedPeriods, period)) {
          addDiagnostic(
            SubjectNotAllowedPeriodConflict(lesson.subject!.name, period),
            lessonIds: [lesson.id],
          );
        }
      }
    }

    // Per (classroom × subject) rules: daily maximum, balanced weekly
    // distribution, and consecutiveness policy.
    final grouped = _groupLessonsByDay(state);
    grouped.forEach((classroomId, subjectMap) {
      subjectMap.forEach((subjectId, dayMap) {
        final group = _groupForState(classroomId, subjectId, dayMap, state);
        if (group == null) return;
        final groupLessonIds = <int>[
          for (final lessons in dayMap.values)
            for (final lesson in lessons) lesson.id,
        ];
        final classroomName = _classroomName(classroomId, dayMap);
        final subjectName = _subjectName(subjectId, dayMap);
        final effectiveMax = group.effectiveMax;

        dayMap.forEach((day, lessons) {
          if (lessons.length > effectiveMax) {
            addDiagnostic(
              SubjectMaxPerDayExceeded(
                subjectName,
                classroomName,
                day,
                effectiveMax,
                lessons.length,
              ),
              lessonIds: [for (final lesson in lessons) lesson.id],
            );
          }

          final sorted = List<LessonEntity>.from(lessons)
            ..sort((a, b) => a.periodIndex!.compareTo(b.periodIndex!));
          for (var index = 0; index < sorted.length - 1; index++) {
            final first = sorted[index];
            final second = sorted[index + 1];
            final gap = second.periodIndex! - first.periodIndex!;
            if (group.policy == SubjectConsecutiveness.consecutive && gap > 1) {
              addDiagnostic(
                NonConsecutiveSubjectPeriodsConflict(
                  subjectName,
                  classroomName,
                  day,
                ),
                lessonIds: [first.id, second.id],
              );
            } else if (group.policy == SubjectConsecutiveness.nonConsecutive &&
                gap == 1) {
              addDiagnostic(
                AdjacentSubjectPeriodsConflict(
                  subjectName,
                  classroomName,
                  day,
                ),
                lessonIds: [first.id, second.id],
              );
            }
          }
        });

        final distribution = group.distribution;
        if (distribution.isBalanced) {
          for (final day in distribution.eligibleDays) {
            final count = dayMap[day]?.length ?? 0;
            if (count < distribution.minPerDay) {
              addDiagnostic(
                SubjectDailyDistributionConflict(
                  subjectName,
                  classroomName,
                  day,
                  count,
                  distribution.minPerDay,
                ),
                lessonIds: groupLessonIds,
              );
            }
          }
        }
      });
    });

    final finalCost = _calculateCost(state, maxDays, maxPeriods);
    if (finalCost > 0 && !diagnostics.any((diagnostic) => diagnostic.isHard)) {
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

  String _classroomName(int classroomId, Map<int, List<LessonEntity>> dayMap) {
    for (final lessons in dayMap.values) {
      if (lessons.isNotEmpty) return lessons.first.classroom!.name;
    }
    return _classroomsById[classroomId]?.name ??
        (classrooms.isNotEmpty ? classrooms.first.name : '');
  }

  String _subjectName(int subjectId, Map<int, List<LessonEntity>> dayMap) {
    for (final lessons in dayMap.values) {
      if (lessons.isNotEmpty) return lessons.first.subject!.name;
    }
    return _subjectsById[subjectId]?.name ?? '';
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

  // 2. The Cost Function (Penalty Calculation) — hard violations only.
  int _calculateCost(List<LessonEntity> state, int maxDays, int maxPeriods) {
    return _evaluate(state, maxDays, maxPeriods).violationCost;
  }

  // ⚠️ عقد معماري: أي تعديل هنا يجب أن ينعكس في _getConflictDiagnostics.
  // كل شرط يرفع violationCost يجب أن يقابله تشخيص إجباري مماثل.
  TimetableCostBreakdown _evaluate(
    List<LessonEntity> state,
    int maxDays,
    int maxPeriods,
  ) {
    int violations = 0;
    int preferences = 0;

    // teacherId -> set of (day * 100 + period)
    final Map<int, Set<int>> teacherSlots = {};
    // teacherId -> map of {day -> count}
    final Map<int, Map<int, int>> teacherDailyCounts = {};
    // classroomId -> set of (day * 100 + period)
    final Map<int, Set<int>> classroomSlots = {};
    // classroomId -> subjectId -> day -> periods
    final Map<int, Map<int, Map<int, List<int>>>> subjectPeriods = {};

    for (final lesson in state) {
      if (lesson.classroom != null && lesson.subject != null) {
        // Register the group even when its lessons are unassigned, so the
        // balanced distribution still reports the missing daily share.
        subjectPeriods
            .putIfAbsent(lesson.classroom!.id, () => {})
            .putIfAbsent(lesson.subject!.id, () => {});
      }
      if (lesson.dayIndex == null || lesson.periodIndex == null) continue;

      final int day = lesson.dayIndex!;
      final int period = lesson.periodIndex!;
      final int timeKey = day * 100 + period;

      // Hard Constraint: Classroom Clash (Multiple lessons in same period)
      if (lesson.classroom != null) {
        final int cId = lesson.classroom!.id;
        final allowedPeriodsOnDay = _periodsForClassroomOnDay(
          cId,
          day,
          maxDays,
          maxPeriods,
        );
        if (day < 0 ||
            day >= maxDays ||
            period < 0 ||
            period >= allowedPeriodsOnDay) {
          violations += _hardPenalty;
        }

        if (!classroomSlots.putIfAbsent(cId, () => {}).add(timeKey)) {
          violations += _hardPenalty;
        }
      }

      if (lesson.teacher != null) {
        final teacher = lesson.teacher!;
        final int tId = teacher.id;

        // Hard Constraint: Teacher Clash
        if (!teacherSlots.putIfAbsent(tId, () => {}).add(timeKey)) {
          violations += _hardPenalty;
        }

        // Hard Constraint: Teacher Daily Limit
        final daily = teacherDailyCounts.putIfAbsent(tId, () => {});
        final dayCount = (daily[day] ?? 0) + 1;
        daily[day] = dayCount;
        if (dayCount > teacher.maxLessonsPerDay) {
          violations += _hardPenalty;
        }

        // Teacher unavailable days
        if (teacher.unavailableDays.contains(day)) {
          violations += _hardPenalty;
        }

        // Teacher allowed periods
        if (!SchedulingRules.isPeriodAllowed(teacher.allowedPeriods, period)) {
          violations += _hardPenalty;
        }
      }

      if (lesson.classroom != null && lesson.subject != null) {
        final subject = lesson.subject!;
        subjectPeriods
            .putIfAbsent(lesson.classroom!.id, () => {})
            .putIfAbsent(subject.id, () => {})
            .putIfAbsent(day, () => [])
            .add(period);

        // Subject allowed periods (hard)
        if (!SchedulingRules.isPeriodAllowed(subject.allowedPeriods, period)) {
          violations += _hardPenalty;
        }

        // Preference: early periods for subjects that ask for them.
        if (subject.preferEarlyPeriods) {
          preferences += period * _earlyPeriodPenalty;
        }
      }
    }

    // Per (classroom × subject) rules.
    void evaluateGroup(_SubjectGroup group, Map<int, List<int>> dayMap) {
      final counts = <int, int>{
        for (final entry in dayMap.entries) entry.key: entry.value.length,
      };
      // Hard: daily maximum (user constraint, tightened by balance).
      violations +=
          group.distribution.excess(counts, group.userMax) * _hardPenalty;
      // Hard: balanced weekly distribution (base share on each eligible day).
      violations += group.distribution.shortfall(counts) * _hardPenalty;
      // Hard: consecutiveness policy.
      for (final periods in dayMap.values) {
        violations += SchedulingRules.consecutivenessViolations(
              group.policy,
              periods,
            ) *
            _hardPenalty;
      }
      // Preference: extras start from Sunday.
      preferences +=
          group.distribution.misplacedExtras(counts) * _misplacedExtraPenalty;
    }

    subjectPeriods.forEach((classroomId, subjectMap) {
      subjectMap.forEach((subjectId, dayMap) {
        final group = _groupCache[classroomId]?[subjectId] ??
            _groupForIds(classroomId, subjectId) ??
            _groupFromState(classroomId, subjectId, state);
        evaluateGroup(group, dayMap);
      });
    });

    return TimetableCostBreakdown(
      violationCost: violations,
      preferenceCost: preferences,
    );
  }
}
