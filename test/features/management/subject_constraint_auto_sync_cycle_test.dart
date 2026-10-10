import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/school_stage.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/subject_constraint_key.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/providers/app_config_provider.dart';
import 'package:jadwal_v2/core/providers/database_provider.dart';
import 'package:jadwal_v2/core/services/app_config_service.dart';
import 'package:jadwal_v2/features/management/presentation/providers/management_provider.dart';
import 'package:jadwal_v2/features/management/presentation/providers/subject_constraint_auto_sync_provider.dart';

/// دورة القيود التلقائية كاملة (إنشاء ← نقل ← حذف ← استعادة) عبر المزوّدات
/// الحقيقية: متحكّم المزامنة، و[SubjectsNotifier.saveSubjectConstraint]،
/// وإعدادات التطبيق المحفوظة في ملف، على قاعدة Isar حقيقية.
///
/// تحاكي الدالتان [saveLikePage] و[deleteLikePage] تسلسل الاستدعاءات في
/// `SubjectConstraintsPage._saveConstraint` و`_deleteConstraint` حرفيًا.
void main() {
  late Isar isar;
  late Directory configDirectory;
  late ProviderContainer container;
  final subscriptions = <ProviderSubscription<Object?>>[];

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [
        TeacherSchema,
        SubjectSchema,
        ClassroomSchema,
        LessonSchema,
        AppSettingsSchema,
        SubjectConstraintSchema,
      ],
      directory: Directory.systemTemp.path,
      name: 'subject_constraint_auto_sync_cycle_test',
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
  });

  setUp(() async {
    await isar.writeTxn(() async {
      await isar.clear();
      await isar.appSettings.put(
        AppSettings()
          ..periodsPerDay = 6
          ..daysPerWeek = 5,
      );
      await isar.classrooms.putAll([
        Classroom()
          ..name = 'A'
          ..grade = 'G1',
        Classroom()
          ..name = 'B'
          ..grade = 'G2',
      ]);
      await isar.subjects.putAll([
        _subject('Arabic', 6),
        _subject('Math', 4),
      ]);
    });

    configDirectory =
        await Directory.systemTemp.createTemp('jadwal_auto_sync_config_');
    container = ProviderContainer(
      overrides: [
        isarDatabaseProvider.overrideWith((ref) async => isar),
        appConfigServiceProvider.overrideWith(
          (ref) async => AppConfigService(
            file: File(
              '${configDirectory.path}${Platform.pathSeparator}'
              '${AppConfigService.fileName}',
            ),
          ),
        ),
      ],
    );
    subscriptions
      ..add(container.listen(appConfigNotifierProvider, (_, __) {}))
      ..add(container.listen(subjectsNotifierProvider, (_, __) {}));
    await container.read(subjectsNotifierProvider.future);
    await container.read(appConfigNotifierProvider.future);
    await container.read(appConfigNotifierProvider.notifier).replace(
          AppConfig.initial().copyWith(
            isSetupCompleted: true,
            schoolStage: SchoolStage.primary,
          ),
        );
  });

  tearDown(() async {
    for (final subscription in subscriptions) {
      subscription.close();
    }
    subscriptions.clear();
    container.dispose();
    await configDirectory.delete(recursive: true);
  });

  SubjectConstraintAutoSyncController sync() =>
      container.read(subjectConstraintAutoSyncProvider);

  /// كل القيود المخزَّنة (تظهر التكرارات إن وُجدت).
  Future<List<String>> storedConstraints() async {
    final constraints = await isar.subjectConstraints.where().findAll();
    return [
      for (final constraint in constraints)
        '${constraint.grade}/${constraint.subjectName}='
            '${constraint.maxPeriodsPerDay}',
    ]..sort();
  }

  Future<SubjectConstraint> storedConstraint(String grade, String subject) {
    return isar.subjectConstraints
        .filter()
        .gradeEqualTo(grade)
        .and()
        .subjectNameEqualTo(subject)
        .findFirst()
        .then((constraint) => constraint!);
  }

  Future<AppConfig> config() =>
      container.read(appConfigNotifierProvider.future);

  String storage(String grade, String subject) =>
      SubjectConstraintKey(grade: grade, subjectName: subject).storageKey;

  Future<void> saveLikePage({
    required int? constraintId,
    SubjectConstraintKey? originalKey,
    required String grade,
    required String subjectName,
    required int maxPeriods,
  }) async {
    final newKey = SubjectConstraintKey(grade: grade, subjectName: subjectName);
    if (originalKey != null && originalKey.storageKey != newKey.storageKey) {
      await sync().recordManualDeletion(originalKey);
    }
    await container
        .read(subjectsNotifierProvider.notifier)
        .saveSubjectConstraint(
          constraintId: constraintId,
          grade: grade,
          subjectName: subjectName,
          maxPeriodsPerDay: maxPeriods,
          consecutiveness: SubjectConsecutiveness.any,
        );
    await sync().recordManualDefinition(newKey);
  }

  Future<void> deleteLikePage(SubjectConstraint constraint) async {
    await sync().recordManualDeletion(
      SubjectConstraintKey.fromConstraint(constraint),
    );
    await isar.writeTxn(() async {
      await isar.subjectConstraints.delete(constraint.id);
    });
  }

  Future<void> setWeeklyLessons(String subjectName, int lessonsPerWeek) async {
    await isar.writeTxn(() async {
      final subject =
          (await isar.subjects.filter().nameEqualTo(subjectName).findFirst())!;
      subject.lessonsPerWeek = lessonsPerWeek;
      await isar.subjects.put(subject);
    });
  }

  test('create → move → delete → restore keeps user decisions', () async {
    // 1) الإنشاء: العربي (6 حصص) مؤهل في الصفين بحد 2؛ الرياضيات (4) لا.
    final created = await sync().run();
    expect(created!.createdKeys, hasLength(2));
    expect(await storedConstraints(), ['G1/Arabic=2', 'G2/Arabic=2']);
    expect((await config()).managedAutoConstraints, {
      storage('G1', 'Arabic'): 2,
      storage('G2', 'Arabic'): 2,
    });
    expect((await sync().run())!.hasChanges, isFalse);

    // 2) النقل: تعديل قيد (G1/Arabic) التلقائي إلى (G1/Math) بحد 3.
    final g1Arabic = await storedConstraint('G1', 'Arabic');
    await saveLikePage(
      constraintId: g1Arabic.id,
      originalKey: SubjectConstraintKey.fromConstraint(g1Arabic),
      grade: 'G1',
      subjectName: 'Math',
      maxPeriods: 3,
    );
    await sync().run();
    await sync().run();
    expect(await storedConstraints(), ['G1/Math=3', 'G2/Arabic=2']);
    expect((await config()).managedAutoConstraints, {
      storage('G2', 'Arabic'): 2,
    });
    expect(
      (await config()).dismissedAutoConstraints,
      {storage('G1', 'Arabic')},
    );

    // 3) الحذف: حذف القيد التلقائي (G2/Arabic) لا يُعاد إنشاؤه.
    await deleteLikePage(await storedConstraint('G2', 'Arabic'));
    await sync().run();
    expect(await storedConstraints(), ['G1/Math=3']);
    expect((await config()).managedAutoConstraints, isEmpty);
    expect((await config()).dismissedAutoConstraints, {
      storage('G1', 'Arabic'),
      storage('G2', 'Arabic'),
    });

    // 4) الاستعادة اليدوية: يعيد المستخدم (G2/Arabic) بحد 1 فيبقى قيدًا يدويًا.
    await saveLikePage(
      constraintId: null,
      grade: 'G2',
      subjectName: 'Arabic',
      maxPeriods: 1,
    );
    await sync().run();
    await setWeeklyLessons('Arabic', 7);
    await sync().run();
    expect(await storedConstraints(), ['G1/Math=3', 'G2/Arabic=1']);
    expect((await config()).managedAutoConstraints, isEmpty);
    expect(
      (await config()).dismissedAutoConstraints,
      {storage('G1', 'Arabic')},
    );

    // 5) الاستعادة بالسياسة: ينخفض النصاب تحت 6 فيُنسى الحذف، ثم يعود فيُعاد
    // إنشاء القيد التلقائي، ويبقى القيد اليدوي كما هو.
    await setWeeklyLessons('Arabic', 4);
    await sync().run();
    expect((await config()).dismissedAutoConstraints, isEmpty);
    expect(await storedConstraints(), ['G1/Math=3', 'G2/Arabic=1']);

    await setWeeklyLessons('Arabic', 6);
    final restored = await sync().run();
    expect(restored!.createdKeys, [storage('G1', 'Arabic')]);
    expect(
      await storedConstraints(),
      ['G1/Arabic=2', 'G1/Math=3', 'G2/Arabic=1'],
    );
    expect((await config()).managedAutoConstraints, {
      storage('G1', 'Arabic'): 2,
    });
  });

  test('moving a constraint onto a key that already has one leaves one record',
      () async {
    await sync().run();
    await saveLikePage(
      constraintId: null,
      grade: 'G1',
      subjectName: 'Math',
      maxPeriods: 1,
    );
    expect(
      await storedConstraints(),
      ['G1/Arabic=2', 'G1/Math=1', 'G2/Arabic=2'],
    );

    // نقل قيد (G1/Math) اليدوي إلى (G1/Arabic) الموجود مسبقًا بحد 3.
    final g1Math = await storedConstraint('G1', 'Math');
    await saveLikePage(
      constraintId: g1Math.id,
      originalKey: SubjectConstraintKey.fromConstraint(g1Math),
      grade: 'G1',
      subjectName: 'Arabic',
      maxPeriods: 3,
    );
    await sync().run();

    expect(await storedConstraints(), ['G1/Arabic=3', 'G2/Arabic=2']);
    expect((await config()).managedAutoConstraints, {
      storage('G2', 'Arabic'): 2,
    });
    expect((await config()).dismissedAutoConstraints, isEmpty);
    expect((await storedConstraint('G1', 'Arabic')).id, g1Math.id);
  });

  test('editing only the value of an auto constraint makes it manual',
      () async {
    await sync().run();
    final g1Arabic = await storedConstraint('G1', 'Arabic');
    await saveLikePage(
      constraintId: g1Arabic.id,
      originalKey: SubjectConstraintKey.fromConstraint(g1Arabic),
      grade: 'G1',
      subjectName: 'Arabic',
      maxPeriods: 3,
    );
    await setWeeklyLessons('Arabic', 4);
    await sync().run();

    // G2 التلقائي يُزال لخروجه من السياسة، وG1 المعدَّل يدويًا يبقى.
    expect(await storedConstraints(), ['G1/Arabic=3']);
    expect((await config()).managedAutoConstraints, isEmpty);
  });
}

Subject _subject(String name, int lessonsPerWeek) {
  return Subject()
    ..name = name
    ..lessonsPerWeek = lessonsPerWeek
    ..preferEarlyPeriods = false
    ..allowedPeriods = <int>[]
    ..consecutiveness = SubjectConsecutiveness.any;
}
