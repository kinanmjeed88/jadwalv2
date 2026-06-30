import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll(RegExp(r'_shape\(([^)]+)\)'), r'\1');

  file.writeAsStringSync(content);
}
