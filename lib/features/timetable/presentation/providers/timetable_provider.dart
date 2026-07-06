import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import 'dart:isolate';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/entities/lesson_entity.dart';
import '../../../../core/entities/teacher_entity.dart';
import '../../../../core/entities/subject_entity.dart';
import '../../../../core/entities/classroom_entity.dart';
import '../../../../core/entities/app_settings_entity.dart';

import '../../domain/usecases/timetable_generator.dart';
import '../../../../core/exceptions/unsolvable_timetable_exception.dart';

part 'timetable_provider.g.dart';

@riverpod
class TimetableNotifier extends _$TimetableNotifier {
  @override
  Future<List<Lesson>> build() async {
    final isar = await ref.watch(isarDatabaseProvider.future);
    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    return lessons;
  }

  Future<(bool, String?)> assignLessonsToPool(
      Classroom classroom, Subject subject, Teacher teacher) async {
    final isar = await ref.read(isarDatabaseProvider.future);

    final allLessons = await isar.lessons.where().findAll();

    // Check duplicate assignment
    bool duplicateAssignment = allLessons.any((l) =>
      l.classroom.value?.id == classroom.id &&
      l.subject.value?.id == subject.id);

    if (duplicateAssignment) {
      return (false, "تم إسناد هذه المادة لهذا الصف مسبقاً");
    }

    // Check capacity overload
    int teacherAssignedLessons = allLessons.where((l) => l.teacher.value?.id == teacher.id).length;
    if (teacherAssignedLessons + subject.lessonsPerWeek > teacher.maxLessonsPerWeek) {
      return (false, "لا يمكن الإسناد: سعة المدرس الأسبوعية لا تكفي");
    }

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

    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    state = AsyncValue.data(lessons);
    return (true, null);
  }

  Future<void> deleteAssignment(int classroomId, int subjectId) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();
    final toDelete = allLessons
        .where((l) =>
            l.classroom.value?.id == classroomId &&
            l.subject.value?.id == subjectId)
        .toList();

    isar.writeTxnSync(() {
      isar.lessons.deleteAllSync(toDelete.map((e) => e.id).toList());
    });
    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    state = AsyncValue.data(lessons);
  }

  Future<void> updateAssignment(
      int classroomId, int subjectId, Teacher newTeacher) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();
    final toUpdate = allLessons
        .where((l) =>
            l.classroom.value?.id == classroomId &&
            l.subject.value?.id == subjectId)
        .toList();

    isar.writeTxnSync(() {
      for (var lesson in toUpdate) {
        lesson.teacher.value = newTeacher;
        isar.lessons.putSync(lesson);
        lesson.teacher.saveSync();
      }
    });
    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    state = AsyncValue.data(lessons);
  }

  Future<void> generateTimetable() async {
    state = const AsyncValue.loading();

    try {
      final isar = await ref.read(isarDatabaseProvider.future);

      final teachers = await isar.teachers.where().findAll();
      final subjects = await isar.subjects.where().findAll();
      final classrooms = await isar.classrooms.where().findAll();
      final settingsList = await isar.appSettings.where().findAll();
      final settings = settingsList.isNotEmpty
          ? settingsList.first
          : (AppSettings()..periodsPerDay = 7);

      // Clear existing schedule assignments by resetting indexes
      final existingLessons = await isar.lessons.where().findAll();

      // Map Isar to DTOs
      final teachersMap = {for (var t in teachers) t.id: TeacherEntity.fromIsar(t)};
      final subjectsMap = {for (var s in subjects) s.id: SubjectEntity.fromIsar(s)};
      final classroomsMap = {for (var c in classrooms) c.id: ClassroomEntity.fromIsar(c)};

      final existingLessonsEntity = existingLessons
          .map((l) => LessonEntity.fromIsar(l, teachersMap, subjectsMap, classroomsMap))
          .toList();

      final settingsEntity = AppSettingsEntity.fromIsar(settings);

      final teachersEntityList = teachersMap.values.toList();
      final subjectsEntityList = subjectsMap.values.toList();
      final classroomsEntityList = classroomsMap.values.toList();

      // Create payload to avoid capturing anything from lexical scope
      final payload = GenerationPayload(
        teachers: teachersEntityList,
        subjects: subjectsEntityList,
        classrooms: classroomsEntityList,
        settings: settingsEntity,
        existingLessons: existingLessonsEntity,
      );

      // Run Generator in an Isolate using a top-level function to avoid capturing `this`
      final resultEntities = await _spawnIsolateAndGenerate(payload);

      // Map DTOs back to existingLessons
      for (var lessonDto in resultEntities) {
        final lesson = existingLessons.firstWhere((l) => l.id == lessonDto.id);
        lesson.dayIndex = lessonDto.dayIndex;
        lesson.periodIndex = lessonDto.periodIndex;
      }

      // Ensure that we save the entire modified pool (even those unplaced/unscheduled)
      // Since generator modifies existingLessons in-place and returns it.
      isar.writeTxnSync(() {
        isar.lessons.putAllSync(existingLessons);
        for (var lesson in existingLessons) {
          lesson.teacher.saveSync();
          lesson.subject.saveSync();
          lesson.classroom.saveSync();
        }
      });

      for (var lesson in existingLessons) {
        lesson.classroom.loadSync();
        lesson.subject.loadSync();
        lesson.teacher.loadSync();
      }
      state = AsyncValue.data(existingLessons);
    } on UnsolvableTimetableException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> togglePin(Lesson lesson) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    isar.writeTxnSync(() {
      lesson.isPinned = !lesson.isPinned;
      isar.lessons.putSync(lesson);
    });
    final lessons = await isar.lessons.where().findAll();
    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }
    state = AsyncValue.data(lessons);
  }

  Future<(bool, String?)> moveLessonToEmpty(Lesson lesson, int newDay, int newPeriod) async {
    if (lesson.isPinned) return (false, "لا يمكن تحريك درس مقفل");

    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();

    // Check teacher conflict
    bool teacherConflict = allLessons.any((l) =>
        l.id != lesson.id &&
        l.teacher.value != null && // null teacher won't conflict with another null
        lesson.teacher.value != null &&
        l.teacher.value?.id == lesson.teacher.value?.id &&
        l.dayIndex == newDay &&
        l.periodIndex == newPeriod);

    if (teacherConflict) {
      return (false, "لا يمكن النقل: الأستاذ (${lesson.teacher.value?.name ?? ''}) لديه حصة في نفس الوقت (${newPeriod + 1})");
    }

    // Check classroom conflict
    bool classroomConflict = allLessons.any((l) =>
        l.id != lesson.id &&
        l.classroom.value?.id == lesson.classroom.value?.id &&
        l.dayIndex == newDay &&
        l.periodIndex == newPeriod);

    if (classroomConflict) return (false, "لا يمكن النقل: الصف مشغول بالفعل في هذه الحصة");

    // Check same subject on same day
    bool subjectAlreadyOnDay = allLessons.any((l) =>
        l.id != lesson.id &&
        l.classroom.value?.id == lesson.classroom.value?.id &&
        l.subject.value?.id == lesson.subject.value?.id &&
        l.dayIndex == newDay);

    if (subjectAlreadyOnDay) return (false, "لا يمكن النقل: مادة (${lesson.subject.value?.name}) مقررة مسبقاً لهذا الصف في نفس اليوم");

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

    // Check same subject on same day for Swap
    bool l1SubjectConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        l.classroom.value?.id == lesson1.classroom.value?.id &&
        l.subject.value?.id == lesson1.subject.value?.id &&
        l.dayIndex == lesson2.dayIndex);

    bool l2SubjectConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        l.classroom.value?.id == lesson2.classroom.value?.id &&
        l.subject.value?.id == lesson2.subject.value?.id &&
        l.dayIndex == lesson1.dayIndex);

    if (l1SubjectConflict || l2SubjectConflict) {
      return (false, "لا يمكن التبديل: سيؤدي ذلك إلى تكرار نفس المادة للصف في نفس اليوم");
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

  const GenerationPayload({
    required this.teachers,
    required this.subjects,
    required this.classrooms,
    required this.settings,
    required this.existingLessons,
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
  );
  return generator.generate();
}
