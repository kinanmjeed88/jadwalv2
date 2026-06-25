import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/teacher.dart';
import '../models/subject.dart';
import '../models/classroom.dart';
import '../models/lesson.dart';
import '../models/settings.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isarDatabase(IsarDatabaseRef ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      TeacherSchema,
      SubjectSchema,
      ClassroomSchema,
      LessonSchema,
      AppSettingsSchema,
    ],
    directory: dir.path,
  );

  // Initialize default settings if empty
  if (await isar.appSettings.count() == 0) {
    await isar.writeTxn(() async {
      final settings = AppSettings()..periodsPerDay = 7;
      await isar.appSettings.put(settings);
    });
  }

  return isar;
}
