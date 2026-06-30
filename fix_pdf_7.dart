import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll(r"                            \1,", "                            settings.schoolName,");
  content = content.replaceAll(r"                              \1,", "                              'جدول الدروس الأسبوعي',");
  content = content.replaceAll(r"                              \1}'),", "                              'العام الدراسي: \${getAcademicYear()}',");
  content = content.replaceAll(r"                                \1,", "                                'توقيع المدير',");
  content = content.replaceAll(r"                            \1},", "                            'مدير المدرسة / \${settings.principalName}',");

  file.writeAsStringSync(content);
}
