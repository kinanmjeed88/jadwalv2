import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/app_config.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/weekly_load_policy.dart';

import '../../fixtures/legacy_classroom.dart';

void main() {
  test('reopens a real old Isar file and preserves classroom through updates',
      () async {
    await Isar.initializeIsarCore(download: true);
    final dir = await Directory.systemTemp.createTemp('weekly_migration_');
    Isar? db;
    try {
      db = await Isar.open([LegacyClassroomSchema],
          directory: dir.path, name: 'migration');
      final old = LegacyClassroom()
        ..id = 42
        ..name = 'السادس أ'
        ..grade = 'الصف السادس';
      final legacyDb = db;
      await legacyDb.writeTxn(() async {
        await legacyDb.collection<LegacyClassroom>().put(old);
      });
      await db.close();
      db = await Isar.open([ClassroomSchema],
          directory: dir.path, name: 'migration');
      final classroom = (await db.classrooms.get(42))!;
      expect(classroom.name, old.name);
      expect(classroom.grade, old.grade);
      expect(classroom.weeklyLessonsOverride, isNull);
      expect(classroom.dailyPeriodsOverride, isNull);
      expect(classroom.weeklyOverride, isNull);
      final effective = AppConfig.initial()
          .resolveWeeklyConfigForClassroom(classroom, daysPerWeek: 5);
      expect(effective.weeklyTarget, 30);
      expect(effective.dailyPeriods, [6, 6, 6, 6, 6]);
      classroom.name = 'السادس ب';
      classroom.weeklyOverride = const ClassroomWeeklyOverride(
          weeklyLessons: 31, dailyPeriods: [6, 6, 7, 6, 6]);
      final updatedDb = db;
      await updatedDb.writeTxn(() async {
        await updatedDb.classrooms.put(classroom);
      });
      await db.close();
      db = await Isar.open([ClassroomSchema],
          directory: dir.path, name: 'migration');
      final saved = (await db.classrooms.get(42))!;
      expect(saved.name, 'السادس ب');
      expect(saved.grade, old.grade);
      expect(saved.id, 42);
      final resolved = AppConfig.initial()
          .resolveWeeklyConfigForClassroom(saved, daysPerWeek: 5);
      expect(resolved.weeklyTarget, 31);
      expect(resolved.dailyPeriods, [6, 6, 7, 6, 6]);
    } finally {
      if (db != null && db.isOpen) await db.close();
      await dir.delete(recursive: true);
    }
  });
}
