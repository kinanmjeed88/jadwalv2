import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/utils/period_mapper.dart';

class PdfExportUseCase {
  /// Generates a PDF document for the timetables grouped by grade.
  /// Handles Arabic text (RTL) and splits pages if a grade has too many classrooms.
  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, AppSettings settings) async {
    final doc = pw.Document();

    // Load Arabic Font (Cairo or Amiri from Google Fonts via Printing)
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontData);

    // Group classrooms by Grade
    final classroomsByGrade = <String, List<Classroom>>{};
    for (var c in classrooms) {
      classroomsByGrade.putIfAbsent(c.grade, () => []).add(c);
    }

    PdfPageFormat format;
    switch (settings.exportPageSize) {
      case 'A3':
        format = PdfPageFormat.a3;
        break;
      case 'A4':
      default:
        format = PdfPageFormat.a4;
        break;
    }
    if (settings.exportOrientation == 'Landscape') {
      format = format.landscape;
    } else {
      format = format.portrait;
    }

    // Scale factor to adjust fonts slightly based on page size and periods
    final bool autoScale = settings.exportAutoScale;

    final maxClassroomsPerPage =
        settings.exportOrientation == 'Landscape' ? 4 : 3;

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
            pageFormat: format,
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(
              base: font,
              bold: fontBold,
            ),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Theme(
                  data: pw.ThemeData.withFont(
                    base: font,
                    bold: fontBold,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                          'جدول الدروس الأسبوعي - $grade${i > 0 ? ' (تابع)' : ''}',
                          style: pw.TextStyle(fontSize: 24, font: fontBold),
                          textDirection: pw.TextDirection.rtl),
                      pw.SizedBox(height: 20),
                      ...chunk.map((c) => _buildClassroomTable(
                          c, lessons, settings, font, fontBold, autoScale, format)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return doc.save();
  }

  pw.Widget _buildClassroomTable(
      Classroom classroom,
      List<Lesson> allLessons,
      AppSettings settings,
      pw.Font font,
      pw.Font fontBold,
      bool autoScale,
      PdfPageFormat format) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    // Auto-scale fonts based on the page width and number of periods
    double baseFontSize = format.width > 500 ? 12.0 : 10.0;
    if (autoScale) {
      if (periodsPerDay > 7) baseFontSize -= 2.0;
      if (displayDays.length > 5) baseFontSize -= 1.0;
      baseFontSize -= 1.0; // Extra compression to fit A to D columns
    }

    // Use FlexColumnWidth for equal column widths to fill space dynamically
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FlexColumnWidth(1.2),
      for (int i = 1; i <= displayDays.length; i++)
        i: const pw.FlexColumnWidth(1),
    };

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
                      font: fontBold,
                      fontWeight: pw.FontWeight.bold),
                  textDirection: pw.TextDirection.rtl),
              pw.SizedBox(height: 10),
              pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: columnWidths,
                  children: [
                    // Header row
                    pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Text('الدرس / اليوم',
                                  textAlign: pw.TextAlign.center,
                                  textDirection: pw.TextDirection.rtl,
                                  style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: baseFontSize,
                                      fontWeight: pw.FontWeight.bold))),
                          for (int d = 0; d < displayDays.length; d++)
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(displayDays[d],
                                    textAlign: pw.TextAlign.center,
                                    textDirection: pw.TextDirection.rtl,
                                    style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: baseFontSize,
                                        fontWeight: pw.FontWeight.bold))),
                        ]),
                    // Data rows
                    for (int p = 0; p < periodsPerDay; p++)
                      pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(PeriodMapper.toArabicName(p),
                                textAlign: pw.TextAlign.center,
                                textDirection: pw.TextDirection.rtl,
                                style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: baseFontSize,
                                    fontWeight: pw.FontWeight.bold))),
                        for (int d = 0; d < displayDays.length; d++)
                          _buildCell(classLessons, d, p, font, fontBold, baseFontSize),
                      ])
                  ])
            ]));
  }

  pw.Widget _buildCell(List<Lesson> classLessons, int dayIndex, int periodIndex,
      pw.Font font, pw.Font fontBold, double baseFontSize) {
    final lesson = classLessons
        .where((l) => l.dayIndex == dayIndex && l.periodIndex == periodIndex)
        .firstOrNull;

    if (lesson == null) {
      return pw.Padding(
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text('',
              style: pw.TextStyle(font: font, fontSize: baseFontSize)));
    }

    return pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(lesson.subject.value?.name ?? '',
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize - 1,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text(lesson.teacher.value?.name ?? '',
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                      font: font,
                      fontSize: baseFontSize - 3,
                      color: PdfColors.grey700)),
            ]));
  }
}
