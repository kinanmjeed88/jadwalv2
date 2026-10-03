import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';

void main() {
  group('SchoolStage', () {
    test('المرحلة الافتراضية لا تُفعّل سياسة التخطي', () {
      expect(SchoolStage.fallback, SchoolStage.middleAndAbove);
      expect(SchoolStage.fallback.enablesAutomaticConstraintBypass, isFalse);
      expect(SchoolStage.primary.enablesAutomaticConstraintBypass, isTrue);
    });

    test('يقرأ القيم المعروفة ويرجع للافتراضي مع القيم المجهولة', () {
      expect(SchoolStage.fromStorage('primary'), SchoolStage.primary);
      expect(
        SchoolStage.fromStorage('middleAndAbove'),
        SchoolStage.middleAndAbove,
      );
      expect(SchoolStage.fromStorage('unknown'), SchoolStage.fallback);
      expect(SchoolStage.fromStorage(null), SchoolStage.fallback);
    });
  });

  group('AppConfig', () {
    test('يُقرأ ويُكتب بصيغة JSON دون فقدان البيانات', () {
      final config = AppConfig(
        isSetupCompleted: true,
        schoolStage: SchoolStage.primary,
        managedAutoConstraints: const {'الصف الأول\u001Fاللغة العربية': 2},
        dismissedAutoConstraints: const {'الصف الثاني\u001Fالرياضيات'},
      );

      final encoded = jsonEncode(config.toJson());
      final decoded =
          AppConfig.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded, config);
    });

    test('يعود للقيم الآمنة عند وجود حقول تالفة', () {
      final decoded = AppConfig.fromJson(<String, dynamic>{
        'isSetupCompleted': 'yes',
        'schoolStage': 42,
        'managedAutoConstraints': 5,
        'dismissedAutoConstraints': 'nope',
      });

      expect(decoded.isSetupCompleted, isFalse);
      expect(decoded.schoolStage, SchoolStage.fallback);
      expect(decoded.managedAutoConstraints, isEmpty);
      expect(decoded.dismissedAutoConstraints, isEmpty);
    });

    test('يتجاهل القيم غير الرقمية في سجلّ القيود المُدارة', () {
      final decoded = AppConfig.fromJson(<String, dynamic>{
        'managedAutoConstraints': <String, dynamic>{
          'مفتاح صحيح': 3,
          'مفتاح نصي': '2',
        },
      });

      expect(decoded.managedAutoConstraints, {'مفتاح صحيح': 3});
    });

    test('copyWith يحفظ القيم غير المذكورة', () {
      final config = AppConfig.initial().copyWith(
        schoolStage: SchoolStage.primary,
        managedAutoConstraints: const {'a': 2},
      );

      final updated = config.copyWith(isSetupCompleted: true);

      expect(updated.isSetupCompleted, isTrue);
      expect(updated.schoolStage, SchoolStage.primary);
      expect(updated.managedAutoConstraints, config.managedAutoConstraints);
    });

    test('AppConfig.initial لا يعتبر الإعداد مكتملًا', () {
      expect(AppConfig.initial().isSetupCompleted, isFalse);
      expect(AppConfig.initial(), AppConfig.initial());
    });
  });
}
