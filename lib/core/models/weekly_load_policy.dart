import 'dart:math';

import 'package:flutter/foundation.dart';

import 'classroom.dart';
import 'school_stage.dart';

/// أيام الأسبوع المعتمدة في الجدول المدرسي (تبدأ من الأحد = 0).
enum Weekday {
  sunday(indexPosition: 0, arabicLabel: 'الأحد'),
  monday(indexPosition: 1, arabicLabel: 'الإثنين'),
  tuesday(indexPosition: 2, arabicLabel: 'الثلاثاء'),
  wednesday(indexPosition: 3, arabicLabel: 'الأربعاء'),
  thursday(indexPosition: 4, arabicLabel: 'الخميس'),
  friday(indexPosition: 5, arabicLabel: 'الجمعة'),
  saturday(indexPosition: 6, arabicLabel: 'السبت');

  const Weekday({
    required this.indexPosition,
    required this.arabicLabel,
  });

  final int indexPosition;
  final String arabicLabel;

  static Weekday fromDayIndex(int dayIndex) {
    for (final day in Weekday.values) {
      if (day.indexPosition == dayIndex) {
        return day;
      }
    }
    return Weekday.sunday;
  }

  static List<Weekday> workingDays(int daysPerWeek) {
    final count = daysPerWeek.clamp(1, Weekday.values.length);
    return Weekday.values.take(count).toList(growable: false);
  }
}

/// السياسة العامة لتحديد عدد الحصص الأسبوعية للصفوف.
enum WeeklyLoadMode {
  uniform30(
    label: '30 حصة لجميع الصفوف',
    description:
        'اعتماد 30 حصة أسبوعيًا كإعداد عام لجميع الصفوف، مع إمكانية التخصيص الاختياري لكل صف.',
  ),
  officialPlan(
    label: 'الخطة الدراسية الرسمية',
    description:
        'اعتماد عدد الحصص الافتراضي حسب الخطة الدراسية الرسمية للمرحلة والصف، مع قابلية تعديلها.',
  );

  const WeeklyLoadMode({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  String get storageName => name;

  /// السلوك الافتراضي المتوافق مع البيانات السابقة.
  static const WeeklyLoadMode fallback = WeeklyLoadMode.uniform30;

  static WeeklyLoadMode fromStorage(Object? value) {
    for (final mode in WeeklyLoadMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return fallback;
  }
}

/// المسارات/المراحل المعتمدة في الخطة الدراسية الرسمية.
enum OfficialPlanTrack {
  primary(
    label: 'ابتدائي',
    grades: <AcademicGrade>[
      AcademicGrade.first,
      AcademicGrade.second,
      AcademicGrade.third,
      AcademicGrade.fourth,
      AcademicGrade.fifth,
      AcademicGrade.sixth,
    ],
  ),
  middle(
    label: 'متوسط',
    grades: <AcademicGrade>[
      AcademicGrade.first,
      AcademicGrade.second,
      AcademicGrade.third,
    ],
  ),
  preparatoryScientific(
    label: 'إعدادي علمي',
    grades: <AcademicGrade>[
      AcademicGrade.fourth,
      AcademicGrade.fifth,
      AcademicGrade.sixth,
    ],
  ),
  preparatoryLiterary(
    label: 'إعدادي أدبي',
    grades: <AcademicGrade>[
      AcademicGrade.fourth,
      AcademicGrade.fifth,
      AcademicGrade.sixth,
    ],
  );

  const OfficialPlanTrack({
    required this.label,
    required this.grades,
  });

  final String label;
  final List<AcademicGrade> grades;

  String get storageKey => name;

  static OfficialPlanTrack? fromStorage(Object? value) {
    for (final track in OfficialPlanTrack.values) {
      if (track.name == value) {
        return track;
      }
    }
    return null;
  }

  /// يستنتج المسار الدراسي من بيانات الصف والمرحلة المختارة في إعدادات التطبيق.
  static OfficialPlanTrack resolve({
    required String gradeText,
    String nameText = '',
    required SchoolStage schoolStage,
    required AcademicGrade academicGrade,
  }) {
    final normalized = _normalizeArabic('$gradeText $nameText');

    if (normalized.contains('ادبي')) {
      return OfficialPlanTrack.preparatoryLiterary;
    }
    if (normalized.contains('علمي')) {
      return OfficialPlanTrack.preparatoryScientific;
    }
    if (normalized.contains('ابتداي') || normalized.contains('ابتدائي')) {
      return OfficialPlanTrack.primary;
    }
    if (normalized.contains('متوسط')) {
      if (OfficialPlanTrack.middle.grades.contains(academicGrade)) {
        return OfficialPlanTrack.middle;
      }
    }
    if (normalized.contains('اعدادي')) {
      return OfficialPlanTrack.preparatoryScientific;
    }

    if (schoolStage == SchoolStage.primary) {
      return OfficialPlanTrack.primary;
    }

    // في مرحلة «متوسط فأعلى»: الصفوف ١-٣ متوسطة، والصفوف ٤-٦ إعدادية.
    if (OfficialPlanTrack.middle.grades.contains(academicGrade)) {
      return OfficialPlanTrack.middle;
    }
    return OfficialPlanTrack.preparatoryScientific;
  }
}

/// الصفوف الدراسية من الأول إلى السادس.
enum AcademicGrade {
  first(label: 'الأول', order: 1),
  second(label: 'الثاني', order: 2),
  third(label: 'الثالث', order: 3),
  fourth(label: 'الرابع', order: 4),
  fifth(label: 'الخامس', order: 5),
  sixth(label: 'السادس', order: 6);

  const AcademicGrade({
    required this.label,
    required this.order,
  });

  final String label;
  final int order;

  String get storageKey => name;

  static AcademicGrade? fromStorage(Object? value) {
    for (final grade in AcademicGrade.values) {
      if (grade.name == value) {
        return grade;
      }
    }
    return null;
  }

  /// يستخرج الصف الدراسي من اسم المرحلة أو اسم الشعبة (مثل «الصف السادس»، «السادس أ»، «6»).
  static AcademicGrade? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final normalized = _normalizeArabic(raw);

    if (normalized.contains('سادس') ||
        RegExp(r'(^|\s|/)6(\s|/|$)').hasMatch(normalized) ||
        normalized.contains('٦')) {
      return AcademicGrade.sixth;
    }
    if (normalized.contains('خامس') ||
        RegExp(r'(^|\s|/)5(\s|/|$)').hasMatch(normalized) ||
        normalized.contains('٥')) {
      return AcademicGrade.fifth;
    }
    if (normalized.contains('رابع') ||
        RegExp(r'(^|\s|/)4(\s|/|$)').hasMatch(normalized) ||
        normalized.contains('٤')) {
      return AcademicGrade.fourth;
    }
    if (normalized.contains('ثالث') ||
        RegExp(r'(^|\s|/)3(\s|/|$)').hasMatch(normalized) ||
        normalized.contains('٣')) {
      return AcademicGrade.third;
    }
    if (normalized.contains('ثاني') ||
        RegExp(r'(^|\s|/)2(\s|/|$)').hasMatch(normalized) ||
        normalized.contains('٢')) {
      return AcademicGrade.second;
    }
    if (normalized.contains('اول') ||
        RegExp(r'(^|\s|/)1(\s|/|$)').hasMatch(normalized) ||
        normalized.contains('١')) {
      return AcademicGrade.first;
    }

    return null;
  }
}

String _normalizeArabic(String input) {
  return input
      .trim()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
}

/// الخطة الدراسية الرسمية القابلة للتعديل بوصفها بيانات افتراضية (Seed Configuration).
///
/// غير مرتبطة بسنة دراسية محددة، ويمكن للمستخدم تعديل أي قيمة فيها من الإعدادات.
class OfficialWeeklyPlan {
  OfficialWeeklyPlan({
    required Map<OfficialPlanTrack, Map<AcademicGrade, int>> table,
  }) : _table = _normalizeTable(table);

  /// القيم الافتراضية المعتمدة للخطة الدراسية الرسمية.
  const OfficialWeeklyPlan.standard() : _table = _defaultTable;

  static const int uniformDefaultLessons = 30;

  static const Map<OfficialPlanTrack, Map<AcademicGrade, int>> _defaultTable =
      <OfficialPlanTrack, Map<AcademicGrade, int>>{
    OfficialPlanTrack.primary: <AcademicGrade, int>{
      AcademicGrade.first: 30,
      AcademicGrade.second: 30,
      AcademicGrade.third: 30,
      AcademicGrade.fourth: 30,
      AcademicGrade.fifth: 30,
      AcademicGrade.sixth: 31,
    },
    OfficialPlanTrack.middle: <AcademicGrade, int>{
      AcademicGrade.first: 30,
      AcademicGrade.second: 30,
      AcademicGrade.third: 30,
    },
    OfficialPlanTrack.preparatoryScientific: <AcademicGrade, int>{
      AcademicGrade.fourth: 30,
      AcademicGrade.fifth: 30,
      AcademicGrade.sixth: 33,
    },
    OfficialPlanTrack.preparatoryLiterary: <AcademicGrade, int>{
      AcademicGrade.fourth: 30,
      AcademicGrade.fifth: 31,
      AcademicGrade.sixth: 31,
    },
  };

  final Map<OfficialPlanTrack, Map<AcademicGrade, int>> _table;

  static Map<OfficialPlanTrack, Map<AcademicGrade, int>> _normalizeTable(
    Map<OfficialPlanTrack, Map<AcademicGrade, int>> source,
  ) {
    final normalized = <OfficialPlanTrack, Map<AcademicGrade, int>>{};
    for (final track in OfficialPlanTrack.values) {
      final defaults = _defaultTable[track]!;
      final incoming = source[track];
      final trackMap = <AcademicGrade, int>{};
      for (final grade in track.grades) {
        final candidate = incoming?[grade];
        trackMap[grade] = (candidate != null && candidate > 0)
            ? candidate
            : defaults[grade]!;
      }
      normalized[track] = Map<AcademicGrade, int>.unmodifiable(trackMap);
    }
    return Map<OfficialPlanTrack, Map<AcademicGrade, int>>.unmodifiable(
      normalized,
    );
  }

  /// يعيد عدد الحصص الأسبوعية لمسار وصف محددين.
  int lessonsFor(OfficialPlanTrack track, AcademicGrade grade) {
    return _table[track]?[grade] ??
        _defaultTable[track]?[grade] ??
        uniformDefaultLessons;
  }

  /// يعيد خريطة القيم الخاصة بمسار معيّن.
  Map<AcademicGrade, int> gradesForTrack(OfficialPlanTrack track) {
    return _table[track] ?? const <AcademicGrade, int>{};
  }

  /// ينشئ نسخة جديدة بعد تعديل نصاب صف في مسار محدد.
  OfficialWeeklyPlan copyWithEntry({
    required OfficialPlanTrack track,
    required AcademicGrade grade,
    required int weeklyLessons,
  }) {
    if (!track.grades.contains(grade) || weeklyLessons < 1) {
      return this;
    }

    final next = <OfficialPlanTrack, Map<AcademicGrade, int>>{};
    for (final currentTrack in OfficialPlanTrack.values) {
      final currentMap = Map<AcademicGrade, int>.from(_table[currentTrack]!);
      if (currentTrack == track) {
        currentMap[grade] = weeklyLessons;
      }
      next[currentTrack] = currentMap;
    }
    return OfficialWeeklyPlan(table: next);
  }

  /// يحسب العدد الافتراضي للحصص الأسبوعية لصف بناءً على مرحلته واسمه.
  int resolveForClassroom({
    required String grade,
    String name = '',
    required SchoolStage schoolStage,
  }) {
    final academicGrade =
        AcademicGrade.tryParse(grade) ?? AcademicGrade.tryParse(name);
    if (academicGrade == null) {
      return uniformDefaultLessons;
    }

    final track = OfficialPlanTrack.resolve(
      gradeText: grade,
      nameText: name,
      schoolStage: schoolStage,
      academicGrade: academicGrade,
    );
    return lessonsFor(track, academicGrade);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    for (final track in OfficialPlanTrack.values) {
      final gradesJson = <String, int>{};
      for (final grade in track.grades) {
        gradesJson[grade.storageKey] = lessonsFor(track, grade);
      }
      json[track.storageKey] = gradesJson;
    }
    return json;
  }

  factory OfficialWeeklyPlan.fromJson(Object? raw) {
    if (raw is! Map) {
      return OfficialWeeklyPlan.standard();
    }

    final table = <OfficialPlanTrack, Map<AcademicGrade, int>>{};
    raw.forEach((trackKey, trackValue) {
      final track = OfficialPlanTrack.fromStorage(trackKey);
      if (track == null || trackValue is! Map) {
        return;
      }
      final gradeMap = <AcademicGrade, int>{};
      trackValue.forEach((gradeKey, lessonsValue) {
        final grade = AcademicGrade.fromStorage(gradeKey);
        if (grade != null && lessonsValue is num && lessonsValue.toInt() > 0) {
          gradeMap[grade] = lessonsValue.toInt();
        }
      });
      table[track] = gradeMap;
    });

    return OfficialWeeklyPlan(table: table);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! OfficialWeeklyPlan) {
      return false;
    }
    for (final track in OfficialPlanTrack.values) {
      if (!mapEquals(_table[track], other._table[track])) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        OfficialPlanTrack.values.map(
          (track) => Object.hashAll(
            track.grades.map((grade) => Object.hash(track, grade, _table[track]![grade])),
          ),
        ),
      );
}

/// تخصيص اختياري لعدد الحصص الأسبوعية وتوزيعها اليومي على مستوى صف واحد.
class ClassroomWeeklyOverride {
  const ClassroomWeeklyOverride({
    required this.weeklyLessons,
    this.dailyPeriods,
  });

  /// يبني تخصيصًا مع تحديد الأيام التي تأخذ حصة إضافية فوق المعدل اليومي الأساسي.
  factory ClassroomWeeklyOverride.withExtraDays({
    required int weeklyLessons,
    required int daysPerWeek,
    required Iterable<int> extraDays,
  }) {
    final distribution = DailyDistribution.buildWithElevatedDays(
      weeklyTarget: weeklyLessons,
      daysPerWeek: daysPerWeek,
      elevatedDays: extraDays.toSet(),
    );
    return ClassroomWeeklyOverride(
      weeklyLessons: weeklyLessons,
      dailyPeriods: distribution,
    );
  }

  final int weeklyLessons;
  final List<int>? dailyPeriods;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ClassroomWeeklyOverride &&
        other.weeklyLessons == weeklyLessons &&
        listEquals(other.dailyPeriods, dailyPeriods);
  }

  @override
  int get hashCode => Object.hash(
        weeklyLessons,
        dailyPeriods == null ? null : Object.hashAll(dailyPeriods!),
      );
}

/// بناء وتحليل التوزيع اليومي للسعة الأسبوعية بشكل عام دون حالات خاصة.
class DailyDistribution {
  const DailyDistribution._();

  /// يوزع [weeklyTarget] على [daysPerWeek] تلقائيًا بأعلى توازن ممكن.
  ///
  /// أمثلة على 5 أيام:
  /// * 30 -> [6, 6, 6, 6, 6]
  /// * 31 -> [7, 6, 6, 6, 6]
  /// * 33 -> [7, 7, 7, 6, 6]
  static List<int> buildAutomatic(int weeklyTarget, int daysPerWeek) {
    final safeDays = daysPerWeek < 1 ? 5 : daysPerWeek;
    final safeTarget = weeklyTarget < 0 ? 0 : weeklyTarget;
    final baseline = safeTarget ~/ safeDays;
    final remainder = safeTarget % safeDays;

    return List<int>.generate(
      safeDays,
      (dayIndex) => dayIndex < remainder ? baseline + 1 : baseline,
      growable: false,
    );
  }

  /// يوزع [weeklyTarget] على [daysPerWeek] مع منح الحصص الإضافية للأيام المحددة في [elevatedDays].
  ///
  /// ملاحظة معمارية: هذه الدالة تحوّل اختيار الأيام في الواجهة إلى خريطة/قائمة
  /// حصص يومية صريحة لكل يوم (مثل `[6, 6, 7, 6, 6]`)، بحيث يعتمد الـDomain
  /// على عدد الحصص الفعلي لكل يوم وليس على مفهوم "حصة إضافية".
  static List<int> buildWithElevatedDays({
    required int weeklyTarget,
    required int daysPerWeek,
    required Set<int> elevatedDays,
  }) {
    final safeDays = daysPerWeek < 1 ? 5 : daysPerWeek;
    final safeTarget = weeklyTarget < 0 ? 0 : weeklyTarget;
    final baseline = safeTarget ~/ safeDays;

    return List<int>.generate(
      safeDays,
      (dayIndex) =>
          elevatedDays.contains(dayIndex) ? baseline + 1 : baseline,
      growable: false,
    );
  }

  /// يستنتج مؤشرات الأيام التي تزيد عن الحد اليومي الأساسي (إن وجدت).
  static Set<int> extractElevatedDays(List<int> dailyPeriods) {
    if (dailyPeriods.isEmpty) {
      return const <int>{};
    }
    final baseline = dailyPeriods.reduce(min);
    final result = <int>{};
    for (var i = 0; i < dailyPeriods.length; i++) {
      if (dailyPeriods[i] > baseline) {
        result.add(i);
      }
    }
    return result;
  }

  /// يحول خريطة `Map<Weekday, int>` إلى قائمة مرتبة حسب أيام الدوام.
  static List<int> fromWeekdayMap(
    Map<Weekday, int> map, {
    required int daysPerWeek,
  }) {
    final safeDays = daysPerWeek < 1 ? 5 : daysPerWeek;
    return List<int>.generate(
      safeDays,
      (index) => map[Weekday.fromDayIndex(index)] ?? 0,
      growable: false,
    );
  }

  /// يحول قائمة الحصص اليومية إلى `Map<Weekday, int>`.
  static Map<Weekday, int> toWeekdayMap(List<int> dailyPeriods) {
    return <Weekday, int>{
      for (var i = 0; i < dailyPeriods.length && i < Weekday.values.length; i++)
        Weekday.fromDayIndex(i): dailyPeriods[i],
    };
  }
}

/// الإعداد الفعلي المحسوب للصف (Effective Weekly Configuration).
///
/// يفصل صراحةً بين ثلاثة مفاهيم:
/// * [weeklyTarget]: عدد الحصص الأسبوعية المطلوب للصف.
/// * [dailyBaseline]: عدد الحصص المعتاد يوميًا (الحد الأساسي).
/// * [dailyMaximum]: الحد الأقصى المسموح به للحصص في اليوم الواحد.
class EffectiveWeeklyConfig {
  EffectiveWeeklyConfig({
    required this.weeklyTarget,
    required this.dailyBaseline,
    required this.dailyMaximum,
    required this.daysPerWeek,
    required List<int> dailyPeriods,
    required this.isOverridden,
  }) : dailyPeriods = List<int>.unmodifiable(dailyPeriods);

  /// عدد الحصص الأسبوعية الفعلي للصف (Weekly Target).
  final int weeklyTarget;

  /// عدد الحصص المعتاد يوميًا (Daily Baseline).
  final int dailyBaseline;

  /// الحد الأقصى للحصص في اليوم الواحد (Daily Maximum).
  final int dailyMaximum;

  /// عدد أيام الدوام الفعلية في الأسبوع.
  final int daysPerWeek;

  /// عدد الحصص لكل يوم دوام (من اليوم 0 إلى `daysPerWeek - 1`).
  final List<int> dailyPeriods;

  /// هل جاءت هذه الإعدادات من تخصيص خاص بالصف (`true`) أم من الإعداد العام (`false`)؟
  final bool isOverridden;

  /// تمثيل التوزيع اليومي كخريطة `Map<Weekday, int>`.
  Map<Weekday, int> get weekdayPeriods =>
      DailyDistribution.toWeekdayMap(dailyPeriods);

  /// تمثيل التوزيع اليومي كخريطة `Map<int, int>` (رقم اليوم -> عدد الحصص).
  Map<int, int> get dailyPeriodsByDay => <int, int>{
        for (var i = 0; i < dailyPeriods.length; i++) i: dailyPeriods[i],
      };

  /// أعلى عدد حصص في يوم واحد ضمن هذا التوزيع.
  int get maxDailyPeriods =>
      dailyPeriods.isEmpty ? 0 : dailyPeriods.reduce(max);

  /// مجموع الحصص اليومية.
  int get totalDailyPeriods =>
      dailyPeriods.fold<int>(0, (sum, item) => sum + item);

  /// عدد الحصص المسموح بها في اليوم ذي الفهرس [dayIndex].
  int periodsForDay(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= dailyPeriods.length) {
      return 0;
    }
    return dailyPeriods[dayIndex];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is EffectiveWeeklyConfig &&
        other.weeklyTarget == weeklyTarget &&
        other.dailyBaseline == dailyBaseline &&
        other.dailyMaximum == dailyMaximum &&
        other.daysPerWeek == daysPerWeek &&
        other.isOverridden == isOverridden &&
        listEquals(other.dailyPeriods, dailyPeriods);
  }

  @override
  int get hashCode => Object.hash(
        weeklyTarget,
        dailyBaseline,
        dailyMaximum,
        daysPerWeek,
        isOverridden,
        Object.hashAll(dailyPeriods),
      );
}

/// نتيجة التحقق من صحة إعداد الحصص الأسبوعية وتوزيعها اليومي.
class WeeklyLoadValidationResult {
  const WeeklyLoadValidationResult._({
    required this.isValid,
    this.errorMessage,
  });

  const WeeklyLoadValidationResult.valid() : this._(isValid: true);

  const WeeklyLoadValidationResult.invalid(String message)
      : this._(isValid: false, errorMessage: message);

  final bool isValid;
  final String? errorMessage;
}

/// التحقق على مستوى الـDomain من صحة عدد الحصص الأسبوعية وتوزيعها اليومي.
class WeeklyLoadValidator {
  const WeeklyLoadValidator._();

  static const int minDaysPerWeek = 1;
  static const int maxDaysPerWeek = 7;
  static const int defaultDailyMaximum = 12;

  /// يتحقق من توافق [weeklyTarget] مع [dailyPeriods] وأيام الدوام والحد اليومي الأقصى.
  static WeeklyLoadValidationResult validate({
    required int weeklyTarget,
    required int daysPerWeek,
    required List<int> dailyPeriods,
    int dailyMaximum = defaultDailyMaximum,
  }) {
    if (daysPerWeek < minDaysPerWeek || daysPerWeek > maxDaysPerWeek) {
      return WeeklyLoadValidationResult.invalid(
        'عدد أيام الدوام ($daysPerWeek) غير صالح. يجب أن يكون بين $minDaysPerWeek و $maxDaysPerWeek.',
      );
    }

    if (weeklyTarget < 1) {
      return const WeeklyLoadValidationResult.invalid(
        'عدد الحصص الأسبوعية يجب أن يكون أكبر من صفر.',
      );
    }

    if (dailyMaximum < 1) {
      return const WeeklyLoadValidationResult.invalid(
        'الحد الأقصى للحصص اليومية يجب أن يكون أكبر من صفر.',
      );
    }

    if (dailyPeriods.length != daysPerWeek) {
      return WeeklyLoadValidationResult.invalid(
        'عدد أيام التوزيع اليومي (${dailyPeriods.length}) لا يطابق عدد أيام الدوام الفعلية ($daysPerWeek).',
      );
    }

    var sum = 0;
    for (var day = 0; day < dailyPeriods.length; day++) {
      final count = dailyPeriods[day];
      final dayLabel = Weekday.fromDayIndex(day).arabicLabel;
      if (count < 0) {
        return WeeklyLoadValidationResult.invalid(
          'عدد الحصص في يوم $dayLabel لا يمكن أن يكون سالبًا ($count).',
        );
      }
      if (count > dailyMaximum) {
        return WeeklyLoadValidationResult.invalid(
          'عدد الحصص في يوم $dayLabel ($count) يتجاوز الحد الأقصى المسموح في اليوم ($dailyMaximum حصة).',
        );
      }
      sum += count;
    }

    if (sum != weeklyTarget) {
      return WeeklyLoadValidationResult.invalid(
        'مجموع التوزيع اليومي ($sum حصة) لا يطابق عدد الحصص الأسبوعية المطلوب ($weeklyTarget حصة).',
      );
    }

    return const WeeklyLoadValidationResult.valid();
  }

  /// يتحقق من خريطة `Map<Weekday, int>` مقابل أيام الدوام الفعلية.
  static WeeklyLoadValidationResult validateWeekdayMap({
    required int weeklyTarget,
    required int daysPerWeek,
    required Map<Weekday, int> weekdayPeriods,
    int dailyMaximum = defaultDailyMaximum,
  }) {
    if (daysPerWeek < minDaysPerWeek || daysPerWeek > maxDaysPerWeek) {
      return WeeklyLoadValidationResult.invalid(
        'عدد أيام الدوام ($daysPerWeek) غير صالح.',
      );
    }

    final allowedWeekdays = Weekday.workingDays(daysPerWeek).toSet();
    for (final entry in weekdayPeriods.entries) {
      if (!allowedWeekdays.contains(entry.key)) {
        return WeeklyLoadValidationResult.invalid(
          'اليوم ${entry.key.arabicLabel} ليس من أيام الدوام الفعلية.',
        );
      }
    }

    for (final requiredDay in allowedWeekdays) {
      if (!weekdayPeriods.containsKey(requiredDay)) {
        return WeeklyLoadValidationResult.invalid(
          'يرجى تحديد عدد الحصص ليوم الدوام ${requiredDay.arabicLabel}.',
        );
      }
    }

    final list = DailyDistribution.fromWeekdayMap(
      weekdayPeriods,
      daysPerWeek: daysPerWeek,
    );
    return validate(
      weeklyTarget: weeklyTarget,
      daysPerWeek: daysPerWeek,
      dailyPeriods: list,
      dailyMaximum: dailyMaximum,
    );
  }
}

/// خدمة حساب الإعداد الأسبوعي الفعلي للصف (Effective Weekly Configuration).
///
/// تتبع التسلسل المعماري:
/// Global Weekly Load Policy -> Official Defaults -> Classroom Optional Override -> Effective Configuration
class WeeklyLoadResolver {
  const WeeklyLoadResolver._();

  /// يحسب القيمة الافتراضية من السياسة العامة دون النظر إلى تخصيص الصف.
  static int resolveDefaultWeeklyTarget({
    required WeeklyLoadMode mode,
    required OfficialWeeklyPlan officialPlan,
    required SchoolStage schoolStage,
    required String grade,
    String classroomName = '',
  }) {
    switch (mode) {
      case WeeklyLoadMode.uniform30:
        return OfficialWeeklyPlan.uniformDefaultLessons;
      case WeeklyLoadMode.officialPlan:
        return officialPlan.resolveForClassroom(
          grade: grade,
          name: classroomName,
          schoolStage: schoolStage,
        );
    }
  }

  /// يحسب الإعداد الفعلي الكامل للصف مع أخذ التخصيص الاختياري بالاعتبار.
  static EffectiveWeeklyConfig resolveForClassroom({
    required Classroom classroom,
    required WeeklyLoadMode mode,
    required OfficialWeeklyPlan officialPlan,
    required SchoolStage schoolStage,
    required int daysPerWeek,
    int dailyMaximum = WeeklyLoadValidator.defaultDailyMaximum,
  }) {
    final safeDays = daysPerWeek < 1 ? 5 : daysPerWeek;
    final overrideWeekly = classroom.weeklyLessonsOverride;

    final int weeklyTarget;
    final List<int> dailyPeriods;
    final bool isOverridden;

    if (overrideWeekly != null && overrideWeekly > 0) {
      isOverridden = true;
      weeklyTarget = overrideWeekly;
      final overrideDaily = classroom.dailyPeriodsOverride;
      if (overrideDaily != null &&
          overrideDaily.length == safeDays &&
          overrideDaily.fold<int>(0, (a, b) => a + b) == weeklyTarget &&
          overrideDaily.every((c) => c >= 0 && c <= dailyMaximum)) {
        dailyPeriods = List<int>.from(overrideDaily);
      } else {
        dailyPeriods = DailyDistribution.buildAutomatic(weeklyTarget, safeDays);
      }
    } else {
      isOverridden = false;
      weeklyTarget = resolveDefaultWeeklyTarget(
        mode: mode,
        officialPlan: officialPlan,
        schoolStage: schoolStage,
        grade: classroom.grade,
        classroomName: classroom.name,
      );
      dailyPeriods = DailyDistribution.buildAutomatic(weeklyTarget, safeDays);
    }

    final dailyBaseline = weeklyTarget ~/ safeDays;
    final resolvedMax = max(
      dailyMaximum,
      dailyPeriods.isEmpty ? 0 : dailyPeriods.reduce(max),
    );

    return EffectiveWeeklyConfig(
      weeklyTarget: weeklyTarget,
      dailyBaseline: dailyBaseline,
      dailyMaximum: resolvedMax,
      daysPerWeek: safeDays,
      dailyPeriods: dailyPeriods,
      isOverridden: isOverridden,
    );
  }
}
