import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  content = content.replaceAll("import 'package:arabic_reshaper/arabic_reshaper.dart';", "");

  content = content.replaceAll(RegExp(r'\s*String _shape\(String text\) \{\s*if \(text\.isEmpty\) return text;\s*final reshaper = ArabicReshaper\(\);\s*return reshaper\.reshape\(text\);\s*\}'), '');
  content = content.replaceAll("assets/fonts/Cairo-Regular.ttf", "assets/fonts/Amiri-Regular.ttf");

  // Custom manual replace to not mess up syntax
  content = content.replaceAll("_shape('وزارة التربية')", "'وزارة التربية'");
  content = content.replaceAll("_shape('المديرية العامة للتربية')", "'المديرية العامة للتربية'");
  content = content.replaceAll("_shape('المدرسة: \${settings.schoolName}')", "settings.schoolName != null && settings.schoolName!.isNotEmpty ? 'المدرسة: \${settings.schoolName}' : 'المدرسة: '");
  content = content.replaceAll("_shape('جدول الدروس الأسبوعي')", "'جدول الدروس الأسبوعي'");
  content = content.replaceAll("_shape('العام الدراسي: \${getAcademicYear()}')", "'العام الدراسي: \${getAcademicYear()}'");
  content = content.replaceAll("_shape('توقيع المدير')", "'توقيع المدير'");
  content = content.replaceAll("_shape('مدير المدرسة / \${settings.principalName}')", "settings.principalName != null && settings.principalName!.isNotEmpty ? 'مدير المدرسة / \${settings.principalName}' : 'مدير المدرسة / '");
  content = content.replaceAll("_shape('اليوم')", "'اليوم'");
  content = content.replaceAll("_shape('الدرس')", "'الدرس'");
  content = content.replaceAll("_shape(c.name)", "c.name");
  content = content.replaceAll("_shape(displayDays[d])", "displayDays[d]");
  content = content.replaceAll("_shape(lesson.subject.value?.name ?? '')", "lesson.subject.value?.name ?? ''");
  content = content.replaceAll("_shape(lesson.teacher.value?.name ?? '')", "lesson.teacher.value?.name ?? ''");
  content = content.replaceAll("_shape(text)", "text");

  file.writeAsStringSync(content);
}
