import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/providers/timetable_provider.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    'Future<void> assignLessonsToPool(',
    'Future<(bool, String?)> assignLessonsToPool('
  );

  content = content.replaceFirst(
    'final newLessons = <Lesson>[];',
    '''final allLessons = await isar.lessons.where().findAll();

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

    final newLessons = <Lesson>[];'''
  );

  var lines = content.split('\n');
  int targetLine = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('Future<void> deleteAssignment(int classroomId, int subjectId) async {')) {
      targetLine = i - 2;
      break;
    }
  }

  if (targetLine != -1 && lines[targetLine].contains('state = AsyncValue.data(await isar.lessons.where().findAll());')) {
    lines.insert(targetLine + 1, '    return (true, null);');
  }

  file.writeAsStringSync(lines.join('\n'));
}
