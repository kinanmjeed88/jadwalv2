import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:jadwal_v2/core/models/classroom.dart';
import 'package:jadwal_v2/core/models/lesson.dart';
import 'package:jadwal_v2/core/models/settings.dart';
import 'package:jadwal_v2/core/models/subject.dart';
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
      directory: '.',
      name: 'benchmark_db',
    );
    backupService = BackupService(isar);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('Benchmark importDatabaseFromJson with 5000 lessons', () async {
    // Generate dummy JSON data
    const int numTeachers = 100;
    const int numSubjects = 50;
    const int numClassrooms = 50;
    const int numLessons = 5000;

    final Map<String, dynamic> data = {
      'teachers': List.generate(
          numTeachers,
          (i) => {
                'id': i + 1,
                'name': 'Teacher $i',
                'specialization': 'Spec $i',
                'maxLessonsPerDay': 5,
                'maxLessonsPerWeek': 25,
                'unavailableDays': [],
              }),
      'subjects': List.generate(
          numSubjects,
          (i) => {
                'id': i + 1,
                'name': 'Subject $i',
                'lessonsPerWeek': 5,
                'preferEarlyPeriods': false,
                'allowedPeriods': [],
              }),
      'classrooms': List.generate(
          numClassrooms,
          (i) => {
                'id': i + 1,
                'name': 'Classroom $i',
                'grade': 'Grade 10',
              }),
      'lessons': List.generate(
          numLessons,
          (i) => {
                'id': i + 1,
                'teacherId': (i % numTeachers) + 1,
                'subjectId': (i % numSubjects) + 1,
                'classroomId': (i % numClassrooms) + 1,
                'dayIndex': i % 5,
                'periodIndex': i % 7,
              }),
    };

    final jsonData = jsonEncode(data);

    print('Starting benchmark for $numLessons lessons...');
    final stopwatch = Stopwatch()..start();
    await backupService.importDatabaseFromJson(jsonData);
    stopwatch.stop();

    print(
        'Time taken to import $numLessons lessons: ${stopwatch.elapsedMilliseconds}ms');

    // Verify
    final count = await isar.lessons.count();
    expect(count, numLessons);
  });
}
