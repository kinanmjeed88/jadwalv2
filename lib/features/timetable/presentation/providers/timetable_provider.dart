import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/models/subject.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';
import '../../domain/usecases/timetable_generator.dart';

part 'timetable_provider.g.dart';

@riverpod
class TimetableNotifier extends _$TimetableNotifier {
  @override
  Future<List<Lesson>> build() async {
    final isar = await ref.watch(isarDatabaseProvider.future);
    return isar.lessons.where().findAll();
  }

  Future<void> assignLessonsToPool(
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

    state = AsyncValue.data(await isar.lessons.where().findAll());
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
    state = AsyncValue.data(await isar.lessons.where().findAll());
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
    state = AsyncValue.data(await isar.lessons.where().findAll());
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

      final generator = TimetableGenerator(
        teachers: teachers,
        subjects: subjects,
        classrooms: classrooms,
        settings: settings,
        existingLessons: existingLessons,
      );

      generator.generate();

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

      state = AsyncValue.data(existingLessons);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<(bool, String?)> swapLessons(Lesson lesson1, Lesson lesson2) async {
    // Validate swap constraints
    if (lesson1.dayIndex == null ||
        lesson1.periodIndex == null ||
        lesson2.dayIndex == null ||
        lesson2.periodIndex == null) {
      return (false, "لا يمكن تبديل دروس غير مجدولة");
    }

    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();

    // Check teacher conflict
    bool lesson1TeacherConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        l.teacher.value?.id == lesson1.teacher.value?.id &&
        l.dayIndex == lesson2.dayIndex &&
        l.periodIndex == lesson2.periodIndex);

    bool lesson2TeacherConflict = allLessons.any((l) =>
        l.id != lesson1.id &&
        l.id != lesson2.id &&
        l.teacher.value?.id == lesson2.teacher.value?.id &&
        l.dayIndex == lesson1.dayIndex &&
        l.periodIndex == lesson1.periodIndex);

    if (lesson1TeacherConflict || lesson2TeacherConflict) {
      return (false, "تعارض للمدرس في الوقت الجديد");
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
      return (false, "تعارض للصف في الوقت الجديد");
    }

    // Check teacher day off constraint
    if (lesson1.teacher.value?.unavailableDays.contains(lesson2.dayIndex) ??
        false) {
      return (
        false,
        "المدرس (${lesson1.teacher.value?.name}) مفرغ في هذا اليوم"
      );
    }

    if (lesson2.teacher.value?.unavailableDays.contains(lesson1.dayIndex) ??
        false) {
      return (
        false,
        "المدرس (${lesson2.teacher.value?.name}) مفرغ في هذا اليوم"
      );
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

    state = AsyncValue.data(await isar.lessons.where().findAll());
    return (true, null);
  }
}
