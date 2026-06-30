import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll(
    "builder: (pw.Context context, pw.BoxConstraints constraints) {",
    "builder: (pw.Context context, pw.BoxConstraints? constraints) {"
  );

  content = content.replaceAll(
    "pw.Widget _buildMasterTable(\n      List<Classroom> classrooms,\n      List<Lesson> allLessons,\n      AppSettings settings,\n      pw.Font font,\n      pw.BoxConstraints constraints,\n      int maxCapacity)",
    "pw.Widget _buildMasterTable(\n      List<Classroom> classrooms,\n      List<Lesson> allLessons,\n      AppSettings settings,\n      pw.Font font,\n      pw.BoxConstraints? constraints,\n      int maxCapacity)"
  );

  content = content.replaceAll(
    "final double availableWidth = constraints.maxWidth;",
    "final double availableWidth = constraints?.maxWidth ?? 500.0;"
  );

  file.writeAsStringSync(content);
}
