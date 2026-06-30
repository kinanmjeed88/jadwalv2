import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll("gradesPerPage = 3;", "");
  content = content.replaceAll("gradesPerPage = 2;", "");

  file.writeAsStringSync(content);
}
