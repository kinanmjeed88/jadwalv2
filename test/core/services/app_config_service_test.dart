import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/services/app_config_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory =
        await Directory.systemTemp.createTemp('jadwal_app_config_test');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  AppConfigService serviceIn(Directory directory) {
    return AppConfigService(
      file: File('${directory.path}${Platform.pathSeparator}'
          '${AppConfigService.fileName}'),
    );
  }

  test('يعيد الإعدادات الافتراضية عند غياب الملف', () async {
    final service = serviceIn(tempDirectory);

    final config = await service.load();

    expect(config.isSetupCompleted, isFalse);
    expect(config.schoolStage, SchoolStage.fallback);
    expect(config, AppConfig.initial());
  });

  test('يحفظ الإعدادات ويقرأها كما هي', () async {
    final service = serviceIn(tempDirectory);
    final config = AppConfig.initial().copyWith(
      isSetupCompleted: true,
      schoolStage: SchoolStage.primary,
      managedAutoConstraints: const {'الصف الأول\u001Fاللغة العربية': 2},
      dismissedAutoConstraints: const {'الصف الثاني\u001Fالرياضيات'},
    );

    await service.save(config);
    final reloaded = await service.load();

    expect(reloaded, config);
  });

  test('ينشئ المجلد الأب عند عدم وجوده', () async {
    final nestedDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}nested'
      '${Platform.pathSeparator}config',
    );
    final service = serviceIn(nestedDirectory);

    await service.save(
      AppConfig.initial().copyWith(
        isSetupCompleted: true,
        schoolStage: SchoolStage.primary,
      ),
    );

    expect(await service.file.exists(), isTrue);
    expect((await service.load()).schoolStage, SchoolStage.primary);
  });

  test('يعود للافتراضي عند تلف محتوى الملف', () async {
    final service = serviceIn(tempDirectory);
    await service.file.writeAsString('{ هذا ليس JSON صالحًا');

    final config = await service.load();

    expect(config, AppConfig.initial());
  });

  test('لا يترك ملفًا مؤقتًا بعد الحفظ', () async {
    final service = serviceIn(tempDirectory);

    await service.save(AppConfig.initial().copyWith(isSetupCompleted: true));

    final temporaryFile = File(
      '${service.file.path}${AppConfigService.temporaryExtension}',
    );
    expect(await temporaryFile.exists(), isFalse);
  });

  test('الحفظ المتكرر يستبدل الملف السابق', () async {
    final service = serviceIn(tempDirectory);

    await service.save(AppConfig.initial().copyWith(
      schoolStage: SchoolStage.primary,
      managedAutoConstraints: const {'a': 2, 'b': 3},
    ));
    await service.save(AppConfig.initial().copyWith(
      isSetupCompleted: true,
      schoolStage: SchoolStage.middleAndAbove,
    ));

    final reloaded = await service.load();

    expect(reloaded.isSetupCompleted, isTrue);
    expect(reloaded.schoolStage, SchoolStage.middleAndAbove);
    expect(reloaded.managedAutoConstraints, isEmpty);
  });
}
