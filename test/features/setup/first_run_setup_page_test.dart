import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/core/providers/app_config_provider.dart';
import 'package:jadwal_v2/core/providers/database_provider.dart';
import 'package:jadwal_v2/core/services/app_config_service.dart';
import 'package:jadwal_v2/features/setup/presentation/pages/first_run_setup_page.dart';

void main() {
  late Isar isar;
  late Directory tempDirectory;
  late AppConfigService appConfigService;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory =
        await Directory.systemTemp.createTemp('jadwal_first_run_setup_test');
    isar = await Isar.open(
      [
        TeacherSchema,
        SubjectSchema,
        ClassroomSchema,
        LessonSchema,
        AppSettingsSchema,
        SubjectConstraintSchema,
      ],
      directory: tempDirectory.path,
      name: 'first_run_setup_test',
    );
    appConfigService = AppConfigService(
      file: File(
        '${tempDirectory.path}${Platform.pathSeparator}${AppConfigService.fileName}',
      ),
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets(
      'FirstRunSetupPage displays weekly load options and persists officialPlan',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isarDatabaseProvider.overrideWith((ref) async => isar),
          appConfigServiceProvider
              .overrideWith((ref) async => appConfigService),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FirstRunSetupPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إعداد الحصص الأسبوعية'), findsOneWidget);
    expect(find.text('30 حصة لجميع الصفوف'), findsOneWidget);
    expect(find.text('الخطة الدراسية الرسمية'), findsOneWidget);
    expect(
      find.text(
        'يمكنك تعديل هذه الإعدادات لاحقًا من الإعدادات أو من تفاصيل الصف. هذا التخصيص اختياري.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم المدرسة'),
      'ثانوية الرافدين',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم المدير'),
      'الأستاذ أحمد',
    );

    final stageOption = find.text(SchoolStage.middleAndAbove.label);
    await tester.ensureVisible(stageOption);
    await tester.tap(stageOption);
    await tester.pumpAndSettle();

    final officialOption = find.text('الخطة الدراسية الرسمية');
    await tester.ensureVisible(officialOption);
    await tester.tap(officialOption);
    await tester.pumpAndSettle();

    final saveButton = find.text('حفظ وبدء الاستخدام');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final savedConfig = await appConfigService.load();
    expect(savedConfig.isSetupCompleted, isTrue);
    expect(savedConfig.schoolStage, SchoolStage.middleAndAbove);
    expect(savedConfig.weeklyLoadMode, WeeklyLoadMode.officialPlan);
  });
}
