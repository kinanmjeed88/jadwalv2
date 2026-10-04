import '../../../core/models/school_stage.dart';
import '../../../core/models/weekly_load_policy.dart';

/// حدود وقواعد التحقق الخاصة ببيانات الإعداد الأولي.
///
/// منطق خالص (بلا واجهة أو قاعدة بيانات) ليُختبر بسهولة ويُستخدم من معالج
/// الإعداد الأولي ومن صفحة الإعدادات معًا.
class SetupValidation {
  const SetupValidation._();

  static const int minPeriodsPerDay = 1;
  static const int maxPeriodsPerDay = 12;
  static const int minDaysPerWeek = 1;
  static const int maxDaysPerWeek = 7;

  /// نص مطلوب غير فارغ.
  static String? requiredText(String? value, {required String fieldLabel}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel مطلوب';
    }
    return null;
  }

  /// عدد الدروس في اليوم: رقم صحيح داخل الحدود المسموحة.
  static String? periodsPerDay(String? value) {
    return _intInRange(
      value,
      min: minPeriodsPerDay,
      max: maxPeriodsPerDay,
      fieldLabel: 'عدد الدروس في اليوم',
    );
  }

  /// عدد أيام الدوام في الأسبوع: رقم صحيح داخل الحدود المسموحة.
  static String? daysPerWeek(String? value) {
    return _intInRange(
      value,
      min: minDaysPerWeek,
      max: maxDaysPerWeek,
      fieldLabel: 'عدد أيام الأسبوع',
    );
  }

  /// المرحلة الدراسية إلزامية.
  static String? schoolStage(SchoolStage? stage) {
    return stage == null ? 'يرجى اختيار المرحلة الدراسية' : null;
  }

  /// سياسة الحصص الأسبوعية إلزامية.
  static String? weeklyLoadMode(WeeklyLoadMode? mode) {
    return mode == null ? 'يرجى اختيار طريقة تحديد الحصص الأسبوعية' : null;
  }

  static String? _intInRange(
    String? value, {
    required int min,
    required int max,
    required String fieldLabel,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel مطلوب';
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'أدخل رقمًا صحيحًا';
    }

    if (parsed < min || parsed > max) {
      return 'أدخل رقمًا بين $min و $max';
    }

    return null;
  }
}
