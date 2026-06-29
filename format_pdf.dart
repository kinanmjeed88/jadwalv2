import 'dart:io';

void main() async {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = await file.readAsString();

  content = content.replaceAll("import 'package:pdf/pdf.dart';",
    "import 'package:pdf/pdf.dart';\nimport 'package:arabic_reshaper/arabic_reshaper.dart';");

  await file.writeAsString(content);
}
