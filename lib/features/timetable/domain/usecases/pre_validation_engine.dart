import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/subject_consecutiveness.dart';
import '../../../../core/models/weekly_load_policy.dart';
import '../services/scheduling_rules.dart';

class PreValidationEngine {
  final List<LessonEntity> existingLessons;
  final List<TeacherEntity> teachers;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;
  final List<SubjectEntity> subjects;
  final List<SubjectConstraintEntity> subjectConstraints;

  PreValidationEngine({
    required this.existingLessons,
    required this.teachers,
    required this.classrooms,
    required this.settings,
    this.subjects = const [],
    this.subjectConstraints = const [],
  });

  List<String> validateAll() {
    List<String> errors = [];

    // 1. Classroom Capacity & Daily Distribution Validation
    for (var classroom in classrooms) {
      if (classroom.weeklyTarget != null && classroom.dailyPeriods != null) {
        final validation = WeeklyLoadValidator.validate(
          weeklyTarget: classroom.weeklyTarget!,
          daysPerWeek: settings.daysPerWeek,
          dailyPeriods: classroom.dailyPeriods!,
        );
        if (!validation.isValid) {
          errors.add(
            'خطأ في توزيع الحصص للصف "${classroom.name}": ${validation.errorMessage}',
          );
          continue;
        }
      }

      int maxClassroomCapacity = classroom.resolveWeeklyCapacity(settings);

      int assignedLessons = existingLessons
          .where((l) => l.classroom?.id == classroom.id)
          .length;
      if (assignedLessons > maxClassroomCapacity) {
        errors.add(
          'استحالة رياضية: الصف "${classroom.name}" مُسند إليه $assignedLessons حصة، بينما سعة الجدول الأسبوعي هي $maxClassroomCapacity حصة فقط (أيام الدوام × الحصص اليومية). الحل: تقليل حصص الصف أو زيادة أيام/حصص الدوام.',
        );
      } else if (assignedLessons < maxClassroomCapacity) {
        errors.add(
          'نقص في بيانات الإسناد: الصف "${classroom.name}" مسند إليه $assignedLessons حصة فقط، بينما المطلوب لملء جدوله الأسبوعي هو $maxClassroomCapacity حصة. يرجى إسناد المواد الناقصة لهذا الصف قبل توليد الجدول.',
        );
      }

      // Check subject max constraints
      Map<int, int> subjectLessonCounts = {};
      for (var lesson in existingLessons.where(
        (l) => l.classroom?.id == classroom.id && l.subject != null,
      )) {
        int sId = lesson.subject!.id;
        subjectLessonCounts[sId] = (subjectLessonCounts[sId] ?? 0) + 1;
      }

      for (var entry in subjectLessonCounts.entries) {
        int sId = entry.key;
        int count = entry.value;

        var subject = subjects.firstWhere(
          (s) => s.id == sId,
          orElse: () => subjects.first,
        );

        int maxPerDay = 1; // Default
        for (var constraint in subjectConstraints) {
          if (constraint.grade == classroom.grade &&
              constraint.subjectName == subject.name) {
            maxPerDay = constraint.maxPeriodsPerDay;
            break;
          }
        }

        int maxPerWeek = maxPerDay * settings.daysPerWeek;
        if (count > maxPerWeek) {
          errors.add(
            'استحالة رياضية: الصف "${classroom.name}" مطلوب له $count حصص لمادة "${subject.name}" أسبوعياً، ولكن الحد الأقصى المسموح يومياً هو $maxPerDay حصة، مما يجعل الحد الأقصى الأسبوعي $maxPerWeek حصة فقط (في ${settings.daysPerWeek} أيام).',
          );
          continue;
        }

        final placementError = _validateSubjectPlacementCapacity(
          classroom: classroom,
          subjectId: sId,
          count: count,
          maxPerDay: maxPerDay,
        );
        if (placementError != null) {
          errors.add(placementError);
        }
      }
    }

    // 2. Teacher Capacity Validation
    for (var teacher in teachers) {
      int assignedLessons = existingLessons
          .where((l) => l.teacher?.id == teacher.id)
          .length;

      int activeUnavailableDays = teacher.unavailableDays
          .where((day) => day < settings.daysPerWeek)
          .length;
      int availableDays = settings.daysPerWeek - activeUnavailableDays;

      int maxCapacityDays = teacher.maxLessonsPerDay * availableDays;
      int absoluteMaxCapacity = teacher.maxLessonsPerWeek < maxCapacityDays
          ? teacher.maxLessonsPerWeek
          : maxCapacityDays;

      if (assignedLessons > absoluteMaxCapacity) {
        errors.add(
          'استحالة رياضية: المعلم "${teacher.name}" مطلوب منه $assignedLessons حصة. لكن حده الأقصى أو أيام تفرغه تسمح له بتدريس $absoluteMaxCapacity حصة فقط كحد أقصى. الحل: رفع الحد الأقصى للمعلم، تقليل إجازاته، أو نقل بعض حصصه لمعلم آخر.',
        );
        continue;
      }

      final allowedPeriodsError = _validateTeacherAllowedPeriodsCapacity(
        teacher,
        assignedLessons,
      );
      if (allowedPeriodsError != null) {
        errors.add(allowedPeriodsError);
      }
    }

    return errors;
  }

  static String _dayLabel(int day) {
    if (day >= 0 && day < AppConstants.daysOfWeek.length) {
      return AppConstants.daysOfWeek[day];
    }
    return 'اليوم ${day + 1}';
  }

  static String _policyLabel(SubjectConsecutiveness policy) {
    switch (policy) {
      case SubjectConsecutiveness.consecutive:
        return 'متتالي';
      case SubjectConsecutiveness.nonConsecutive:
        return 'غير متتالي';
      case SubjectConsecutiveness.any:
        return 'بدون قيد';
    }
  }

  /// شروط ضرورية فقط لمجموعة (صف × مادة): إن فشلت فلا يوجد أي جدول صالح.
  ///
  /// تحسب لكل يوم أكبر عدد حصص يمكن وضعه للمادة (الدروس المسموحة للمادة
  /// ولمعلمها، أيام عدم تدريس المعلم، عدد حصص الصف في اليوم، الحد اليومي،
  /// وسياسة التتابع)، ثم تتحقق من التوزيع الأسبوعي المتوازن.
  String? _validateSubjectPlacementCapacity({
    required ClassroomEntity classroom,
    required int subjectId,
    required int count,
    required int maxPerDay,
  }) {
    final groupLessons = existingLessons
        .where(
          (lesson) =>
              lesson.classroom?.id == classroom.id &&
              lesson.subject?.id == subjectId,
        )
        .toList();
    if (groupLessons.isEmpty) return null;
    final subjectEntity = groupLessons.first.subject!;
    final policy = subjectEntity.consecutiveness;
    final dailyPeriods = classroom.resolveDailyPeriods(settings);
    int periodsOnDay(int day) =>
        day >= 0 && day < dailyPeriods.length ? dailyPeriods[day] : 0;

    final profiles = [
      for (final lesson in groupLessons)
        LessonPlacementProfile(
          teacherUnavailableDays:
              lesson.teacher?.unavailableDays ?? const <int>[],
          teacherAllowedPeriods:
              lesson.teacher?.allowedPeriods ?? const <int>[],
          subjectAllowedPeriods:
              lesson.subject?.allowedPeriods ?? const <int>[],
        ),
    ];

    final eligibleDays = SchedulingRules.eligibleDays(
      daysPerWeek: settings.daysPerWeek,
      periodsOnDay: periodsOnDay,
      profiles: profiles,
    );
    final subjectLabel = subjectEntity.name;
    if (eligibleDays.isEmpty) {
      return 'استحالة رياضية: مادة "$subjectLabel" للصف "${classroom.name}" لا يوجد لها أي يوم أو درس يمكن وضعها فيه، لأن أيام عدم تدريس المعلم أو الدروس المسموحة (للمادة أو لمعلمها) لا تتقاطع مع حصص الصف. الحل: توسيع الدروس المسموحة أو تقليل أيام عدم تدريس المعلم.';
    }

    final distribution = SubjectWeeklyDistribution.compute(
      lessonCount: count,
      eligibleDays: eligibleDays,
    );
    final effectiveMax = distribution.effectiveMax(maxPerDay);
    final capacityByDay = <int, int>{
      for (final day in eligibleDays)
        day: SchedulingRules.maxPlaceableOnDay(
          allowedPeriods: SchedulingRules.unionAllowedPeriodsOnDay(
            day: day,
            periodsOnDay: periodsOnDay(day),
            profiles: profiles,
          ),
          policy: policy,
          maxPerDay: effectiveMax,
        ),
    };

    final totalCapacity = capacityByDay.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (totalCapacity < count) {
      return 'استحالة رياضية: مادة "$subjectLabel" للصف "${classroom.name}" مطلوب لها $count حصص أسبوعياً، لكن الأيام المتاحة (${eligibleDays.length}) مع الدروس المسموحة والحد اليومي ($effectiveMax) وقيد التتابع (${_policyLabel(policy)}) تسمح بـ $totalCapacity حصة فقط. الحل: توسيع الدروس المسموحة، رفع الحد اليومي، أو تغيير قيد التتابع.';
    }

    if (distribution.isBalanced) {
      for (final day in eligibleDays) {
        final capacity = capacityByDay[day] ?? 0;
        if (capacity < distribution.minPerDay) {
          return 'استحالة رياضية: توزيع مادة "$subjectLabel" للصف "${classroom.name}" ($count حصص على ${eligibleDays.length} أيام) يتطلب ${distribution.minPerDay} حصة على الأقل في كل يوم، لكن يوم ${_dayLabel(day)} لا يتسع إلا لـ $capacity حصة ضمن الدروس المسموحة وقيد التتابع (${_policyLabel(policy)}). الحل: توسيع الدروس المسموحة في ذلك اليوم أو تغيير قيد التتابع.';
        }
      }
    }
    return null;
  }

  /// شرط ضروري لسعة المعلم بعد احتساب دروسه المسموحة وعدد حصص صفوفه يوميًا.
  String? _validateTeacherAllowedPeriodsCapacity(
    TeacherEntity teacher,
    int assignedLessons,
  ) {
    if (assignedLessons == 0) return null;
    final dailyByClassroom = <int, List<int>>{};
    var hasLessonWithoutClassroom = false;
    for (final lesson in existingLessons) {
      if (lesson.teacher?.id != teacher.id) continue;
      final classroom = lesson.classroom;
      if (classroom == null) {
        hasLessonWithoutClassroom = true;
        continue;
      }
      dailyByClassroom.putIfAbsent(classroom.id, () {
        ClassroomEntity resolved = classroom;
        for (final candidate in classrooms) {
          if (candidate.id == classroom.id) {
            resolved = candidate;
            break;
          }
        }
        return resolved.resolveDailyPeriods(settings);
      });
    }

    var weeklyCapacity = 0;
    for (var day = 0; day < settings.daysPerWeek; day++) {
      if (teacher.unavailableDays.contains(day)) continue;
      var periodsOnDay = hasLessonWithoutClassroom ? settings.periodsPerDay : 0;
      for (final daily in dailyByClassroom.values) {
        final value = day < daily.length ? daily[day] : 0;
        if (value > periodsOnDay) periodsOnDay = value;
      }
      if (periodsOnDay <= 0) continue;
      var allowedCount = 0;
      for (var period = 0; period < periodsOnDay; period++) {
        if (SchedulingRules.isPeriodAllowed(teacher.allowedPeriods, period)) {
          allowedCount++;
        }
      }
      weeklyCapacity += allowedCount < teacher.maxLessonsPerDay
          ? allowedCount
          : teacher.maxLessonsPerDay;
    }
    if (teacher.maxLessonsPerWeek < weeklyCapacity) {
      weeklyCapacity = teacher.maxLessonsPerWeek;
    }

    if (assignedLessons > weeklyCapacity) {
      return 'استحالة رياضية: المعلم "${teacher.name}" مطلوب منه $assignedLessons حصة، لكن دروسه المسموحة في أيام تدريسه (مع حده اليومي وعدد حصص صفوفه) تسمح بـ $weeklyCapacity حصة فقط. الحل: توسيع الدروس المسموحة للمعلم أو نقل بعض حصصه لمعلم آخر.';
    }
    return null;
  }
}
