import 'dart:convert';
import 'package:isar/isar.dart';

import '../models/teacher.dart';
import '../models/subject.dart';
import '../models/classroom.dart';
import '../models/lesson.dart';
import '../models/settings.dart';
import '../models/subject_consecutiveness.dart';
import '../models/subject_constraint.dart';

class BackupService {
  final Isar _isar;

  BackupService(this._isar);

  Future<String> exportDatabaseToJson() async {
    final teachers = await _isar.teachers.where().findAll();
    final subjects = await _isar.subjects.where().findAll();
    final classrooms = await _isar.classrooms.where().findAll();
    final lessons = await _isar.lessons.where().findAll();
    final settings = await _isar.appSettings.where().findAll();
    final subjectConstraints =
        await _isar.subjectConstraints.where().findAll();

    final Map<String, dynamic> data = {
      'teachers': teachers
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'specialization': t.specialization,
                'maxLessonsPerDay': t.maxLessonsPerDay,
                'maxLessonsPerWeek': t.maxLessonsPerWeek,
                'unavailableDays': t.unavailableDays,
                'allowedPeriods': t.allowedPeriods,
              })
          .toList(),
      'subjects': subjects
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'lessonsPerWeek': s.lessonsPerWeek,
                'preferEarlyPeriods': s.preferEarlyPeriods,
                'allowedPeriods': s.allowedPeriods,
                'consecutiveness': s.consecutiveness.storageName,
              })
          .toList(),
      'classrooms': classrooms
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'grade': c.grade,
                if (c.weeklyLessonsOverride != null)
                  'weeklyLessonsOverride': c.weeklyLessonsOverride,
                if (c.dailyPeriodsOverride != null)
                  'dailyPeriodsOverride': c.dailyPeriodsOverride,
              })
          .toList(),
      'settings': settings
            .map((s) => {
                  'id': s.id,
                  'schoolName': s.schoolName,
                  'principalName': s.principalName,
                  'periodsPerDay': s.periodsPerDay,
                  'daysPerWeek': s.daysPerWeek,
                  'exportPageSize': s.exportPageSize,
                  'exportOrientation': s.exportOrientation,
                  'exportAutoScale': s.exportAutoScale,
                  'customPageWidth': s.customPageWidth,
                  'customPageHeight': s.customPageHeight,
                })
            .toList(),
      'subjectConstraints': subjectConstraints
          .map((c) => {
                'id': c.id,
                'grade': c.grade,
                'subjectName': c.subjectName,
                'maxPeriodsPerDay': c.maxPeriodsPerDay,
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
                'isPinned': l.isPinned,
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
      await _isar.subjectConstraints.clear();

      if (data.containsKey('settings')) {
        final List<dynamic> settingsList = data['settings'];
        final newSettings = settingsList
            .map((s) => AppSettings()
              ..id = s['id']
              ..schoolName = s['schoolName'] ?? ''
              ..principalName = s['principalName'] ?? ''
              ..periodsPerDay = s['periodsPerDay']
              ..daysPerWeek = s['daysPerWeek']
              ..exportPageSize = s['exportPageSize'] ?? 'A4'
              ..exportOrientation = s['exportOrientation'] ?? 'Landscape'
              ..exportAutoScale = s['exportAutoScale'] ?? true
              ..customPageWidth = (s['customPageWidth'] as num?)?.toDouble()
              ..customPageHeight = (s['customPageHeight'] as num?)?.toDouble())
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
              ..unavailableDays = List<int>.from(t['unavailableDays'] ?? [])
              ..allowedPeriods = List<int>.from(t['allowedPeriods'] ?? []))
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
              ..allowedPeriods = List<int>.from(s['allowedPeriods'] ?? [])
              ..consecutiveness =
                  subjectConsecutivenessFromStorage(s['consecutiveness']))
            .toList();
        await _isar.subjects.putAll(newSubjects);
        for (final s in newSubjects) {
          subjectMap[s.id] = s;
        }
      }

      final Map<int, Classroom> classroomMap = {};
      if (data.containsKey('classrooms')) {
        final List<dynamic> classroomsList = data['classrooms'];
        final newClassrooms = classroomsList.map((c) {
          final rawWeeklyOverride = c['weeklyLessonsOverride'];
          final rawDailyOverride = c['dailyPeriodsOverride'];
          return Classroom()
            ..id = c['id']
            ..name = c['name']
            ..grade = c['grade']
            ..weeklyLessonsOverride =
                rawWeeklyOverride is num ? rawWeeklyOverride.toInt() : null
            ..dailyPeriodsOverride = rawDailyOverride is List
                ? rawDailyOverride
                    .whereType<num>()
                    .map((e) => e.toInt())
                    .toList()
                : null;
        }).toList();
        await _isar.classrooms.putAll(newClassrooms);
        for (final c in newClassrooms) {
          classroomMap[c.id] = c;
        }
      }

      // قيود المواد: مقطع اختياري حتى تبقى النسخ القديمة (التي لا تحتويه)
      // قابلة للاستيراد، فتُترك المجموعة فارغة كما كانت النسخة نفسها.
      if (data.containsKey('subjectConstraints')) {
        final List<dynamic> constraintsList = data['subjectConstraints'];
        final newConstraints = constraintsList
            .map((c) => SubjectConstraint()
              ..id = c['id']
              ..grade = c['grade']
              ..subjectName = c['subjectName']
              ..maxPeriodsPerDay = c['maxPeriodsPerDay'])
            .toList();
        await _isar.subjectConstraints.putAll(newConstraints);
      }

      if (data.containsKey('lessons')) {
        final List<dynamic> lessonsList = data['lessons'];
        final newLessons = lessonsList
            .map((l) => Lesson()
              ..id = l['id']
              ..dayIndex = l['dayIndex']
              ..periodIndex = l['periodIndex']
              ..isPinned = l['isPinned'] == true)
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
