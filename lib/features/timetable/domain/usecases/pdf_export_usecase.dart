import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';

class PdfExportUseCase {
  /// Generates a PDF document for the timetables grouped by grade.
  /// Handles Arabic text (RTL) and splits pages if a grade has too many classrooms.
  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, int periodsPerDay) async {
    final doc = pw.Document();

    // Load Arabic Font (Cairo)
    // We need to fetch it from Google Fonts via Printing, or include a local TTF.
    // Here we'll use a local fallback or fetching if possible. For robustness, we will fetch Cairo from Google Fonts using `Printing`.
    final font = await PdfGoogleFonts.cairoRegular();

    // Group classrooms by Grade
    final classroomsByGrade = <String, List<Classroom>>{};
    for (var c in classrooms) {
      classroomsByGrade.putIfAbsent(c.grade, () => []).add(c);
    }

    final maxClassroomsPerPage = 4;

    for (var grade in classroomsByGrade.keys) {
      final gradeClassrooms = classroomsByGrade[grade]!;

      // Split into chunks of maxClassroomsPerPage
      for (int i = 0; i < gradeClassrooms.length; i += maxClassroomsPerPage) {
        final chunk = gradeClassrooms.sublist(
            i,
            i + maxClassroomsPerPage > gradeClassrooms.length
                ? gradeClassrooms.length
                : i + maxClassroomsPerPage);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(
              base: font,
            ),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                      'جدول الحصص الأسبوعي - $grade ${i > 0 ? '(تابع)' : ''}',
                      style: pw.TextStyle(fontSize: 24, font: font)),
                  pw.SizedBox(height: 20),
                  ...chunk
                      .map((c) =>
                          _buildClassroomTable(c, lessons, periodsPerDay, font))
                      .toList(),
                ],
              );
            },
          ),
        );
      }
    }

    return doc.save();
  }

  pw.Widget _buildClassroomTable(Classroom classroom, List<Lesson> allLessons,
      int periodsPerDay, pw.Font font) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

    // Filter lessons for this classroom
    final classLessons = allLessons
        .where((l) => l.classroom.value?.id == classroom.id && !l.isUnassigned)
        .toList();

    return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('الشعبة: ${classroom.name}',
                  style: pw.TextStyle(
                      fontSize: 18,
                      font: font,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(border: pw.TableBorder.all(), children: [
                // Header row
                pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('اليوم / الحصة',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: font))),
                      for (int p = 0; p < periodsPerDay; p++)
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${p + 1}',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(font: font))),
                    ]),
                // Data rows
                for (int d = 0; d < days.length; d++)
                  pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(days[d],
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font))),
                    for (int p = 0; p < periodsPerDay; p++)
                      _buildCell(classLessons, d, p, font),
                  ])
              ])
            ]));
  }

  pw.Widget _buildCell(
      List<Lesson> classLessons, int dayIndex, int periodIndex, pw.Font font) {
    final lesson = classLessons
        .where((l) => l.dayIndex == dayIndex && l.periodIndex == periodIndex)
        .firstOrNull;

    if (lesson == null) {
      return pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text('', style: pw.TextStyle(font: font)));
    }

    return pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(lesson.subject.value?.name ?? '',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text(lesson.teacher.value?.name ?? '',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      font: font, fontSize: 8, color: PdfColors.grey700)),
            ]));
  }
}
