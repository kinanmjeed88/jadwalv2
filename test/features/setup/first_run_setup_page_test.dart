import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/core/providers/app_config_provider.dart';
import 'package:jadwal_v2/core/services/app_config_service.dart';
import 'package:jadwal_v2/features/management/data/services/subject_constraint_auto_sync_service.dart';
import 'package:jadwal_v2/features/management/presentation/providers/management_provider.dart';
import 'package:jadwal_v2/features/management/presentation/providers/subject_constraint_auto_sync_provider.dart';
import 'package:jadwal_v2/features/setup/presentation/pages/first_run_setup_page.dart';

class _InMemoryAppConfigService extends AppConfigService {
  _InMemoryAppConfigService([AppConfig? initial])
      : _config = initial ?? AppConfig.initial(),
        super(file: File('in_memory_config.json'));

  AppConfig _config;

  @override
  Future<AppConfig> load() async => _config;

  @override
  Future<void> save(AppConfig config) async {
    _config = config;
  }
}

class _SettingsHolder {
  AppSettings current = AppSettings()..periodsPerDay = 7;
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._holder);

  final _SettingsHolder _holder;

  @override
  Future<AppSettings> build() async => _holder.current;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _holder.current = settings;
    state = AsyncData(_holder.current);
  }
}

class _NoOpSyncController extends SubjectConstraintAutoSyncController {
  _NoOpSyncController()
      : super(
          readIsar: () => throw UnimplementedError(),
          readConfig: () async => AppConfig.initial(),
          replaceConfig: (_) async {},
        );

  @override
  Future<AutoConstraintSyncOutcome?> run() async => null;
}

void main() {
  testWidgets(
      'FirstRunSetupPage displays weekly load options and persists officialPlan',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final configService = _InMemoryAppConfigService();
    final settingsHolder = _SettingsHolder();
    final syncController = _NoOpSyncController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigServiceProvider.overrideWith((ref) async => configService),
          settingsNotifierProvider
              .overrideWith(() => _FakeSettingsNotifier(settingsHolder)),
          subjectConstraintAutoSyncProvider.overrideWithValue(syncController),
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

    final visibleTexts =
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    expect(
      find.text('إعداد الحصص الأسبوعية'),
      findsOneWidget,
      reason: 'Visible texts: $visibleTexts',
    );
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

    final savedConfig = await configService.load();
    expect(savedConfig.isSetupCompleted, isTrue);
    expect(savedConfig.schoolStage, SchoolStage.middleAndAbove);
    expect(savedConfig.weeklyLoadMode, WeeklyLoadMode.officialPlan);
  });
}
