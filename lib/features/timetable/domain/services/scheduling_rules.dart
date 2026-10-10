import '../../../../core/models/subject_consecutiveness.dart';

/// قيود موضع حصة واحدة كما تراها قواعد الجدولة (بلا Isar ولا Flutter).
///
/// تُبنى من المعلم والمادة المرتبطين بالحصة، وتُستخدم لحساب الأيام والدروس
/// التي يمكن أن تقع فيها الحصة.
class LessonPlacementProfile {
  const LessonPlacementProfile({
    this.teacherUnavailableDays = const <int>[],
    this.teacherAllowedPeriods = const <int>[],
    this.subjectAllowedPeriods = const <int>[],
  });

  /// أيام عدم التدريس للمعلم («أيام التفرغ»).
  final List<int> teacherUnavailableDays;

  /// الدروس المسموحة للمعلم؛ الفارغة تعني السماح بالكل.
  final List<int> teacherAllowedPeriods;

  /// الدروس المسموحة للمادة؛ الفارغة تعني السماح بالكل.
  final List<int> subjectAllowedPeriods;

  /// الدروس المسموحة لهذه الحصة في يوم معيّن، مرتبة تصاعديًا.
  ///
  /// [periodsOnDay] هو عدد حصص الصف في ذلك اليوم. القيمة `null` تعني أن
  /// العدد غير معروف، فتُعاد الدروس المسموحة الصريحة فقط (أو قائمة غير محدودة
  /// يمثّلها [unboundedMarker] إن لم يوجد أي قيد).
  List<int> allowedPeriodsOnDay(int day, int? periodsOnDay) {
    if (teacherUnavailableDays.contains(day)) {
      return const <int>[];
    }
    if (periodsOnDay != null && periodsOnDay <= 0) {
      return const <int>[];
    }

    final upperBound = periodsOnDay;
    final result = <int>[];
    if (upperBound == null) {
      // العدد غير معروف: نعتمد على القوائم الصريحة إن وُجدت.
      final explicit = teacherAllowedPeriods.isNotEmpty
          ? teacherAllowedPeriods
          : subjectAllowedPeriods;
      if (explicit.isEmpty) {
        return const <int>[unboundedMarker];
      }
      for (final period in explicit.toSet()) {
        if (period >= 0 && isAllowed(period)) {
          result.add(period);
        }
      }
    } else {
      for (var period = 0; period < upperBound; period++) {
        if (isAllowed(period)) {
          result.add(period);
        }
      }
    }
    result.sort();
    return result;
  }

  /// هل الدرس [period] مسموح للمعلم وللمادة معًا؟
  bool isAllowed(int period) {
    return SchedulingRules.isPeriodAllowed(teacherAllowedPeriods, period) &&
        SchedulingRules.isPeriodAllowed(subjectAllowedPeriods, period);
  }

  /// قيمة تمثّل «لا قيد على الدروس» عندما يكون عدد حصص اليوم غير معروف.
  static const int unboundedMarker = -1;
}

/// التوزيع الأسبوعي لحصص مادة واحدة في صف واحد.
///
/// السياسة المعتمدة (انظر `docs/scheduling-constraints-design.md`):
/// * إذا كان عدد الحصص `n` لا يقل عن عدد الأيام المتاحة `E`، فكل يوم متاح يأخذ
///   `floor(n/E)` على الأقل و`ceil(n/E)` على الأكثر — **إجباري**.
/// * الحصص الإضافية `n mod E` مستهدفة لأول الأيام المتاحة بدءًا من الأحد —
///   **تفضيل** يُقيَّم ولا يُفشل التوليد.
/// * إذا كان `n < E` فلا حد أدنى ولا حد أعلى من هذه السياسة.
class SubjectWeeklyDistribution {
  SubjectWeeklyDistribution._({
    required this.lessonCount,
    required List<int> eligibleDays,
    required this.isBalanced,
    required this.minPerDay,
    required this.maxPerDay,
    required Map<int, int> targetByDay,
  })  : eligibleDays = List<int>.unmodifiable(eligibleDays),
        _eligibleSet = eligibleDays.toSet(),
        targetByDay = Map<int, int>.unmodifiable(targetByDay);

  factory SubjectWeeklyDistribution.compute({
    required int lessonCount,
    required Iterable<int> eligibleDays,
  }) {
    final days = eligibleDays.toSet().toList()..sort();
    final safeCount = lessonCount < 0 ? 0 : lessonCount;
    final balanced = days.isNotEmpty && safeCount >= days.length;
    if (!balanced) {
      return SubjectWeeklyDistribution._(
        lessonCount: safeCount,
        eligibleDays: days,
        isBalanced: false,
        minPerDay: 0,
        maxPerDay: null,
        targetByDay: const <int, int>{},
      );
    }

    final base = safeCount ~/ days.length;
    final extras = safeCount % days.length;
    final target = <int, int>{
      for (var i = 0; i < days.length; i++)
        days[i]: base + (i < extras ? 1 : 0),
    };
    return SubjectWeeklyDistribution._(
      lessonCount: safeCount,
      eligibleDays: days,
      isBalanced: true,
      minPerDay: base,
      maxPerDay: extras == 0 ? base : base + 1,
      targetByDay: target,
    );
  }

  /// عدد حصص المادة في الصف أسبوعيًا.
  final int lessonCount;

  /// الأيام المتاحة للمادة مرتبة من الأحد.
  final List<int> eligibleDays;
  final Set<int> _eligibleSet;

  /// هل تنطبق قاعدة التوازن الإجبارية (`n ≥ E`)؟
  final bool isBalanced;

  /// الحد الأدنى في كل يوم متاح عند التوازن.
  final int minPerDay;

  /// الحد الأعلى في أي يوم عند التوازن، أو `null` إن لم تنطبق القاعدة.
  final int? maxPerDay;

  /// الهدف اليومي (الأحد أولًا للحصص الإضافية).
  final Map<int, int> targetByDay;

  bool isEligible(int day) => _eligibleSet.contains(day);

  /// الحد الأدنى الإجباري في [day].
  int minFor(int day) =>
      isBalanced && _eligibleSet.contains(day) ? minPerDay : 0;

  /// الهدف المفضّل في [day].
  int targetFor(int day) => targetByDay[day] ?? 0;

  /// الحد الأعلى الفعّال بعد دمج قيد المستخدم [userMax].
  int effectiveMax(int userMax) {
    final policyMax = maxPerDay;
    if (policyMax == null || policyMax >= userMax) {
      return userMax;
    }
    return policyMax;
  }

  /// عدد الحصص الناقصة عن الحد الأدنى في الأيام المتاحة (مخالفة إجبارية).
  int shortfall(Map<int, int> countsByDay) {
    if (!isBalanced) return 0;
    var total = 0;
    for (final day in eligibleDays) {
      final missing = minPerDay - (countsByDay[day] ?? 0);
      if (missing > 0) total += missing;
    }
    return total;
  }

  /// عدد الحصص الزائدة عن الحد الأعلى الفعّال (مخالفة إجبارية).
  int excess(Map<int, int> countsByDay, int userMax) {
    final limit = effectiveMax(userMax);
    var total = 0;
    countsByDay.forEach((_, count) {
      if (count > limit) total += count - limit;
    });
    return total;
  }

  /// عدد الحصص الإضافية الموضوعة في غير يومها المستهدف (تفضيل).
  int misplacedExtras(Map<int, int> countsByDay) {
    if (!isBalanced || maxPerDay == minPerDay) return 0;
    var total = 0;
    countsByDay.forEach((day, count) {
      final over = count - targetFor(day);
      if (over > 0) total += over;
    });
    return total;
  }
}

/// قواعد الجدولة المشتركة بين المحرك والفحص المسبق والتحقق اليدوي.
class SchedulingRules {
  const SchedulingRules._();

  /// القائمة الفارغة تعني السماح بكل الدروس.
  static bool isPeriodAllowed(List<int> allowedPeriods, int period) {
    return allowedPeriods.isEmpty || allowedPeriods.contains(period);
  }

  /// عدد مخالفات سياسة التتابع في دروس مادة واحدة ضمن يوم واحد لصف واحد.
  ///
  /// * [SubjectConsecutiveness.consecutive]: كل فجوة بين درسين متتاليين مخالفة.
  /// * [SubjectConsecutiveness.nonConsecutive]: كل زوج متجاور مخالفة.
  /// * [SubjectConsecutiveness.any]: لا مخالفات.
  static int consecutivenessViolations(
    SubjectConsecutiveness policy,
    Iterable<int> periods,
  ) {
    if (policy == SubjectConsecutiveness.any) return 0;
    final sorted = periods.toList()..sort();
    if (sorted.length < 2) return 0;

    var violations = 0;
    for (var i = 0; i < sorted.length - 1; i++) {
      final gap = sorted[i + 1] - sorted[i];
      if (policy == SubjectConsecutiveness.consecutive && gap > 1) {
        violations++;
      } else if (policy == SubjectConsecutiveness.nonConsecutive && gap == 1) {
        violations++;
      }
    }
    return violations;
  }

  /// الأيام التي يمكن أن تقع فيها حصة واحدة على الأقل من المجموعة.
  ///
  /// [periodsOnDay] تعيد عدد حصص الصف في اليوم، أو `null` إن كان غير معروف.
  static List<int> eligibleDays({
    required int daysPerWeek,
    required int? Function(int day) periodsOnDay,
    required Iterable<LessonPlacementProfile> profiles,
  }) {
    final profileList = profiles.toList(growable: false);
    final result = <int>[];
    for (var day = 0; day < daysPerWeek; day++) {
      final periods = periodsOnDay(day);
      if (periods != null && periods <= 0) continue;
      final anyAllowed = profileList.isEmpty ||
          profileList.any(
            (profile) => profile.allowedPeriodsOnDay(day, periods).isNotEmpty,
          );
      if (anyAllowed) result.add(day);
    }
    return result;
  }

  /// اتحاد الدروس المسموحة لأي حصة من المجموعة في يوم معيّن.
  static List<int> unionAllowedPeriodsOnDay({
    required int day,
    required int? periodsOnDay,
    required Iterable<LessonPlacementProfile> profiles,
  }) {
    final union = <int>{};
    for (final profile in profiles) {
      union.addAll(profile.allowedPeriodsOnDay(day, periodsOnDay));
    }
    return union.toList()..sort();
  }

  /// أكبر عدد حصص للمادة يمكن وضعه في يوم واحد مع احترام الدروس المسموحة
  /// وسياسة التتابع والحد اليومي [maxPerDay].
  static int maxPlaceableOnDay({
    required List<int> allowedPeriods,
    required SubjectConsecutiveness policy,
    required int maxPerDay,
  }) {
    if (allowedPeriods.isEmpty || maxPerDay <= 0) return 0;
    if (allowedPeriods.contains(LessonPlacementProfile.unboundedMarker)) {
      return maxPerDay;
    }

    final sorted = allowedPeriods.toSet().toList()..sort();
    int structural;
    switch (policy) {
      case SubjectConsecutiveness.any:
        structural = sorted.length;
        break;
      case SubjectConsecutiveness.consecutive:
        var longest = 1;
        var run = 1;
        for (var i = 1; i < sorted.length; i++) {
          run = sorted[i] - sorted[i - 1] == 1 ? run + 1 : 1;
          if (run > longest) longest = run;
        }
        structural = longest;
        break;
      case SubjectConsecutiveness.nonConsecutive:
        var picked = 0;
        int? last;
        for (final period in sorted) {
          if (last == null || period - last > 1) {
            picked++;
            last = period;
          }
        }
        structural = picked;
        break;
    }
    return structural < maxPerDay ? structural : maxPerDay;
  }
}
