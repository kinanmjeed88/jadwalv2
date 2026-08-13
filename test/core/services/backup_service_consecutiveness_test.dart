import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
import 'package:jadwal_v2/core/models/subject_consecutiveness.dart';
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
}
