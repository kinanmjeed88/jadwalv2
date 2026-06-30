import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll(
    "pw.Expanded(\n                      child: _buildMasterTable(chunkClassrooms, lessons,\n                          settings, font, format, maxCapacity),\n                    ),",
    "pw.Expanded(\n                      child: pw.LayoutBuilder(\n                        builder: (pw.Context context, pw.BoxConstraints? constraints) {\n                          return _buildMasterTable(chunkClassrooms, lessons,\n                              settings, font, constraints, maxCapacity);\n                        },\n                      ),\n                    ),"
  );

  content = content.replaceAll(
    "pw.Widget _buildMasterTable(\n      List<Classroom> classrooms,\n      List<Lesson> allLessons,\n      AppSettings settings,\n      pw.Font font,\n      PdfPageFormat format,\n      int maxCapacity)",
    "pw.Widget _buildMasterTable(\n      List<Classroom> classrooms,\n      List<Lesson> allLessons,\n      AppSettings settings,\n      pw.Font font,\n      pw.BoxConstraints? constraints,\n      int maxCapacity)"
  );

  content = content.replaceAll(
    "final double availableWidth = format.availableWidth - 40;",
    "final double availableWidth = constraints?.maxWidth ?? 500.0;"
  );

  file.writeAsStringSync(content);
}
