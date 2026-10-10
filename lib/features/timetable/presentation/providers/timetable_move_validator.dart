import '../../../../core/models/lesson.dart';
import '../../../../core/models/subject_consecutiveness.dart';
import '../../domain/services/scheduling_rules.dart';
import 'timetable_interaction_index.dart';

/// موضع مقترح لحصة أثناء النقل أو التبديل اليدوي.
typedef TimetableProposedSlot = ({int dayIndex, int periodIndex});

/// تحقق السحب والتبديل اليدوي بالقواعد نفسها التي يطبّقها المحرك.
///
/// * [validatePlacement]: فحوص الحصة الواحدة (الخانة، تعارض المعلم/الصف، الحد
///   اليومي، أيام عدم التدريس، الدروس المسموحة للمادة **وللمعلم**).
/// * [validateGroupRules]: قواعد مجموعة (صف × مادة) على الحالة **بعد** الحركة:
///   سياسة التتابع والتوزيع الأسبوعي. للتبديل تُطبَّق الحركتان معًا.
///   تُرفض الحركة إذا زادت المخالفة في **أي يوم** (لا يكفي ثبات المجموع
///   الأسبوعي، فلا تُنقل مخالفة قديمة من يوم إلى آخر)؛ ولا تُقفل الجداول
///   القديمة المحفوظة قبل تطبيق هذه القواعد، فيبقى إصلاحها أو تقليلها يدويًا
///   ممكنًا.
class TimetableMoveValidator {
  const TimetableMoveValidator(this.index);

  final TimetableInteractionIndex index;

  String? validatePlacement({
    required Lesson lesson,
    required int newDay,
    required int newPeriod,
    required Set<int> excludedLessonIds,
    required String operationLabel,
  }) {
    final teacher = lesson.teacher.value;
    final subject = lesson.subject.value;
    final classroom = lesson.classroom.value;

    final allowedPeriodsOnDay = index.allowedPeriodsForClassroomOnDay(
      classroom: classroom,
      dayIndex: newDay,
    );
    if (allowedPeriodsOnDay != null && newPeriod >= allowedPeriodsOnDay) {
      return 'لا يمكن $operationLabel: الحصة (${newPeriod + 1}) خارج التوزيع اليومي المعتمد للصف (${classroom?.name ?? ''}) في اليوم المقترح';
    }

    if (index.hasTeacherConflict(
      teacherId: teacher?.id,
      dayIndex: newDay,
      periodIndex: newPeriod,
      excludedLessonIds: excludedLessonIds,
    )) {
      return 'لا يمكن $operationLabel: الأستاذ (${teacher?.name ?? ''}) لديه حصة أخرى في نفس الوقت';
    }

    if (index.hasClassroomConflict(
      classroomId: classroom?.id,
      dayIndex: newDay,
      periodIndex: newPeriod,
      excludedLessonIds: excludedLessonIds,
    )) {
      return 'لا يمكن $operationLabel: الصف مشغول بالفعل في الحصة المقترحة';
    }

    if (subject != null && classroom != null) {
      final maxAllowed = index.maxPeriodsPerDay(
        grade: classroom.grade,
        subjectName: subject.name,
      );
      final subjectCountOnNewDay = index.subjectCountOnDay(
        classroomId: classroom.id,
        subjectId: subject.id,
        dayIndex: newDay,
        excludedLessonIds: excludedLessonIds,
      );
      if (subjectCountOnNewDay >= maxAllowed) {
        return 'لا يمكن $operationLabel: تجاوز الحد الأقصى ($maxAllowed حصص) لمادة (${subject.name}) في اليوم المقترح';
      }
    }

    if (lesson.dayIndex != newDay && teacher != null) {
      final teacherLessonsNewDay = index.teacherCountOnDay(
        teacherId: teacher.id,
        dayIndex: newDay,
        excludedLessonIds: excludedLessonIds,
      );
      if (teacherLessonsNewDay >= teacher.maxLessonsPerDay) {
        return 'لا يمكن $operationLabel: تجاوز الحد الأقصى للحصص اليومية للأستاذ (${teacher.name})';
      }
    }

    if (teacher?.unavailableDays.contains(newDay) ?? false) {
      return 'لا يمكن $operationLabel: الأستاذ مفرغ في اليوم المقترح ولا يمكن وضع حصة له';
    }

    if (teacher != null &&
        !SchedulingRules.isPeriodAllowed(teacher.allowedPeriods, newPeriod)) {
      return 'لا يمكن $operationLabel: الأستاذ (${teacher.name}) غير مسموح له بالتدريس في الحصة (${newPeriod + 1}) بناءً على إعداداته';
    }

    if (subject != null &&
        subject.allowedPeriods.isNotEmpty &&
        !subject.allowedPeriods.contains(newPeriod)) {
      return 'لا يمكن $operationLabel: المادة غير مسموح بتدريسها في الحصة (${newPeriod + 1}) بناءً على إعداداتها';
    }

    return null;
  }

  /// يفحص قواعد مجموعات (صف × مادة) المتأثرة بالحركات [moves]
  /// (معرّف الحصة ← موضعها الجديد).
  String? validateGroupRules({
    required Map<int, TimetableProposedSlot> moves,
    required String operationLabel,
  }) {
    final checkedGroups = <String>{};
    for (final lessonId in moves.keys) {
      final lesson = index.lessonById(lessonId);
      final classroom = lesson?.classroom.value;
      final subject = lesson?.subject.value;
      if (lesson == null || classroom == null || subject == null) continue;
      if (!checkedGroups.add('${classroom.id}:${subject.id}')) continue;

      final groupLessons = index.lessonsById.values
          .where((candidate) =>
              candidate.classroom.value?.id == classroom.id &&
              candidate.subject.value?.id == subject.id)
          .toList(growable: false);

      final before = <int, List<int>>{};
      final after = <int, List<int>>{};
      for (final candidate in groupLessons) {
        final day = candidate.dayIndex;
        final period = candidate.periodIndex;
        if (day != null && period != null) {
          before.putIfAbsent(day, () => <int>[]).add(period);
        }
        final moved = moves[candidate.id];
        final afterDay = moved?.dayIndex ?? day;
        final afterPeriod = moved?.periodIndex ?? period;
        if (afterDay != null && afterPeriod != null) {
          after.putIfAbsent(afterDay, () => <int>[]).add(afterPeriod);
        }
      }

      final policy = subject.consecutiveness;
      if (_consecutivenessWorsensOnAnyDay(policy, before, after)) {
        if (policy == SubjectConsecutiveness.consecutive) {
          return 'لا يمكن $operationLabel: مادة (${subject.name}) مضبوطة على «متتالي»، فيجب أن تكون حصصها في اليوم نفسه متصلة بلا فراغ بينها';
        }
        return 'لا يمكن $operationLabel: مادة (${subject.name}) مضبوطة على «غير متتالي»، فلا يجوز أن تتجاور حصتان منها في اليوم نفسه';
      }

      final profiles = [
        for (final candidate in groupLessons)
          LessonPlacementProfile(
            teacherUnavailableDays:
                candidate.teacher.value?.unavailableDays ?? const <int>[],
            teacherAllowedPeriods:
                candidate.teacher.value?.allowedPeriods ?? const <int>[],
            subjectAllowedPeriods:
                candidate.subject.value?.allowedPeriods ?? const <int>[],
          ),
      ];
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: groupLessons.length,
        eligibleDays: SchedulingRules.eligibleDays(
          daysPerWeek: index.daysPerWeek,
          periodsOnDay: (day) => index.allowedPeriodsForClassroomOnDay(
            classroom: classroom,
            dayIndex: day,
          ),
          profiles: profiles,
        ),
      );
      final userMax = index.maxPeriodsPerDay(
        grade: classroom.grade,
        subjectName: subject.name,
      );
      if (_distributionWorsensOnAnyDay(distribution, before, after, userMax)) {
        final range = distribution.maxPerDay == distribution.minPerDay
            ? '${distribution.minPerDay}'
            : '${distribution.minPerDay}–${distribution.effectiveMax(userMax)}';
        return 'لا يمكن $operationLabel: يخالف توزيع حصص مادة (${subject.name}) على أيام الأسبوع؛ المطلوب $range حصة في كل يوم متاح';
      }
    }
    return null;
  }

  /// تُقارن المخالفات **لكل يوم على حدة**: تُرفض الحركة إذا زادت مخالفات
  /// التتابع في أي يوم، ولو نقصت في يوم آخر بالقدر نفسه. فلا تُنقل مخالفة
  /// قديمة من يوم إلى آخر، ويبقى إصلاحها أو تقليلها مسموحًا.
  static bool _consecutivenessWorsensOnAnyDay(
    SubjectConsecutiveness policy,
    Map<int, List<int>> before,
    Map<int, List<int>> after,
  ) {
    for (final entry in after.entries) {
      final beforePeriods = before[entry.key] ?? const <int>[];
      if (SchedulingRules.consecutivenessViolations(policy, entry.value) >
          SchedulingRules.consecutivenessViolations(policy, beforePeriods)) {
        return true;
      }
    }
    return false;
  }

  /// مثل [_consecutivenessWorsensOnAnyDay] للتوزيع الأسبوعي: يُقارن النقص عن
  /// الحد الأدنى والزيادة على الحد الأقصى الفعلي في كل يوم على حدة.
  static bool _distributionWorsensOnAnyDay(
    SubjectWeeklyDistribution distribution,
    Map<int, List<int>> before,
    Map<int, List<int>> after,
    int userMax,
  ) {
    final limit = distribution.effectiveMax(userMax);
    final days = <int>{
      ...before.keys,
      ...after.keys,
      ...distribution.eligibleDays,
    };
    for (final day in days) {
      final countBefore = before[day]?.length ?? 0;
      final countAfter = after[day]?.length ?? 0;
      final minimum = distribution.minFor(day);
      final shortfallBefore = _positivePart(minimum - countBefore);
      final shortfallAfter = _positivePart(minimum - countAfter);
      final excessBefore = _positivePart(countBefore - limit);
      final excessAfter = _positivePart(countAfter - limit);
      if (shortfallAfter > shortfallBefore || excessAfter > excessBefore) {
        return true;
      }
    }
    return false;
  }

  static int _positivePart(int value) => value > 0 ? value : 0;
}
