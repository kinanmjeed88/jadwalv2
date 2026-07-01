import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/providers/timetable_provider.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    'state = AsyncValue.data(await isar.lessons.where().findAll());\n  }\n\n  Future<void> deleteAssignment',
    'state = AsyncValue.data(await isar.lessons.where().findAll());\n    return (true, null);\n  }\n\n  Future<void> deleteAssignment'
  );

  file.writeAsStringSync(content);
}
