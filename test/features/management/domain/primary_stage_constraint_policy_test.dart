import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/subject_constraint_key.dart';
import 'package:jadwal_v2/features/management/domain/services/primary_stage_constraint_policy.dart';

void main() {
  group('PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay', () {
    test('لا يؤهل المواد التي نصابها الأسبوعي أقل من ست حصص', () {
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 5,
          daysPerWeek: 5,
        ),
        isNull,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 4,
          daysPerWeek: 5,
        ),
        isNull,
      );
    });

    test('ست حصص هي نقطة البداية وتعطي حصتان في اليوم على خمسة أيام', () {
      expect(PrimaryStageConstraintPolicy.qualifies(6), isTrue);
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 6,
          daysPerWeek: 5,
        ),
        2,
      );
    });

    test('يسمح بحصتين في اليوم للنصاب 6 حتى 10 على خمسة أيام', () {
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 6,
          daysPerWeek: 5,
        ),
        2,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 7,
          daysPerWeek: 5,
        ),
        2,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 8,
          daysPerWeek: 5,
        ),
        2,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 9,
          daysPerWeek: 5,
        ),
        2,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 10,
          daysPerWeek: 5,
        ),
        2,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 12,
          daysPerWeek: 6,
        ),
        2,
      );
    });

    test('أيام الأسبوع غير الصالحة لا تحول النصاب الأسبوعي إلى حد يومي', () {
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 10,
          daysPerWeek: 0,
        ),
        2,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 7,
          daysPerWeek: -1,
        ),
        2,
      );
    });

    test('يرفع الحد اليومي فقط عند الحاجة الرياضية الفعلية', () {
      // ١٢ حصة على ٥ أيام لا تكفيها حصتان في اليوم.
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 12,
          daysPerWeek: 5,
        ),
        3,
      );
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 7,
          daysPerWeek: 3,
        ),
        3,
      );
    });

    test('لا ينزل عن الحد الأدنى للتكرار اليومي مهما كان عدد الأيام', () {
      expect(PrimaryStageConstraintPolicy.minimumDailyRepetition, 2);
      expect(
        PrimaryStageConstraintPolicy.resolveMaxPeriodsPerDay(
          weeklyLessons: 7,
          daysPerWeek: 0,
        ),
        greaterThanOrEqualTo(
          PrimaryStageConstraintPolicy.minimumDailyRepetition,
        ),
      );
    });
  });

  group('PrimaryStageConstraintPolicy.planFor', () {
    test('ينشئ قيدًا للنصاب الستة بحد يومي اثنين', () {
      final plan = PrimaryStageConstraintPolicy.planFor(
        grades: const ['الصف الأول'],
        subjects: [
          SubjectWeeklyLoad(
            subjectName: 'اللغة العربية',
            plannedLessonsPerWeek: 6,
            assignedLessonsPerGrade: const <String, int>{},
          ),
        ],
        daysPerWeek: 5,
      );

      expect(
        plan[const SubjectConstraintKey(
          grade: 'الصف الأول',
          subjectName: 'اللغة العربية',
        )],
        2,
      );
    });

    test('ينشئ قيدًا لكل مرحلة للمواد المتجاوزة الحد', () {
      final plan = PrimaryStageConstraintPolicy.planFor(
        grades: const ['الصف الأول', 'الصف الثاني'],
        subjects: [
          SubjectWeeklyLoad(
            subjectName: 'اللغة العربية',
            plannedLessonsPerWeek: 8,
            assignedLessonsPerGrade: const <String, int>{},
          ),
          SubjectWeeklyLoad(
            subjectName: 'الرياضيات',
            plannedLessonsPerWeek: 7,
            assignedLessonsPerGrade: const {'الصف الأول': 7},
          ),
          SubjectWeeklyLoad(
            subjectName: 'العلوم',
            plannedLessonsPerWeek: 4,
            assignedLessonsPerGrade: const <String, int>{},
          ),
        ],
        daysPerWeek: 5,
      );

      expect(plan.length, 4);
      expect(
        plan[const SubjectConstraintKey(
          grade: 'الصف الأول',
          subjectName: 'اللغة العربية',
        )],
        2,
      );
      expect(
        plan[const SubjectConstraintKey(
          grade: 'الصف الثاني',
          subjectName: 'الرياضيات',
        )],
        2,
      );
      expect(
        plan.containsKey(const SubjectConstraintKey(
          grade: 'الصف الأول',
          subjectName: 'العلوم',
        )),
        isFalse,
      );
    });

    test('يعتمد الأعلى بين النصاب المخطَّط والإسناد الفعلي', () {
      final load = SubjectWeeklyLoad(
        subjectName: 'الرياضيات',
        plannedLessonsPerWeek: 5,
        assignedLessonsPerGrade: const {'الصف الأول': 11},
      );

      final plan = PrimaryStageConstraintPolicy.planFor(
        grades: const ['الصف الأول'],
        subjects: [load],
        daysPerWeek: 5,
      );

      expect(
        plan[const SubjectConstraintKey(
          grade: 'الصف الأول',
          subjectName: 'الرياضيات',
        )],
        3,
      );
    });

    test('يتجاهل المراحل والمواد الفارغة', () {
      final plan = PrimaryStageConstraintPolicy.planFor(
        grades: const ['', '   '],
        subjects: [
          SubjectWeeklyLoad(
            subjectName: 'اللغة العربية',
            plannedLessonsPerWeek: 9,
            assignedLessonsPerGrade: const <String, int>{},
          ),
        ],
        daysPerWeek: 5,
      );

      expect(plan, isEmpty);
    });
  });

  group('SubjectConstraintKey', () {
    test('يُشفَّر ويُقرأ بشكل متطابق', () {
      const key = SubjectConstraintKey(
        grade: 'الصف الأول',
        subjectName: 'اللغة العربية',
      );

      expect(SubjectConstraintKey.tryParse(key.storageKey), key);
    });

    test('يعيد null للقيم التالفة', () {
      expect(SubjectConstraintKey.tryParse(null), isNull);
      expect(SubjectConstraintKey.tryParse('بدون فاصل'), isNull);
      expect(SubjectConstraintKey.tryParse('مرحلة\u001F'), isNull);
    });
  });
}
