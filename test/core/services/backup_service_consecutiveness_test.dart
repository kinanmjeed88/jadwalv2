import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
import 'package:jadwal_v2/core/models/subject_constraint.dart';
import 'package:jadwal_v2/core/models/teacher.dart';
import 'package:jadwal_v2/core/services/backup_service.dart';

void main() {
  late Isar isar;
  late BackupService backupService;

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
      name: 'consecutiveness_backup_test',
    );
    backupService = BackupService(isar);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('exports and restores all consecutiveness values', () async {
    final subjects = [
      Subject()
        ..id = 1
        ..name = 'Any'
        ..lessonsPerWeek = 1
        ..allowedPeriods = const []
        ..consecutiveness = SubjectConsecutiveness.any,
      Subject()
        ..id = 2
        ..name = 'Consecutive'
        ..lessonsPerWeek = 1
        ..allowedPeriods = const []
        ..consecutiveness = SubjectConsecutiveness.consecutive,
      Subject()
        ..id = 3
        ..name = 'Non consecutive'
        ..lessonsPerWeek = 1
        ..allowedPeriods = const []
        ..consecutiveness = SubjectConsecutiveness.nonConsecutive,
    ];

    await isar.writeTxn(() async {
      await isar.subjects.putAll(subjects);
    });

    final exported = await backupService.exportDatabaseToJson();
    final exportedSubjects = (jsonDecode(exported)
        as Map<String, dynamic>)['subjects'] as List<dynamic>;
    expect(
      exportedSubjects
          .map((subject) => subject['consecutiveness'])
          .toList(growable: false),
      ['any', 'consecutive', 'nonConsecutive'],
    );

    await backupService.importDatabaseFromJson(
      jsonEncode({
        'subjects': [
          {
            'id': 10,
            'name': 'Legacy subject',
            'lessonsPerWeek': 1,
            'preferEarlyPeriods': false,
            'allowedPeriods': [],
          },
          {
            'id': 11,
            'name': 'Unknown subject',
            'lessonsPerWeek': 1,
            'preferEarlyPeriods': false,
            'allowedPeriods': [],
            'consecutiveness': 'future-policy',
          },
        ],
      }),
    );

    final restored = await isar.subjects.where().findAll();
    expect(restored.map((subject) => subject.consecutiveness), [
      SubjectConsecutiveness.any,
      SubjectConsecutiveness.any,
    ]);
  });

  test('exports school settings and subject constraints and restores them',
      () async {
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

    final exported = await backupService.exportDatabaseToJson();
    final data = jsonDecode(exported) as Map<String, dynamic>;
    final settingsJson = (data['settings'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect(settingsJson['schoolName'], 'مدرسة النور');
    expect(settingsJson['principalName'], 'الأستاذ علي');
    final constraintsJson = data['subjectConstraints'] as List<dynamic>;
    expect(constraintsJson, hasLength(1));
    expect(
      (constraintsJson.first as Map<String, dynamic>)['maxPeriodsPerDay'],
      2,
    );

    await isar.writeTxn(() async {
      await isar.appSettings.clear();
      await isar.subjectConstraints.clear();
    });

    await backupService.importDatabaseFromJson(exported);

    final restoredSettings = await isar.appSettings.where().findFirst();
    expect(restoredSettings?.schoolName, 'مدرسة النور');
    expect(restoredSettings?.principalName, 'الأستاذ علي');
    final restoredConstraints = await isar.subjectConstraints.where().findAll();
    expect(restoredConstraints, hasLength(1));
    expect(restoredConstraints.single.grade, 'الصف الأول');
    expect(restoredConstraints.single.subjectName, 'اللغة العربية');
    expect(restoredConstraints.single.maxPeriodsPerDay, 2);
  });

  test('roundtrips teacher periods, pinned lessons, and custom page size',
      () async {
    await isar.writeTxn(() async {
      await isar.teachers.clear();
      await isar.subjects.clear();
      await isar.classrooms.clear();
      await isar.lessons.clear();
      await isar.appSettings.clear();
      await isar.subjectConstraints.clear();
      final teacher = Teacher()
        ..id = 1
        ..name = 'معلم'
        ..specialization = 'رياضيات'
        ..maxLessonsPerDay = 5
        ..maxLessonsPerWeek = 20
        ..unavailableDays = [0]
        ..allowedPeriods = [1, 3];
      final subject = Subject()
        ..id = 1
        ..name = 'رياضيات'
        ..lessonsPerWeek = 6
        ..allowedPeriods = const [];
      final classroom = Classroom()
        ..id = 1
        ..name = '1أ'
        ..grade = 'الصف الأول';
      await isar.teachers.put(teacher);
      await isar.subjects.put(subject);
      await isar.classrooms.put(classroom);
      await isar.appSettings.put(
        AppSettings()
          ..periodsPerDay = 7
          ..daysPerWeek = 5
          ..customPageWidth = 21.0
          ..customPageHeight = 29.7,
      );
      final lesson = Lesson()
        ..id = 1
        ..dayIndex = 0
        ..periodIndex = 1
        ..isPinned = true
        ..teacher.value = teacher
        ..subject.value = subject
        ..classroom.value = classroom;
      await isar.lessons.put(lesson);
      await lesson.teacher.save();
      await lesson.subject.save();
      await lesson.classroom.save();
    });

    final exported = await backupService.exportDatabaseToJson();
    final data = jsonDecode(exported) as Map<String, dynamic>;
    expect(
      List<int>.from(
        ((data['teachers'] as List<dynamic>).first
            as Map<String, dynamic>)['allowedPeriods'] as List<dynamic>,
      ),
      [1, 3],
    );
    expect(
      ((data['lessons'] as List<dynamic>).first
          as Map<String, dynamic>)['isPinned'],
      isTrue,
    );

    await isar.writeTxn(() async {
      await isar.teachers.clear();
      await isar.subjects.clear();
      await isar.classrooms.clear();
      await isar.lessons.clear();
      await isar.appSettings.clear();
      await isar.subjectConstraints.clear();
    });

    await backupService.importDatabaseFromJson(exported);

    final restoredTeacher = await isar.teachers.get(1);
    expect(restoredTeacher?.allowedPeriods, [1, 3]);
    final restoredSettings = await isar.appSettings.where().findFirst();
    expect(restoredSettings?.customPageWidth, 21.0);
    expect(restoredSettings?.customPageHeight, 29.7);
    final restoredLesson = await isar.lessons.get(1);
    expect(restoredLesson?.isPinned, isTrue);
    await restoredLesson?.teacher.load();
    await restoredLesson?.subject.load();
    await restoredLesson?.classroom.load();
    expect(restoredLesson?.teacher.value?.id, 1);
    expect(restoredLesson?.subject.value?.id, 1);
    expect(restoredLesson?.classroom.value?.id, 1);
  });

  test('imports legacy backups without subject constraints section', () async {
    await isar.writeTxn(() async {
      await isar.subjectConstraints.clear();
      await isar.subjectConstraints.put(
        SubjectConstraint()
          ..grade = 'الصف الثاني'
          ..subjectName = 'الرياضيات'
          ..maxPeriodsPerDay = 3,
      );
    });

    await backupService.importDatabaseFromJson(
      jsonEncode({
        'settings': [
          {'id': 1, 'periodsPerDay': 6, 'daysPerWeek': 4}
        ],
      }),
    );

    final restoredSettings = await isar.appSettings.where().findFirst();
    expect(restoredSettings?.schoolName, '');
    expect(restoredSettings?.principalName, '');
    expect(await isar.subjectConstraints.count(), 0);
  });
}
