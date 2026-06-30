import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll("int gradesPerPage = 2; // Default for A4 or Custom", "");

  file.writeAsStringSync(content);
}
