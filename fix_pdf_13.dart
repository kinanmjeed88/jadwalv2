import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceFirst("final double availableWidth = constraints?.maxWidth ?? 500.0;", "final double availableWidth = format.availableWidth - 40;");

  file.writeAsStringSync(content);
}
