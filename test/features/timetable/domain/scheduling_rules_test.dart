import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/features/timetable/domain/services/scheduling_rules.dart';

void main() {
  group('SubjectWeeklyDistribution', () {
    test('6 lessons on 5 days: one per day, extra starts from Sunday', () {
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: 6,
        eligibleDays: const [0, 1, 2, 3, 4],
      );

      expect(distribution.isBalanced, isTrue);
      expect(distribution.minPerDay, 1);
      expect(distribution.maxPerDay, 2);
      expect(
        [for (var day = 0; day < 5; day++) distribution.targetFor(day)],
        [2, 1, 1, 1, 1],
      );
    });

    test('7 lessons on 5 days targets Sunday then Monday for extras', () {
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: 7,
        eligibleDays: const [4, 3, 2, 1, 0],
      );

      expect(
        [for (var day = 0; day < 5; day++) distribution.targetFor(day)],
        [2, 2, 1, 1, 1],
      );
    });

    test('exact multiples have no extras and a fixed daily share', () {
      final five = SubjectWeeklyDistribution.compute(
        lessonCount: 5,
        eligibleDays: const [0, 1, 2, 3, 4],
      );
      final ten = SubjectWeeklyDistribution.compute(
        lessonCount: 10,
        eligibleDays: const [0, 1, 2, 3, 4],
      );

      expect(five.minPerDay, 1);
      expect(five.maxPerDay, 1);
      expect(ten.minPerDay, 2);
      expect(ten.maxPerDay, 2);
      expect(five.misplacedExtras(const {0: 1, 1: 1, 2: 1, 3: 1, 4: 1}), 0);
    });

    test('unavailable Sunday moves the extras to the first eligible days', () {
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: 6,
        eligibleDays: const [1, 2, 3, 4],
      );

      expect(distribution.targetFor(0), 0);
      expect(
        [for (var day = 1; day < 5; day++) distribution.targetFor(day)],
        [2, 2, 1, 1],
      );
      expect(distribution.minFor(0), 0);
      expect(distribution.minFor(1), 1);
    });

    test('fewer lessons than days imposes no minimum and keeps user max', () {
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: 3,
        eligibleDays: const [0, 1, 2, 3, 4],
      );

      expect(distribution.isBalanced, isFalse);
      expect(distribution.minPerDay, 0);
      expect(distribution.maxPerDay, isNull);
      expect(distribution.effectiveMax(2), 2);
      expect(distribution.shortfall(const {0: 3}), 0);
    });

    test('effective max is the tighter of user max and balanced ceiling', () {
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: 6,
        eligibleDays: const [0, 1, 2, 3, 4],
      );

      expect(distribution.effectiveMax(3), 2);
      expect(distribution.effectiveMax(2), 2);
      expect(distribution.effectiveMax(1), 1);
    });

    test('shortfall, excess and misplaced extras are measured separately', () {
      final distribution = SubjectWeeklyDistribution.compute(
        lessonCount: 6,
        eligibleDays: const [0, 1, 2, 3, 4],
      );

      // [2,1,1,1,1] is ideal.
      const ideal = {0: 2, 1: 1, 2: 1, 3: 1, 4: 1};
      expect(distribution.shortfall(ideal), 0);
      expect(distribution.excess(ideal, 2), 0);
      expect(distribution.misplacedExtras(ideal), 0);

      // [1,1,1,1,2] is valid but the extra is not on Sunday.
      const lateExtra = {0: 1, 1: 1, 2: 1, 3: 1, 4: 2};
      expect(distribution.shortfall(lateExtra), 0);
      expect(distribution.misplacedExtras(lateExtra), 1);

      // [2,2,0,1,1] leaves Tuesday empty: a hard shortfall.
      const missingDay = {0: 2, 1: 2, 3: 1, 4: 1};
      expect(distribution.shortfall(missingDay), 1);

      // [3,0,1,1,1] exceeds the balanced ceiling even with user max 3.
      const stacked = {0: 3, 2: 1, 3: 1, 4: 1};
      expect(distribution.excess(stacked, 3), 1);
      expect(distribution.shortfall(stacked), 1);
    });
  });

  group('SchedulingRules.consecutivenessViolations', () {
    test('consecutive counts gaps only', () {
      const policy = SubjectConsecutiveness.consecutive;
      expect(SchedulingRules.consecutivenessViolations(policy, [0, 1]), 0);
      expect(SchedulingRules.consecutivenessViolations(policy, [2, 0]), 1);
      expect(SchedulingRules.consecutivenessViolations(policy, [0, 1, 3]), 1);
      expect(SchedulingRules.consecutivenessViolations(policy, [4]), 0);
    });

    test('nonConsecutive counts adjacent pairs only', () {
      const policy = SubjectConsecutiveness.nonConsecutive;
      expect(SchedulingRules.consecutivenessViolations(policy, [0, 1]), 1);
      expect(SchedulingRules.consecutivenessViolations(policy, [0, 2]), 0);
      expect(SchedulingRules.consecutivenessViolations(policy, [1, 2, 3]), 2);
    });

    test('any never reports a violation', () {
      const policy = SubjectConsecutiveness.any;
      expect(SchedulingRules.consecutivenessViolations(policy, [0, 1]), 0);
      expect(SchedulingRules.consecutivenessViolations(policy, [0, 5]), 0);
    });

    test('the three policies classify the same placements differently', () {
      const adjacent = [2, 3];
      const split = [1, 4];
      int count(SubjectConsecutiveness policy, List<int> periods) =>
          SchedulingRules.consecutivenessViolations(policy, periods);

      expect(count(SubjectConsecutiveness.consecutive, adjacent), 0);
      expect(count(SubjectConsecutiveness.nonConsecutive, adjacent), 1);
      expect(count(SubjectConsecutiveness.any, adjacent), 0);

      expect(count(SubjectConsecutiveness.consecutive, split), 1);
      expect(count(SubjectConsecutiveness.nonConsecutive, split), 0);
      expect(count(SubjectConsecutiveness.any, split), 0);
    });
  });

  group('SchedulingRules capacity helpers', () {
    test('maxPlaceableOnDay respects the policy structure', () {
      const allowed = [0, 1, 3, 4, 5];
      expect(
        SchedulingRules.maxPlaceableOnDay(
          allowedPeriods: allowed,
          policy: SubjectConsecutiveness.any,
          maxPerDay: 9,
        ),
        5,
      );
      expect(
        SchedulingRules.maxPlaceableOnDay(
          allowedPeriods: allowed,
          policy: SubjectConsecutiveness.consecutive,
          maxPerDay: 9,
        ),
        3,
      );
      expect(
        SchedulingRules.maxPlaceableOnDay(
          allowedPeriods: allowed,
          policy: SubjectConsecutiveness.nonConsecutive,
          maxPerDay: 9,
        ),
        3,
      );
      expect(
        SchedulingRules.maxPlaceableOnDay(
          allowedPeriods: allowed,
          policy: SubjectConsecutiveness.any,
          maxPerDay: 2,
        ),
        2,
      );
      expect(
        SchedulingRules.maxPlaceableOnDay(
          allowedPeriods: const [],
          policy: SubjectConsecutiveness.any,
          maxPerDay: 2,
        ),
        0,
      );
    });

    test('profile intersects teacher and subject allowed periods', () {
      const profile = LessonPlacementProfile(
        teacherUnavailableDays: [2],
        teacherAllowedPeriods: [0, 1, 2, 6],
        subjectAllowedPeriods: [1, 2, 6],
      );

      expect(profile.allowedPeriodsOnDay(0, 7), [1, 2, 6]);
      // Period 6 does not exist on a 6-period day.
      expect(profile.allowedPeriodsOnDay(1, 6), [1, 2]);
      // Teacher does not teach on day 2.
      expect(profile.allowedPeriodsOnDay(2, 7), isEmpty);
      // Unknown day length keeps the explicit allowed periods.
      expect(profile.allowedPeriodsOnDay(0, null), [1, 2, 6]);
    });

    test('eligibleDays excludes days off and days without allowed periods', () {
      const profile = LessonPlacementProfile(
        teacherUnavailableDays: [4],
        subjectAllowedPeriods: [6],
      );
      const dailyPeriods = [7, 6, 7, 6, 7];

      final days = SchedulingRules.eligibleDays(
        daysPerWeek: 5,
        periodsOnDay: (day) => dailyPeriods[day],
        profiles: const [profile],
      );

      expect(days, [0, 2]);
    });
  });
}
