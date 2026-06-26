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

      // Clear existing schedule assignments (or you might want to create a new pool)
      final existingLessons = await isar.lessons.where().findAll();
      // For this example, we assume `existingLessons` are the requirements.
      // If none exist, we would normally build them from Subject/Classroom relationships.
      // To keep it simple, we just pass the current list and let the generator assign day/period.
      for (var l in existingLessons) {
        l.dayIndex = null;
        l.periodIndex = null;
      }

      final generator = TimetableGenerator(
        teachers: teachers,
        subjects: subjects,
        classrooms: classrooms,
        settings: settings,
        existingLessons: existingLessons,
      );

      final generatedLessons = generator.generate();

      // Save to Isar
      await isar.writeTxn(() async {
        await isar.lessons.putAll(generatedLessons);
        for (var lesson in generatedLessons) {
          await lesson.teacher.save();
          await lesson.subject.save();
          await lesson.classroom.save();
        }
      });

      state = AsyncValue.data(generatedLessons);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> swapLessons(Lesson lesson1, Lesson lesson2) async {
    // Validate swap constraints
    if (lesson1.dayIndex == null ||
        lesson1.periodIndex == null ||
        lesson2.dayIndex == null ||
        lesson2.periodIndex == null) {
      return false;
    }

    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();

    // Check if swap causes teacher conflict
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
      return false; // Swap invalid
    }

    // Perform swap
    await isar.writeTxn(() async {
      final tempDay = lesson1.dayIndex;
      final tempPeriod = lesson1.periodIndex;

      lesson1.dayIndex = lesson2.dayIndex;
      lesson1.periodIndex = lesson2.periodIndex;

      lesson2.dayIndex = tempDay;
      lesson2.periodIndex = tempPeriod;

      await isar.lessons.putAll([lesson1, lesson2]);
    });

    state = AsyncValue.data(await isar.lessons.where().findAll());
    return true;
  }
}
