import 'dart:io';

void main() {
  var file = File('test/timetable_generator_test.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('package:timetable', 'package:jadwal_v2');
  file.writeAsStringSync(content);
}
