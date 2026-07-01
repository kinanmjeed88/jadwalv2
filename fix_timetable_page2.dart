import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/pages/timetable_page.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '''final teachers = await isar.teachers.where().findAll();''',
    '''final teachers = await isar.collection<Teacher>().where().findAll();'''
  );

  content = content.replaceFirst(
    "import '../../../../core/models/classroom.dart';",
    "import '../../../../core/models/classroom.dart';\nimport '../../../../core/models/teacher.dart';"
  );

  file.writeAsStringSync(content);
}
