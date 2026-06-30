import 'dart:convert';
import 'package:isar/isar.dart';

import '../models/teacher.dart';
import '../models/subject.dart';
import '../models/classroom.dart';
import '../models/lesson.dart';
import '../models/settings.dart';

class BackupService {
  final Isar _isar;

  BackupService(this._isar);

  Future<String> exportDatabaseToJson() async {
    final teachers = await _isar.teachers.where().findAll();
    final subjects = await _isar.subjects.where().findAll();
    final classrooms = await _isar.classrooms.where().findAll();
    final lessons = await _isar.lessons.where().findAll();
    final settings = await _isar.appSettings.where().findAll();

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
      'settings': settings
          .map((s) => {
                'id': s.id,
                'periodsPerDay': s.periodsPerDay,
                'daysPerWeek': s.daysPerWeek,
                'exportPageSize': s.exportPageSize,
                'exportOrientation': s.exportOrientation,
                'exportAutoScale': s.exportAutoScale,
              })
          .toList(),
      'lessons': lessons
          .map((l) => {
                'id': l.id,
                'teacherId': l.teacher.value?.id,
                'subjectId': l.subject.value?.id,
                'classroomId': l.classroom.value?.id,
                'dayIndex': l.dayIndex,
                'periodIndex': l.periodIndex,
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
      await _isar.appSettings.clear();

      if (data.containsKey('settings')) {
        final List<dynamic> settingsList = data['settings'];
        final newSettings = settingsList
            .map((s) => AppSettings()
              ..id = s['id']
              ..periodsPerDay = s['periodsPerDay']
              ..daysPerWeek = s['daysPerWeek']
              ..exportPageSize = s['exportPageSize'] ?? 'A4'
              ..exportOrientation = s['exportOrientation'] ?? 'Landscape'
              ..exportAutoScale = s['exportAutoScale'] ?? true)
            .toList();
        await _isar.appSettings.putAll(newSettings);
      }

      final Map<int, Teacher> teacherMap = {};
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
        for (final t in newTeachers) {
          teacherMap[t.id] = t;
        }
      }

      final Map<int, Subject> subjectMap = {};
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
        for (final s in newSubjects) {
          subjectMap[s.id] = s;
        }
      }

      final Map<int, Classroom> classroomMap = {};
      if (data.containsKey('classrooms')) {
        final List<dynamic> classroomsList = data['classrooms'];
        final newClassrooms = classroomsList
            .map((c) => Classroom()
              ..id = c['id']
              ..name = c['name']
              ..grade = c['grade'])
            .toList();
        await _isar.classrooms.putAll(newClassrooms);
        for (final c in newClassrooms) {
          classroomMap[c.id] = c;
        }
      }

      if (data.containsKey('lessons')) {
        final List<dynamic> lessonsList = data['lessons'];
        final newLessons = lessonsList
            .map((l) => Lesson()
              ..id = l['id']
              ..dayIndex = l['dayIndex']
              ..periodIndex = l['periodIndex'])
            .toList();

        // Map relationships using in-memory maps
        for (var i = 0; i < lessonsList.length; i++) {
          final lMap = lessonsList[i];
          final l = newLessons[i];

          if (lMap['teacherId'] != null) {
            final tId = lMap['teacherId'] as int;
            if (teacherMap.containsKey(tId)) {
              l.teacher.value = teacherMap[tId];
            }
          }
          if (lMap['subjectId'] != null) {
            final sId = lMap['subjectId'] as int;
            if (subjectMap.containsKey(sId)) {
              l.subject.value = subjectMap[sId];
            }
          }
          if (lMap['classroomId'] != null) {
            final cId = lMap['classroomId'] as int;
            if (classroomMap.containsKey(cId)) {
              l.classroom.value = classroomMap[cId];
            }
          }
        }

        // Put all objects in one batch call to avoid individual save() iterations
        await _isar.lessons.putAll(newLessons);

        // Ensure IsarLinks are explicitly flushed to DB after putAll,
        // using the transaction's existing scope without sequential individual awaits
        // Isar 3.x implicitly saves linked objects if they are assigned before putAll IF there are cascading configurations.
        // If not, we have to save them sequentially per Isar's limitations unless putAll saves them.
        for (final l in newLessons) {
          await l.teacher.save();
          await l.subject.save();
          await l.classroom.save();
        }
      }
    });
  }
}
