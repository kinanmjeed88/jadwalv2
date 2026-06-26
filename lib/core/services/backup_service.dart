import 'dart:convert';
import 'package:isar/isar.dart';

import '../models/teacher.dart';
import '../models/subject.dart';
import '../models/classroom.dart';
import '../models/lesson.dart';


class BackupService {
  final Isar _isar;

  BackupService(this._isar);

  Future<String> exportDatabaseToJson() async {
    final teachers = await _isar.teachers.where().findAll();
    final subjects = await _isar.subjects.where().findAll();
    final classrooms = await _isar.classrooms.where().findAll();
    // In a real scenario, we'd also export lessons and settings and handle IsarLinks.
    // Simplifying here to just export basic collections for demo.

    final Map<String, dynamic> data = {
      'teachers': teachers
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'specialization': t.specialization,
                'maxLessonsPerDay': t.maxLessonsPerDay,
                'maxLessonsPerWeek': t.maxLessonsPerWeek,
                'unavailableDays': t.unavailableDays,
              })
          .toList(),
      'subjects': subjects
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'lessonsPerWeek': s.lessonsPerWeek,
                'preferEarlyPeriods': s.preferEarlyPeriods,
                'allowedPeriods': s.allowedPeriods,
              })
          .toList(),
      'classrooms': classrooms
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'grade': c.grade,
              })
          .toList(),
    };

    return jsonEncode(data);
  }

  Future<void> importDatabaseFromJson(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;

    await _isar.writeTxn(() async {
      // Clear existing
      await _isar.teachers.clear();
      await _isar.subjects.clear();
      await _isar.classrooms.clear();
      await _isar.lessons.clear();

      if (data.containsKey('teachers')) {
        final List<dynamic> teachersList = data['teachers'];
        final newTeachers = teachersList
            .map((t) => Teacher()
              ..id = t['id']
              ..name = t['name']
              ..specialization = t['specialization']
              ..maxLessonsPerDay = t['maxLessonsPerDay']
              ..maxLessonsPerWeek = t['maxLessonsPerWeek']
              ..unavailableDays = List<int>.from(t['unavailableDays'] ?? []))
            .toList();
        await _isar.teachers.putAll(newTeachers);
      }

      if (data.containsKey('subjects')) {
        final List<dynamic> subjectsList = data['subjects'];
        final newSubjects = subjectsList
            .map((s) => Subject()
              ..id = s['id']
              ..name = s['name']
              ..lessonsPerWeek = s['lessonsPerWeek']
              ..preferEarlyPeriods = s['preferEarlyPeriods']
              ..allowedPeriods = List<int>.from(s['allowedPeriods'] ?? []))
            .toList();
        await _isar.subjects.putAll(newSubjects);
      }

      if (data.containsKey('classrooms')) {
        final List<dynamic> classroomsList = data['classrooms'];
        final newClassrooms = classroomsList
            .map((c) => Classroom()
              ..id = c['id']
              ..name = c['name']
              ..grade = c['grade'])
            .toList();
        await _isar.classrooms.putAll(newClassrooms);
      }
    });
  }
}
