import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jadwal_v2/core/providers/app_config_provider.dart';
import 'package:jadwal_v2/core/providers/database_provider.dart';
import 'package:jadwal_v2/features/timetable/presentation/providers/timetable_provider.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';
import 'package:jadwal_v2/core/services/app_backup_service.dart';
import 'package:jadwal_v2/core/services/app_config_service.dart';
import 'package:jadwal_v2/core/services/backup_service.dart';

void main() {
  late Isar isar;
  late Directory tempDirectory;
  late AppConfigService appConfigService;
  late AppBackupService appBackupService;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory =
        await Directory.systemTemp.createTemp('jadwal_app_backup_test');
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
      name: 'app_backup_test',
    );
    appConfigService = AppConfigService(
      file: File('${tempDirectory.path}${Platform.pathSeparator}'
          '${AppConfigService.fileName}'),
    );
    appBackupService = AppBackupService(
      databaseBackup: BackupService(isar),
      appConfigService: appConfigService,
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('يصدّر بيانات قاعدة البيانات وحالة الإعداد الأولي معًا', () async {
    await isar.writeTxn(() async {
      await isar.appSettings.clear();
      await isar.subjectConstraints.clear();
      await isar.appSettings.put(
        AppSettings()
          ..schoolName = 'مدرسة النور'
          ..principalName = 'الأستاذ علي'
          ..periodsPerDay = 7
          ..daysPerWeek = 5,
      );
      await isar.subjectConstraints.put(
        SubjectConstraint()
          ..grade = 'الصف الأول'
          ..subjectName = 'اللغة العربية'
          ..maxPeriodsPerDay = 2,
      );
    });
    await appConfigService.save(
      AppConfig.initial().copyWith(
        isSetupCompleted: true,
        schoolStage: SchoolStage.primary,
        managedAutoConstraints: const {'الصف الأول\u001Fاللغة العربية': 2},
      ),
    );

    final exported = await appBackupService.exportToJson();
    final data = jsonDecode(exported) as Map<String, dynamic>;

    expect(data.containsKey(AppBackupService.appConfigKey), isTrue);
    final settingsJson =
        (data['settings'] as List<dynamic>).first as Map<String, dynamic>;
    expect(settingsJson['schoolName'], 'مدرسة النور');
    expect(settingsJson['principalName'], 'الأستاذ علي');
    final constraintsJson = data['subjectConstraints'] as List<dynamic>;
    expect(
      (constraintsJson.first as Map<String, dynamic>)['maxPeriodsPerDay'],
      2,
    );
    final configJson = data[AppBackupService.appConfigKey] as Map<String, dynamic>;
    expect(configJson['schoolStage'], 'primary');

    // مسح الحالة ثم الاستيراد للتحقق من الاستعادة الكاملة.
    await isar.writeTxn(() async {
      await isar.appSettings.clear();
      await isar.subjectConstraints.clear();
    });
    await appConfigService.save(AppConfig.initial());

    await appBackupService.importFromJson(exported);

    final restoredSettings = await isar.appSettings.where().findFirst();
    expect(restoredSettings?.schoolName, 'مدرسة النور');
    expect(restoredSettings?.principalName, 'الأستاذ علي');
    final restoredConstraints = await isar.subjectConstraints.where().findAll();
    expect(restoredConstraints, hasLength(1));
    expect(restoredConstraints.single.subjectName, 'اللغة العربية');

    final restoredConfig = await appConfigService.load();
    expect(restoredConfig.isSetupCompleted, isTrue);
    expect(restoredConfig.schoolStage, SchoolStage.primary);
    expect(restoredConfig.managedAutoConstraints, hasLength(1));
  });

  test('يستورد النسخ القديمة (بلا مقطع appConfig) دون المساس بالإعدادات',
      () async {
    await appConfigService.save(
      AppConfig.initial().copyWith(
        isSetupCompleted: true,
        schoolStage: SchoolStage.primary,
      ),
    );

    await appBackupService.importFromJson(
      jsonEncode({
        'subjects': <dynamic>[],
        'teachers': <dynamic>[],
        'classrooms': <dynamic>[],
        'lessons': <dynamic>[],
        'settings': <dynamic>[],
      }),
    );

    final config = await appConfigService.load();
    expect(config.isSetupCompleted, isTrue);
    expect(config.schoolStage, SchoolStage.primary);
  });

  test(
      'يصدّر ويستورد سياسة الحصص الأسبوعية والخطة الرسمية وتخصيص الصفوف',
      () async {
    await isar.writeTxn(() async {
      await isar.classrooms.clear();
      await isar.classrooms.putAll(<Classroom>[
        Classroom()
          ..name = 'السادس أ'
          ..grade = 'الصف السادس',
        Classroom()
          ..name = 'السادس ب'
          ..grade = 'الصف السادس'
          ..weeklyOverride = const ClassroomWeeklyOverride(
            weeklyLessons: 31,
            dailyPeriods: <int>[6, 6, 7, 6, 6],
          ),
      ]);
    });

    final customPlan = const OfficialWeeklyPlan.standard().copyWithEntry(
      track: OfficialPlanTrack.primary,
      grade: AcademicGrade.sixth,
      weeklyLessons: 32,
    );
    await appConfigService.save(
      AppConfig(
        isSetupCompleted: true,
        schoolStage: SchoolStage.primary,
        weeklyLoadMode: WeeklyLoadMode.officialPlan,
        officialWeeklyPlan: customPlan,
        managedAutoConstraints: const <String, int>{},
        dismissedAutoConstraints: const <String>{},
      ),
    );

    final exportedJson = await appBackupService.exportToJson();

    await isar.writeTxn(() async {
      await isar.classrooms.clear();
    });
    await appConfigService.save(AppConfig.initial());

    await appBackupService.importFromJson(exportedJson);

    final restoredConfig = await appConfigService.load();
    expect(restoredConfig.weeklyLoadMode, WeeklyLoadMode.officialPlan);
    expect(
      restoredConfig.officialWeeklyPlan
          .lessonsFor(OfficialPlanTrack.primary, AcademicGrade.sixth),
      32,
    );

    final restoredClassrooms = await isar.classrooms.where().findAll();
    expect(restoredClassrooms.length, 2);

    final withoutOverride =
        restoredClassrooms.firstWhere((c) => c.name == 'السادس أ');
    expect(withoutOverride.hasWeeklyOverride, isFalse);
    expect(withoutOverride.weeklyOverride, isNull);

    final withOverride =
        restoredClassrooms.firstWhere((c) => c.name == 'السادس ب');
    expect(withOverride.hasWeeklyOverride, isTrue);
    expect(withOverride.weeklyLessonsOverride, 31);
    expect(withOverride.dailyPeriodsOverride, <int>[6, 6, 7, 6, 6]);
    final effective = restoredConfig.resolveWeeklyConfigForClassroom(
        withOverride, daysPerWeek: 5);
    expect(effective.weeklyTarget, 31);
    expect(effective.dailyPeriods, [6, 6, 7, 6, 6]);
    final inherited = restoredConfig.resolveWeeklyConfigForClassroom(
        withoutOverride, daysPerWeek: 5);
    expect(inherited.weeklyTarget, 32);
    expect(inherited.dailyPeriods, [7, 7, 6, 6, 6]);
  });
  test('legacy backup missing all weekly keys resolves default capacity', () async {
    await appConfigService.save(AppConfig.initial());
    await appBackupService.importFromJson(jsonEncode({
      'subjects': [], 'teachers': [], 'lessons': [], 'settings': [],
      'classrooms': [{'id': 91, 'name': 'قديم', 'grade': 'الصف السادس'}],
      'appConfig': {'isSetupCompleted': true, 'schoolStage': 'primary'},
    }));
    final config = await appConfigService.load();
    final classroom = (await isar.classrooms.get(91))!;
    expect(config.weeklyLoadMode, WeeklyLoadMode.uniform30);
    expect(classroom.weeklyOverride, isNull);
    expect(classroom.dailyPeriodsOverride, isNull);
    final effective = config.resolveWeeklyConfigForClassroom(
        classroom, daysPerWeek: 5);
    expect(effective.weeklyTarget, 30);
    expect(effective.dailyPeriods, [6, 6, 6, 6, 6]);
  });

  test('Notifier rejects drag outside daily profile without persisting it', () async {
    await appConfigService.save(AppConfig.initial());
    final classroom = Classroom()
      ..name = 'اختبار النقل'
      ..grade = 'الصف السادس'
      ..weeklyOverride = const ClassroomWeeklyOverride(
          weeklyLessons: 31, dailyPeriods: [6, 6, 7, 6, 6]);
    final lesson = Lesson()
      ..dayIndex = 0
      ..periodIndex = 0;
    await isar.writeTxn(() async {
      await isar.lessons.clear();
      await isar.classrooms.put(classroom);
      lesson.classroom.value = classroom;
      await isar.lessons.put(lesson);
      await lesson.classroom.save();
    });
    final container = ProviderContainer(overrides: [
      isarDatabaseProvider.overrideWith((ref) async => isar),
      appConfigServiceProvider.overrideWith((ref) async => appConfigService),
    ]);
    final subscription = container.listen(timetableNotifierProvider,
        (previous, next) {});
    try {
      await container.read(timetableNotifierProvider.future);
      final notifier = container.read(timetableNotifierProvider.notifier);
      final result = await notifier.moveLessonToEmpty(lesson, 0, 6);
      expect(result.$1, isFalse);
      expect(result.$2, contains('خارج التوزيع اليومي'));
      final saved = (await isar.lessons.get(lesson.id))!;
      expect(saved.dayIndex, 0);
      expect(saved.periodIndex, 0);
    } finally {
      subscription.close();
      container.dispose();
    }
  });

}
