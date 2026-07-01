import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/providers/timetable_provider.dart');
  var content = file.readAsStringSync();

  // Replace the entire swapLessons block and append moveLessonToEmpty
  var lines = content.split('\n');
  int startIdx = lines.indexWhere((l) => l.contains('Future<(bool, String?)> swapLessons('));

  if (startIdx != -1) {
    // Delete till end of file
    lines.removeRange(startIdx, lines.length);
  }

  // Append new methods
  lines.add('''
  Future<void> togglePin(Lesson lesson) async {
    final isar = await ref.read(isarDatabaseProvider.future);
    isar.writeTxnSync(() {
      lesson.isPinned = !lesson.isPinned;
      isar.lessons.putSync(lesson);
    });
    state = AsyncValue.data(await isar.lessons.where().findAll());
  }

  Future<(bool, String?)> moveLessonToEmpty(Lesson lesson, int newDay, int newPeriod) async {
    if (lesson.isPinned) return (false, "لا يمكن تحريك درس مقفل");

    final isar = await ref.read(isarDatabaseProvider.future);
    final allLessons = await isar.lessons.where().findAll();

    // Check teacher conflict
    bool teacherConflict = allLessons.any((l) =>
        l.id != lesson.id &&
        l.teacher.value?.id == lesson.teacher.value?.id &&
        l.dayIndex == newDay &&
        l.periodIndex == newPeriod);

    if (teacherConflict) return (false, "تعارض للمدرس في الوقت الجديد");

    // Check classroom conflict
    bool classroomConflict = allLessons.any((l) =>
        l.id != lesson.id &&
        l.classroom.value?.id == lesson.classroom.value?.id &&
        l.dayIndex == newDay &&
        l.periodIndex == newPeriod);

    if (classroomConflict) return (false, "تعارض للصف في الوقت الجديد");

    // Check teacher daily limit (if moving to a new day)
    if (lesson.dayIndex != newDay) {
      int teacherLessonsNewDay = allLessons.where((l) =>
          l.id != lesson.id &&
          l.teacher.value?.id == lesson.teacher.value?.id &&
          l.dayIndex == newDay).length;

      if (lesson.teacher.value != null && teacherLessonsNewDay >= lesson.teacher.value!.maxLessonsPerDay) {
        return (false, "تجاوز الحد الأقصى للحصص اليومية للمدرس");
      }
    }

    // Check teacher day off constraint
    if (lesson.teacher.value?.unavailableDays.contains(newDay) ?? false) {
      return (false, "المدرس مفرغ في هذا اليوم");
    }

    // Check subject constraint (allowed periods)
    if (lesson.subject.value != null && lesson.subject.value!.allowedPeriods.isNotEmpty && !lesson.subject.value!.allowedPeriods.contains(newPeriod)) {
      return (false, "هذه المادة غير مسموح بها في هذه الحصة");
    }

    isar.writeTxnSync(() {
      lesson.dayIndex = newDay;
      lesson.periodIndex = newPeriod;
      isar.lessons.putSync(lesson);
    });

    state = AsyncValue.data(await isar.lessons.where().findAll());
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
        "المدرس (\${lesson1.teacher.value?.name}) مفرغ في هذا اليوم"
      );
    }

    if (lesson2.teacher.value?.unavailableDays.contains(lesson1.dayIndex) ??
        false) {
      return (
        false,
        "المدرس (\${lesson2.teacher.value?.name}) مفرغ في هذا اليوم"
      );
    }

    // Check max lessons per day if they change days
    if (lesson1.dayIndex != lesson2.dayIndex) {
      if (lesson1.teacher.value != null) {
        int l1TeacherLessonsNewDay = allLessons.where((l) =>
            l.id != lesson1.id && l.id != lesson2.id &&
            l.teacher.value?.id == lesson1.teacher.value?.id &&
            l.dayIndex == lesson2.dayIndex).length;
        if (l1TeacherLessonsNewDay >= lesson1.teacher.value!.maxLessonsPerDay) {
          return (false, "تجاوز الحد الأقصى للحصص اليومية للمدرس الأول");
        }
      }

      if (lesson2.teacher.value != null) {
        int l2TeacherLessonsNewDay = allLessons.where((l) =>
            l.id != lesson1.id && l.id != lesson2.id &&
            l.teacher.value?.id == lesson2.teacher.value?.id &&
            l.dayIndex == lesson1.dayIndex).length;
        if (l2TeacherLessonsNewDay >= lesson2.teacher.value!.maxLessonsPerDay) {
          return (false, "تجاوز الحد الأقصى للحصص اليومية للمدرس الثاني");
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

    state = AsyncValue.data(await isar.lessons.where().findAll());
    return (true, null);
  }
}
''');

  file.writeAsStringSync(lines.join('\n'));
}
