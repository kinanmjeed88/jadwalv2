import 'package:isar/isar.dart';
import 'dart:isolate';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/subject_constraint.dart';
import '../../domain/usecases/timetable_generator.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/subject_constraint_entity.dart';

part 'timetable_provider.g.dart';

@riverpod
class TimetableNotifier extends _$TimetableNotifier {
  @override
  AsyncValue<List<Lesson>> build() {
    _loadLessons();
    return const AsyncValue.loading();
  }

  Future<void> _loadLessons() async {
    try {
      final isar = await ref.read(isarDatabaseProvider.future);
      final lessons = await isar.lessons.where().findAll();

      for (var lesson in lessons) {
        lesson.classroom.loadSync();
        lesson.subject.loadSync();
        lesson.teacher.loadSync();
      }

      state = AsyncValue.data(lessons);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<(bool, String?)> assignLessonsToPool(
      Classroom classroom, Subject subject, Teacher teacher) async {
    final isar = await ref.read(isarDatabaseProvider.future);

    final newLessons = <Lesson>[];
    for (int i = 0; i < subject.lessonsPerWeek; i++) {
      final lesson = Lesson()
        ..classroom.value = classroom
        ..subject.value = subject
        ..teacher.value = teacher;
      newLessons.add(lesson);
    }

    isar.writeTxnSync(() {
      isar.lessons.putAllSync(newLessons);
      for (var l in newLessons) {
        l.classroom.saveSync();
        l.subject.saveSync();
        l.teacher.saveSync();
      }
    });

    _loadLessons();
    return (true, null);
  }

  Future<void> deleteAssignment(int classroomId, int subjectId) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();
    final toDelete = allLessons.where((l) => l.classroom.value?.id == classroomId && l.subject.value?.id == subjectId).toList();

    isar.writeTxnSync(() {
      isar.lessons.deleteAllSync(toDelete.map((e) => e.id).toList());
    });

    _loadLessons();
  }

  Future<void> updateAssignment(int classroomId, int subjectId, Teacher newTeacher) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();
    final toUpdate = allLessons.where((l) => l.classroom.value?.id == classroomId && l.subject.value?.id == subjectId).toList();

    isar.writeTxnSync(() {
      for (var lesson in toUpdate) {
        lesson.teacher.value = newTeacher;
        isar.lessons.putSync(lesson);
        lesson.teacher.saveSync();
      }
    });

    _loadLessons();
  }

  Future<void> clearTimetable() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    await isar.writeTxn(() async {
      final allLessons = await isar.lessons.where().findAll();
      for (var lesson in allLessons) {
        if (!lesson.isPinned) {
          lesson.dayIndex = null;
          lesson.periodIndex = null;
          await isar.lessons.put(lesson);
        }
      }
    });
    _loadLessons();
  }

  Future<void> togglePin(Lesson lesson) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    await isar.writeTxn(() async {
      lesson.isPinned = !lesson.isPinned;
      await isar.lessons.put(lesson);
    });
    _loadLessons();
  }

  Future<void> generateTimetable() async {
    state = const AsyncValue.loading();
    try {
      final isar = await ref.read(isarDatabaseProvider.future);
      final teachers = await isar.teachers.where().findAll();
      final subjects = await isar.subjects.where().findAll();
      final classrooms = await isar.classrooms.where().findAll();
      final settings = await isar.appSettings.where().findFirst() ?? AppSettings();
      final existingLessons = await isar.lessons.where().findAll();
      final subjectConstraints = await isar.subjectConstraints.where().findAll();

      for (var lesson in existingLessons) {
        lesson.classroom.loadSync();
        lesson.subject.loadSync();
        lesson.teacher.loadSync();
      }

      // Convert Isar Models to pure Entities for the domain layer (Isolate safe)
      final teacherEntitiesMap = {for (var t in teachers) t.id: TeacherEntity.fromIsar(t)};
      final teacherEntities = teacherEntitiesMap.values.toList();

      final subjectEntitiesMap = {for (var s in subjects) s.id: SubjectEntity.fromIsar(s)};
      final subjectEntities = subjectEntitiesMap.values.toList();

      final classroomEntitiesMap = {for (var c in classrooms) c.id: ClassroomEntity.fromIsar(c)};
      final classroomEntities = classroomEntitiesMap.values.toList();

      final settingsEntity = AppSettingsEntity.fromIsar(settings);

      final lessonEntities = existingLessons.map((l) => LessonEntity.fromIsar(
        l,
        teacherEntitiesMap,
        subjectEntitiesMap,
        classroomEntitiesMap,
      )).toList();

      final subjectConstraintEntities = subjectConstraints.map((sc) => SubjectConstraintEntity.fromIsar(sc)).toList();

      final payload = GenerationPayload(
        teachers: teacherEntities,
        subjects: subjectEntities,
        classrooms: classroomEntities,
        settings: settingsEntity,
        existingLessons: lessonEntities,
        subjectConstraints: subjectConstraintEntities,
      );

      // Run generation in a separate isolate
      final generatedLessonEntities = await _spawnIsolateAndGenerate(payload);

      // Save generated state back to database
      await isar.writeTxn(() async {
        for (var entity in generatedLessonEntities) {
          if (!entity.isPinned) {
             var isarLesson = existingLessons.firstWhere((l) => l.id == entity.id);
             isarLesson.dayIndex = entity.dayIndex;
             isarLesson.periodIndex = entity.periodIndex;
             await isar.lessons.put(isarLesson);
          }
        }
      });

      // Reload lessons with all links to update the UI correctly
      final newLessons = await isar.lessons.where().findAll();
      for (var lesson in newLessons) {
        lesson.classroom.loadSync();
        lesson.subject.loadSync();
        lesson.teacher.loadSync();
      }
      state = AsyncValue.data(newLessons);
    } on TimetableGenerationException catch (e) {
      // Restore valid data state to avoid generic error widget
      final isar = await ref.read(isarDatabaseProvider.future);
      final lessons = await isar.lessons.where().findAll();
      for (var lesson in lessons) {
        lesson.classroom.loadSync();
        lesson.subject.loadSync();
        lesson.teacher.loadSync();
      }
      state = AsyncValue.data(lessons);

      // Rethrow to the UI try-catch block
      throw e; // Dart 3 throws correctly
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<(bool, String?)> moveLessonToEmpty(Lesson lesson, int newDay, int newPeriod) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();

    // Check teacher conflict
    bool hasTeacherConflict = allLessons.any((l) =>
        l.id != lesson.id &&
        l.teacher.value?.id == lesson.teacher.value?.id &&
        l.dayIndex == newDay &&
        l.periodIndex == newPeriod);

    if (lesson.teacher.value != null && hasTeacherConflict) {
      return (false, "لا يمكن النقل: الأستاذ لديه حصة أخرى في هذا الوقت");
    }

    // Check subject max periods per day
    if (lesson.subject.value != null && lesson.classroom.value != null) {
      final constraints = await isar.subjectConstraints.where().findAll();
      int maxAllowed = 1;
      for (var constraint in constraints) {
        if (constraint.grade == lesson.classroom.value!.grade && constraint.subjectName == lesson.subject.value!.name) {
          maxAllowed = constraint.maxPeriodsPerDay;
          break;
        }
      }

      int subjectCountOnNewDay = allLessons.where((l) =>
          l.id != lesson.id &&
          l.classroom.value?.id == lesson.classroom.value?.id &&
          l.subject.value?.id == lesson.subject.value?.id &&
          l.dayIndex == newDay).length;

      if (subjectCountOnNewDay >= maxAllowed) {
        return (false, "لا يمكن النقل: تجاوز الحد الأقصى ($maxAllowed حصص) لمادة (${lesson.subject.value?.name}) في هذا اليوم");
      }
    }

    // Check teacher daily limit (if moving to a new day)
    if (lesson.dayIndex != newDay && lesson.teacher.value != null) {
      int teacherLessonsNewDay = allLessons.where((l) =>
          l.id != lesson.id &&
          l.teacher.value?.id == lesson.teacher.value?.id &&
          l.dayIndex == newDay).length;

      if (lesson.teacher.value != null && teacherLessonsNewDay >= lesson.teacher.value!.maxLessonsPerDay) {
        return (false, "لا يمكن النقل: تجاوز الحد الأقصى للحصص اليومية للأستاذ (${lesson.teacher.value?.name})");
      }
    }

    // Check teacher day off constraint
    if (lesson.teacher.value?.unavailableDays.contains(newDay) ?? false) {
      return (false, "لا يمكن النقل: الأستاذ مفرغ في هذا اليوم ولا يمكن وضع حصة له");
    }

    // Check subject constraint (allowed periods)
    if (lesson.subject.value != null && lesson.subject.value!.allowedPeriods.isNotEmpty && !lesson.subject.value!.allowedPeriods.contains(newPeriod)) {
      return (false, "لا يمكن النقل: هذه المادة غير مسموح بتدريسها في الحصة (${newPeriod + 1}) بناءً على إعدادات المادة");
    }

    isar.writeTxnSync(() {
      lesson.dayIndex = newDay;
      lesson.periodIndex = newPeriod;
      isar.lessons.putSync(lesson);
    });

    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    state = AsyncValue.data(lessons);
    return (true, null);
  }

  Future<(bool, String?)> swapLessons(Lesson lesson1, Lesson lesson2) async {
    // Validate swap constraints
    if (lesson1.dayIndex == null ||
        lesson1.periodIndex == null ||
        lesson2.dayIndex == null ||
        lesson2.periodIndex == null) {
      return (false, "لا يمكن تبديل دروس غير مجدولة");
    }

    if (lesson1.isPinned || lesson2.isPinned) {
      return (false, "لا يمكن تبديل دروس مقفلة");
    }

    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();

    // Check teacher conflict
    bool lesson1TeacherConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        lesson1.teacher.value != null &&
        l.teacher.value != null &&
        l.teacher.value?.id == lesson1.teacher.value?.id &&
        l.dayIndex == lesson2.dayIndex &&
        l.periodIndex == lesson2.periodIndex);

    bool lesson2TeacherConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        lesson2.teacher.value != null &&
        l.teacher.value != null &&
        l.teacher.value?.id == lesson2.teacher.value?.id &&
        l.dayIndex == lesson1.dayIndex &&
        l.periodIndex == lesson1.periodIndex);

    if (lesson1TeacherConflict || lesson2TeacherConflict) {
      return (false, "لا يمكن التبديل: أحد الأساتذة لديه حصة أخرى في نفس الوقت المقترح");
    }

    // Check classroom conflict
    bool lesson1ClassroomConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        l.classroom.value?.id == lesson1.classroom.value?.id &&
        l.dayIndex == lesson2.dayIndex &&
        l.periodIndex == lesson2.periodIndex);

    bool lesson2ClassroomConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        l.classroom.value?.id == lesson2.classroom.value?.id &&
        l.dayIndex == lesson1.dayIndex &&
        l.periodIndex == lesson1.periodIndex);

    if (lesson1ClassroomConflict || lesson2ClassroomConflict) {
      return (false, "لا يمكن التبديل: أحد الصفوف مشغول بالفعل في الحصة المقترحة");
    }

    // Check subject max periods per day for Swap
    if (lesson1.dayIndex != lesson2.dayIndex) {
      final constraints = await isar.subjectConstraints.where().findAll();

      if (lesson1.subject.value != null && lesson1.classroom.value != null) {
        int maxAllowed = 1;
        for (var constraint in constraints) {
          if (constraint.grade == lesson1.classroom.value!.grade && constraint.subjectName == lesson1.subject.value!.name) {
            maxAllowed = constraint.maxPeriodsPerDay;
            break;
          }
        }
        int l1SubjectCountNewDay = allLessons.where((l) =>
            l.id != lesson1.id && l.id != lesson2.id &&
            l.classroom.value?.id == lesson1.classroom.value?.id &&
            l.subject.value?.id == lesson1.subject.value?.id &&
            l.dayIndex == lesson2.dayIndex).length;
        if (l1SubjectCountNewDay >= maxAllowed) {
          return (false, "لا يمكن التبديل: سيؤدي ذلك لتجاوز الحد الأقصى ($maxAllowed حصص) لمادة (${lesson1.subject.value?.name}) للصف في اليوم المقترح");
        }
      }

      if (lesson2.subject.value != null && lesson2.classroom.value != null) {
        int maxAllowed = 1;
        for (var constraint in constraints) {
          if (constraint.grade == lesson2.classroom.value!.grade && constraint.subjectName == lesson2.subject.value!.name) {
            maxAllowed = constraint.maxPeriodsPerDay;
            break;
          }
        }
        int l2SubjectCountNewDay = allLessons.where((l) =>
            l.id != lesson1.id && l.id != lesson2.id &&
            l.classroom.value?.id == lesson2.classroom.value?.id &&
            l.subject.value?.id == lesson2.subject.value?.id &&
            l.dayIndex == lesson1.dayIndex).length;
        if (l2SubjectCountNewDay >= maxAllowed) {
           return (false, "لا يمكن التبديل: سيؤدي ذلك لتجاوز الحد الأقصى ($maxAllowed حصص) لمادة (${lesson2.subject.value?.name}) للصف في اليوم المقترح");
        }
      }
    }

    // Check teacher day off constraint
    if (lesson1.teacher.value?.unavailableDays.contains(lesson2.dayIndex) ??
        false) {
      return (
        false,
        "لا يمكن التبديل: الأستاذ (${lesson1.teacher.value?.name}) مفرغ في اليوم المقترح"
      );
    }

    if (lesson2.teacher.value?.unavailableDays.contains(lesson1.dayIndex) ??
        false) {
      return (
        false,
        "لا يمكن التبديل: الأستاذ (${lesson2.teacher.value?.name}) مفرغ في اليوم المقترح"
      );
    }

    // Check max lessons per day if they change days
    if (lesson1.dayIndex != lesson2.dayIndex) {
      if (lesson1.teacher.value != null) {
        int l1TeacherLessonsNewDay = allLessons.where((l) =>
            l.id != lesson1.id && l.id != lesson2.id &&
            l.teacher.value?.id == lesson1.teacher.value?.id &&
            l.dayIndex == lesson2.dayIndex).length;
        if (lesson1.teacher.value != null && l1TeacherLessonsNewDay >= lesson1.teacher.value!.maxLessonsPerDay) {
          return (false, "لا يمكن التبديل: سيتم تجاوز الحد الأقصى للحصص اليومية للأستاذ (${lesson1.teacher.value?.name})");
        }
      }

      if (lesson2.teacher.value != null) {
        int l2TeacherLessonsNewDay = allLessons.where((l) =>
            l.id != lesson1.id && l.id != lesson2.id &&
            l.teacher.value?.id == lesson2.teacher.value?.id &&
            l.dayIndex == lesson1.dayIndex).length;
        if (lesson2.teacher.value != null && l2TeacherLessonsNewDay >= lesson2.teacher.value!.maxLessonsPerDay) {
          return (false, "لا يمكن التبديل: سيتم تجاوز الحد الأقصى للحصص اليومية للأستاذ (${lesson2.teacher.value?.name})");
        }
      }
    }

    // Perform swap
    isar.writeTxnSync(() {
      final tempDay = lesson1.dayIndex;
      final tempPeriod = lesson1.periodIndex;

      lesson1.dayIndex = lesson2.dayIndex;
      lesson1.periodIndex = lesson2.periodIndex;

      lesson2.dayIndex = tempDay;
      lesson2.periodIndex = tempPeriod;

      isar.lessons.putAllSync([lesson1, lesson2]);
    });

    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    state = AsyncValue.data(lessons);
    return (true, null);
  }
}

class GenerationPayload {
  final List<TeacherEntity> teachers;
  final List<SubjectEntity> subjects;
  final List<ClassroomEntity> classrooms;
  final AppSettingsEntity settings;
  final List<LessonEntity> existingLessons;
  final List<SubjectConstraintEntity> subjectConstraints;

  const GenerationPayload({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
    required this.subjectConstraints,
  });
}

Future<List<LessonEntity>> _spawnIsolateAndGenerate(GenerationPayload payload) async {
  // هذه الدالة موجودة في Top-Level، لذا لا يوجد هنا 'this' ولا 'isar' ليلتقطه الـ Closure!
  return await Isolate.run(() => _generateInIsolate(payload));
}

/// A top-level function that strictly accepts DTOs, isolating memory.
List<LessonEntity> _generateInIsolate(GenerationPayload payload) {
  final generator = TimetableGenerator(
    teachers: payload.teachers,
    subjects: payload.subjects,
    classrooms: payload.classrooms,
    settings: payload.settings,
    existingLessons: payload.existingLessons,
    subjectConstraints: payload.subjectConstraints,
  );
  return generator.generate();
}
