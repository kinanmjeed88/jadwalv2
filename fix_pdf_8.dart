import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll("settings.schoolName != null && settings.schoolName!.isNotEmpty ? 'المدرسة: \${settings.schoolName}' : 'المدرسة: '", "'المدرسة: \${settings.schoolName}'");
  content = content.replaceAll("settings.principalName != null && settings.principalName!.isNotEmpty ? 'مدير المدرسة / \${settings.principalName}' : 'مدير المدرسة / '", "'مدير المدرسة / \${settings.principalName}'");

  file.writeAsStringSync(content);
}
