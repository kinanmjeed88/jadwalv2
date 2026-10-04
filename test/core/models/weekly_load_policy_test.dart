import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';

void main() {
  group('WeeklyLoadMode', () {
    test('default mode is uniform30 and labels contain no year', () {
      expect(WeeklyLoadMode.fallback, WeeklyLoadMode.uniform30);
      expect(WeeklyLoadMode.uniform30.label, '30 حصة لجميع الصفوف');
      expect(WeeklyLoadMode.officialPlan.label, 'الخطة الدراسية الرسمية');

      for (final mode in WeeklyLoadMode.values) {
        expect(mode.name, isNot(contains(RegExp(r'\d{4}'))));
        expect(mode.storageName, isNot(contains(RegExp(r'\d{4}'))));
        expect(mode.label, isNot(contains(RegExp(r'\d{4}'))));
      }

      expect(WeeklyLoadMode.fromStorage('uniform30'), WeeklyLoadMode.uniform30);
      expect(
        WeeklyLoadMode.fromStorage('officialPlan'),
        WeeklyLoadMode.officialPlan,
      );
      expect(WeeklyLoadMode.fromStorage('unknown'), WeeklyLoadMode.uniform30);
      expect(WeeklyLoadMode.fromStorage(null), WeeklyLoadMode.uniform30);
    });
  });

  group('OfficialWeeklyPlan defaults & editing', () {
    test('standard official plan matches exact curriculum defaults', () {
      const plan = OfficialWeeklyPlan.standard();

      // ابتدائي
      expect(
        plan.lessonsFor(OfficialPlanTrack.primary, AcademicGrade.first),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.primary, AcademicGrade.second),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.primary, AcademicGrade.third),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.primary, AcademicGrade.fourth),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.primary, AcademicGrade.fifth),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.primary, AcademicGrade.sixth),
        31,
      );

      // متوسط
      expect(
        plan.lessonsFor(OfficialPlanTrack.middle, AcademicGrade.first),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.middle, AcademicGrade.second),
        30,
      );
      expect(
        plan.lessonsFor(OfficialPlanTrack.middle, AcademicGrade.third),
        30,
      );

      // إعدادي علمي
      expect(
        plan.lessonsFor(
          OfficialPlanTrack.preparatoryScientific,
          AcademicGrade.fourth,
        ),
        30,
      );
      expect(
        plan.lessonsFor(
          OfficialPlanTrack.preparatoryScientific,
          AcademicGrade.fifth,
        ),
        30,
      );
      expect(
        plan.lessonsFor(
          OfficialPlanTrack.preparatoryScientific,
          AcademicGrade.sixth,
        ),
        33,
      );

      // إعدادي أدبي
      expect(
        plan.lessonsFor(
          OfficialPlanTrack.preparatoryLiterary,
          AcademicGrade.fourth,
        ),
        30,
      );
      expect(
        plan.lessonsFor(
          OfficialPlanTrack.preparatoryLiterary,
          AcademicGrade.fifth,
        ),
        31,
      );
      expect(
        plan.lessonsFor(
          OfficialPlanTrack.preparatoryLiterary,
          AcademicGrade.sixth,
        ),
        31,
      );
    });

    test('editing official plan defaults updates non-overridden classrooms only',
        () {
      const standardPlan = OfficialWeeklyPlan.standard();
      final editedPlan = standardPlan.copyWithEntry(
        track: OfficialPlanTrack.primary,
        grade: AcademicGrade.sixth,
        weeklyLessons: 32,
      );

      final config = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.primary,
        weeklyLoadMode: WeeklyLoadMode.officialPlan,
        officialWeeklyPlan: editedPlan,
      );

      final classroomUsingDefault = Classroom()
        ..id = 1
        ..name = 'السادس أ'
        ..grade = 'الصف السادس';

      final classroomWithOverride = Classroom()
        ..id = 2
        ..name = 'السادس ب'
        ..grade = 'الصف السادس'
        ..weeklyOverride = const ClassroomWeeklyOverride(
          weeklyLessons: 31,
          dailyPeriods: <int>[6, 6, 7, 6, 6],
        );

      final resolvedDefault = config.resolveWeeklyConfigForClassroom(
        classroomUsingDefault,
        daysPerWeek: 5,
      );
      final resolvedOverridden = config.resolveWeeklyConfigForClassroom(
        classroomWithOverride,
        daysPerWeek: 5,
      );

      expect(resolvedDefault.weeklyTarget, 32);
      expect(resolvedDefault.isOverridden, isFalse);
      expect(resolvedDefault.dailyPeriods, <int>[7, 7, 6, 6, 6]);

      expect(resolvedOverridden.weeklyTarget, 31);
      expect(resolvedOverridden.isOverridden, isTrue);
      expect(resolvedOverridden.dailyPeriods, <int>[6, 6, 7, 6, 6]);
    });
  });

  group('Classroom resolution with and without override', () {
    test('classroom without override uses general setting', () {
      final sixthPrimary = Classroom()
        ..id = 1
        ..name = 'السادس أ'
        ..grade = 'الصف السادس الابتدائي';
      final sixthScientific = Classroom()
        ..id = 2
        ..name = 'السادس العلمي أ'
        ..grade = 'السادس العلمي';
      final fifthLiterary = Classroom()
        ..id = 3
        ..name = 'الخامس الأدبي أ'
        ..grade = 'الخامس الأدبي';

      final uniformConfig = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.primary,
        weeklyLoadMode: WeeklyLoadMode.uniform30,
      );
      expect(
        uniformConfig
            .resolveWeeklyConfigForClassroom(sixthPrimary, daysPerWeek: 5)
            .weeklyTarget,
        30,
      );

      final officialPrimaryConfig = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.primary,
        weeklyLoadMode: WeeklyLoadMode.officialPlan,
      );
      expect(
        officialPrimaryConfig
            .resolveWeeklyConfigForClassroom(sixthPrimary, daysPerWeek: 5)
            .weeklyTarget,
        31,
      );

      final officialSecondaryConfig = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.middleAndAbove,
        weeklyLoadMode: WeeklyLoadMode.officialPlan,
      );
      expect(
        officialSecondaryConfig
            .resolveWeeklyConfigForClassroom(sixthScientific, daysPerWeek: 5)
            .weeklyTarget,
        33,
      );
      expect(
        officialSecondaryConfig
            .resolveWeeklyConfigForClassroom(fifthLiterary, daysPerWeek: 5)
            .weeklyTarget,
        31,
      );
    });

    test('classroom with override uses override regardless of global mode', () {
      final classroom = Classroom()
        ..id = 10
        ..name = 'الأول أ'
        ..grade = 'الصف الأول'
        ..weeklyOverride = const ClassroomWeeklyOverride(weeklyLessons: 31);

      final uniformConfig = AppConfig.initial().copyWith(
        weeklyLoadMode: WeeklyLoadMode.uniform30,
      );
      final resolved = uniformConfig.resolveWeeklyConfigForClassroom(
        classroom,
        daysPerWeek: 5,
      );

      expect(resolved.isOverridden, isTrue);
      expect(resolved.weeklyTarget, 31);
      expect(resolved.dailyPeriods, <int>[7, 6, 6, 6, 6]);
    });
  });

  group('DailyDistribution & WeeklyLoadValidator', () {
    test('30 lessons distribution -> [6, 6, 6, 6, 6]', () {
      final dist = DailyDistribution.buildAutomatic(30, 5);
      expect(dist, <int>[6, 6, 6, 6, 6]);

      final validation = WeeklyLoadValidator.validate(
        weeklyTarget: 30,
        daysPerWeek: 5,
        dailyPeriods: dist,
      );
      expect(validation.isValid, isTrue);
    });

    test('31 lessons automatic distribution -> [7, 6, 6, 6, 6]', () {
      final dist = DailyDistribution.buildAutomatic(31, 5);
      expect(dist, <int>[7, 6, 6, 6, 6]);

      final validation = WeeklyLoadValidator.validate(
        weeklyTarget: 31,
        daysPerWeek: 5,
        dailyPeriods: dist,
      );
      expect(validation.isValid, isTrue);
    });

    test('31 lessons custom Tuesday -> [6, 6, 7, 6, 6]', () {
      final dist = DailyDistribution.buildWithElevatedDays(
        weeklyTarget: 31,
        daysPerWeek: 5,
        elevatedDays: <int>[Weekday.tuesday.indexPosition],
      );
      expect(dist, <int>[6, 6, 7, 6, 6]);

      final validation = WeeklyLoadValidator.validate(
        weeklyTarget: 31,
        daysPerWeek: 5,
        dailyPeriods: dist,
      );
      expect(validation.isValid, isTrue);
    });

    test('33 lessons automatic and custom distributions', () {
      final autoDist = DailyDistribution.buildAutomatic(33, 5);
      expect(autoDist, <int>[7, 7, 7, 6, 6]);

      final customDist = DailyDistribution.buildWithElevatedDays(
        weeklyTarget: 33,
        daysPerWeek: 5,
        elevatedDays: <int>[
          Weekday.sunday.indexPosition,
          Weekday.tuesday.indexPosition,
          Weekday.thursday.indexPosition,
        ],
      );
      expect(customDist, <int>[7, 6, 7, 6, 7]);

      expect(
        WeeklyLoadValidator.validate(
          weeklyTarget: 33,
          daysPerWeek: 5,
          dailyPeriods: autoDist,
        ).isValid,
        isTrue,
      );
      expect(
        WeeklyLoadValidator.validate(
          weeklyTarget: 33,
          daysPerWeek: 5,
          dailyPeriods: customDist,
        ).isValid,
        isTrue,
      );
    });

    test('invalid daily sum rejection and bounds validation', () {
      // مجموع الحصص (30) لا يساوي 31
      final sumTooLow = WeeklyLoadValidator.validate(
        weeklyTarget: 31,
        daysPerWeek: 5,
        dailyPeriods: const <int>[6, 6, 6, 6, 6],
      );
      expect(sumTooLow.isValid, isFalse);

      // مجموع الحصص (32) لا يساوي 31
      final sumTooHigh = WeeklyLoadValidator.validate(
        weeklyTarget: 31,
        daysPerWeek: 5,
        dailyPeriods: const <int>[7, 7, 6, 6, 6],
      );
      expect(sumTooHigh.isValid, isFalse);

      // عدد الأيام لا يطابق أيام الدوام
      final wrongDaysLength = WeeklyLoadValidator.validate(
        weeklyTarget: 30,
        daysPerWeek: 5,
        dailyPeriods: const <int>[6, 6, 6, 6],
      );
      expect(wrongDaysLength.isValid, isFalse);

      // قيمة سالبة
      final negativePeriod = WeeklyLoadValidator.validate(
        weeklyTarget: 30,
        daysPerWeek: 5,
        dailyPeriods: const <int>[-1, 8, 8, 8, 7],
      );
      expect(negativePeriod.isValid, isFalse);

      // تجاوز الحد الأقصى اليومي
      final exceedsDailyMax = WeeklyLoadValidator.validate(
        weeklyTarget: 30,
        daysPerWeek: 5,
        dailyPeriods: const <int>[13, 5, 4, 4, 4],
        dailyMaximum: 12,
      );
      expect(exceedsDailyMax.isValid, isFalse);
    });
  });
}
