import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/features/setup/domain/setup_validation.dart';

void main() {
  group('SetupValidation.requiredText', () {
    test('يرفض النص الفارغ أو المسافات فقط', () {
      expect(SetupValidation.requiredText(null, fieldLabel: 'اسم المدرسة'),
          'اسم المدرسة مطلوب');
      expect(SetupValidation.requiredText('', fieldLabel: 'اسم المدرسة'),
          'اسم المدرسة مطلوب');
      expect(SetupValidation.requiredText('   ', fieldLabel: 'اسم المدرسة'),
          'اسم المدرسة مطلوب');
    });

    test('يقبل النص غير الفارغ', () {
      expect(
        SetupValidation.requiredText('مدرسة النور', fieldLabel: 'اسم المدرسة'),
        isNull,
      );
    });
  });

  group('SetupValidation.periodsPerDay', () {
    test('يقبل القيم داخل الحدود', () {
      expect(SetupValidation.periodsPerDay('7'), isNull);
      expect(SetupValidation.periodsPerDay(' 12 '), isNull);
      expect(SetupValidation.periodsPerDay('1'), isNull);
    });

    test('يرفض القيم خارج الحدود أو غير الرقمية', () {
      expect(SetupValidation.periodsPerDay('0'), 'أدخل رقمًا بين 1 و 12');
      expect(SetupValidation.periodsPerDay('13'), 'أدخل رقمًا بين 1 و 12');
      expect(SetupValidation.periodsPerDay('abc'), 'أدخل رقمًا صحيحًا');
      expect(
        SetupValidation.periodsPerDay(''),
        'عدد الدروس في اليوم مطلوب',
      );
    });
  });

  group('SetupValidation.daysPerWeek', () {
    test('يقبل القيم داخل الحدود', () {
      expect(SetupValidation.daysPerWeek('5'), isNull);
      expect(SetupValidation.daysPerWeek('6'), isNull);
      expect(SetupValidation.daysPerWeek('7'), isNull);
    });

    test('يرفض القيم خارج الحدود أو غير الرقمية', () {
      expect(SetupValidation.daysPerWeek('0'), 'أدخل رقمًا بين 1 و 7');
      expect(SetupValidation.daysPerWeek('8'), 'أدخل رقمًا بين 1 و 7');
      expect(SetupValidation.daysPerWeek('خمسة'), 'أدخل رقمًا صحيحًا');
    });
  });

  group('SetupValidation.schoolStage', () {
    test('يرفض عدم الاختيار ويقبل المرحلتين', () {
      expect(
        SetupValidation.schoolStage(null),
        'يرجى اختيار المرحلة الدراسية',
      );
      expect(SetupValidation.schoolStage(SchoolStage.primary), isNull);
      expect(SetupValidation.schoolStage(SchoolStage.middleAndAbove), isNull);
    });
  });

  group('SetupValidation.weeklyLoadMode', () {
    test('يرفض عدم الاختيار ويقبل السياسة المحددة', () {
      expect(
        SetupValidation.weeklyLoadMode(null),
        'يرجى اختيار طريقة تحديد الحصص الأسبوعية',
      );
      expect(SetupValidation.weeklyLoadMode(WeeklyLoadMode.uniform30), isNull);
      expect(
        SetupValidation.weeklyLoadMode(WeeklyLoadMode.officialPlan),
        isNull,
      );
    });
  });
}
