import '../../../../core/models/subject_constraint_key.dart';

/// الحمل الأسبوعي لمادة واحدة، مُجمَّعًا من بيانات التطبيق.
///
/// يُبنى من [Subject.lessonsPerWeek] (النصاب المخطَّط) ومن العدد الفعلي
/// للحصص المُسندة لكل شعبة، ثم يؤخذ الأعلى بينهما لأن المستخدم قد يُسند
/// المادة لأكثر من معلم أو يعدّل الإسناد دون تعديل نصاب المادة.
class SubjectWeeklyLoad {
  const SubjectWeeklyLoad({
    required this.subjectName,
    required this.plannedLessonsPerWeek,
    required this.assignedLessonsPerGrade,
  });

  /// اسم المادة كما هو مخزَّن في قاعدة البيانات.
  final String subjectName;

  /// النصاب المخطَّط في [Subject.lessonsPerWeek].
  final int plannedLessonsPerWeek;

  /// المرحلة/الصف → أكبر عدد حصص مُسندة لشعبة واحدة في تلك المرحلة.
  final Map<String, int> assignedLessonsPerGrade;

  /// الحمل الفعلي المعتمد للمرحلة المطلوبة.
  int effectiveWeeklyLessonsFor(String grade) {
    final assigned = assignedLessonsPerGrade[grade] ?? 0;
    return plannedLessonsPerWeek > assigned ? plannedLessonsPerWeek : assigned;
  }
}

/// سياسة "تخطي قيود المواد" للمرحلة الابتدائية.
///
/// الفكرة: الحد الافتراضي لأي مادة في هذه النسخة من المحرك هو حصة واحدة يوميًا،
/// لكن مواد المرحلة الابتدائية (اللغة العربية والرياضيات خاصة) يتجاوز نصابها
/// الأسبوعي ست حصص، فيستحيل جدولتها بالحد الافتراضي (٥ أيام × حصة = ٥ حصص).
/// لذلك تُشتق القيود تلقائيًا من عدد الحصص المُضافة:
/// * **٦ حصص أسبوعيًا هي نقطة البداية**: أي مادة نصابها ٦ أو أكثر تدخل السياسة.
///   لا يُستخدم نصاب المادة نفسه (٧، ٨، ٩، ١٠…) حدًا يوميًا، ولا يُشتق حد يومي
///   أكبر من ٦ بسبب حساب خاطئ لأيام الأسبوع.
/// * يُسمح لها بالتكرار **حصتين في اليوم** كحد أدنى (توزيع ٦ على ٥ أيام:
///   ٢+١+١+١+١، و٧: ٢+٢+١+١+١، و١٠: ٢+٢+٢+٢+٢)، مع رفعه فقط عند الحاجة
///   الرياضية الفعلية (مثال: ١٢ حصة في ٥ أيام تحتاج ٣ حصص في اليوم) حتى لا
///   نُنشئ قيدًا مستحيلًا بذاته.
///
/// القيود الناتجة تُكتب في جدول قيود المواد كأي قيد يدوي، فيمكن للمستخدم
/// تعديلها أو حذفها، ويكفي هذا الصنف لمنطق القرار وحده ليبقى قابلًا للاختبار
/// دون قاعدة بيانات.
class PrimaryStageConstraintPolicy {
  const PrimaryStageConstraintPolicy._();

  /// الحد الفاصل: النصاب الأسبوعي الذي يبلغ هذه القيمة يدخل سياسة التخطي.
  /// ست حصص على خمسة أيام لا يمكن جدولتها بالحد الافتراضي (حصة/يوم).
  static const int weeklyLessonsThreshold = 6;

  /// أقل تكرار مسموح به في اليوم للمواد الداخلة في السياسة (قاعدة الست حصص).
  static const int minimumDailyRepetition = 2;

  /// عدد أيام الأسبوع المعتمد إذا كانت القيمة المخزّنة غير صالحة.
  /// استخدام `1` هنا يجعل `ceil(النصاب ÷ الأيام)` يساوي النصاب نفسه
  /// (٧، ٨، ٩، ١٠…) فيُكتب حد يومي أكبر من ٦ بالخطأ.
  static const int fallbackDaysPerWeek = 5;

  /// هل نصاب المادة الأسبوعي مؤهّل لتخطي قيود المواد؟
  static bool qualifies(int effectiveWeeklyLessons) {
    return effectiveWeeklyLessons >= weeklyLessonsThreshold;
  }

  /// الحد الأقصى اليومي المطلوب لمادة، أو `null` إذا لم تكن مؤهلة.
  static int? resolveMaxPeriodsPerDay({
    required int weeklyLessons,
    required int daysPerWeek,
  }) {
    if (!qualifies(weeklyLessons)) {
      return null;
    }

    final safeDaysPerWeek =
        daysPerWeek < 1 ? fallbackDaysPerWeek : daysPerWeek;
    final requiredPerDay =
        (weeklyLessons + safeDaysPerWeek - 1) ~/ safeDaysPerWeek;

    return requiredPerDay > minimumDailyRepetition
        ? requiredPerDay
        : minimumDailyRepetition;
  }

  /// خطة القيود المطلوبة: مفتاح القيد → الحد الأقصى اليومي.
  ///
  /// تُبنى أسماء المراحل والمواد كما هي مخزَّنة في قاعدة البيانات (دون تعديل)
  /// لأن محرك التوليد يقارن النصوص مقارنة تامة.
  static Map<SubjectConstraintKey, int> planFor({
    required Iterable<String> grades,
    required Iterable<SubjectWeeklyLoad> subjects,
    required int daysPerWeek,
  }) {
    final plan = <SubjectConstraintKey, int>{};

    final consideredGrades = <String>[];
    for (final grade in grades) {
      if (grade.trim().isEmpty || consideredGrades.contains(grade)) {
        continue;
      }
      consideredGrades.add(grade);
    }

    for (final subject in subjects) {
      if (subject.subjectName.trim().isEmpty) {
        continue;
      }

      for (final grade in consideredGrades) {
        final weeklyLessons = subject.effectiveWeeklyLessonsFor(grade);
        final maxPeriodsPerDay = resolveMaxPeriodsPerDay(
          weeklyLessons: weeklyLessons,
          daysPerWeek: daysPerWeek,
        );
        if (maxPeriodsPerDay == null) {
          continue;
        }

        plan[SubjectConstraintKey(
          grade: grade,
          subjectName: subject.subjectName,
        )] = maxPeriodsPerDay;
      }
    }

    return plan;
  }
}
