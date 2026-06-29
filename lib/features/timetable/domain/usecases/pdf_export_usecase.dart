import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

class PdfExportUseCase {
  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    // Group classrooms by Grade
    final classroomsByGrade = <String, List<Classroom>>{};
    // Sort classrooms by id to keep consistent order
    classrooms.sort((a, b) => a.id.compareTo(b.id));
    for (var c in classrooms) {
      classroomsByGrade.putIfAbsent(c.grade, () => []).add(c);
    }

    final List<String> gradeNames = classroomsByGrade.keys.toList();

    PdfPageFormat format;
    int gradesPerPage = 2; // Default for A4 or Custom

    switch (settings.exportPageSize) {
      case 'A3':
        format = PdfPageFormat.a3;
        gradesPerPage = 3;
        break;
      case 'Custom':
        final double width = (settings.customPageWidth ?? 21.0) * PdfPageFormat.cm;
        final double height = (settings.customPageHeight ?? 29.7) * PdfPageFormat.cm;
        format = PdfPageFormat(width, height);
        break;
      case 'A4':
      default:
        format = PdfPageFormat.a4;
        gradesPerPage = 2;
        break;
    }

    if (settings.exportPageSize != 'Custom') {
      if (settings.exportOrientation == 'Landscape') {
        format = format.landscape;
      } else {
        format = format.portrait;
      }
    }

    // Split grades into chunks (Atomic Grouping)
    for (int i = 0; i < gradeNames.length; i += gradesPerPage) {
      final chunkGrades = gradeNames.sublist(
          i,
          i + gradesPerPage > gradeNames.length
              ? gradeNames.length
              : i + gradesPerPage);

      // Collect all classrooms for this chunk
      final chunkClassrooms = <Classroom>[];
      for (var g in chunkGrades) {
        chunkClassrooms.addAll(classroomsByGrade[g]!);
      }

      if (chunkClassrooms.isEmpty) continue;

      doc.addPage(
        pw.Page(
          pageFormat: format,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Theme(
                data: pw.ThemeData.withFont(
                  base: font,
                  bold: font,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            settings.schoolName,
                            style: pw.TextStyle(fontSize: 14, font: font, fontWeight: pw.FontWeight.bold),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            'جدول الدروس الأسبوعي',
                            style: pw.TextStyle(fontSize: 18, font: font, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            settings.principalName,
                            style: pw.TextStyle(fontSize: 14, font: font, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    // Master Table
                    pw.Expanded(
                      child: _buildMasterTable(chunkClassrooms, lessons, settings, font, format),
                    ),
                    pw.SizedBox(height: 10),
                    // Footer / Principal
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          'مدير المدرسة / ${settings.principalName}',
                          style: pw.TextStyle(fontSize: 14, font: font, fontWeight: pw.FontWeight.bold),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ]
                    )
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildMasterTable(
      List<Classroom> classrooms,
      List<Lesson> allLessons,
      AppSettings settings,
      pw.Font font,
      PdfPageFormat format) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    // We need auto-fit layout. Minimum font size 6pt.
    // Best way in pw is to use FittedBox scaleDown around the table.
    // Also use equal FlexColumnWidth for classrooms.

    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FlexColumnWidth(0.8), // Day
      1: const pw.FlexColumnWidth(0.6), // Period
      for (int i = 0; i < classrooms.length; i++)
        i + 2: const pw.FlexColumnWidth(1),
    };

    double baseFontSize = 10.0;
    if (classrooms.length > 8) baseFontSize = 8.0;
    if (classrooms.length > 12) baseFontSize = 6.0;

    final headerRows = [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: [
          _buildCellHeader('اليوم', font, baseFontSize),
          _buildCellHeader('الدرس', font, baseFontSize),
          for (var c in classrooms) _buildCellHeader(c.name, font, baseFontSize),
        ],
      )
    ];

    final dataRows = <pw.TableRow>[];

    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < periodsPerDay; p++) {
        final cells = <pw.Widget>[];

        // Day cell (only on first period)
        if (p == 0) {
          cells.add(
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Center(
                child: pw.Text(
                  displayDays[d],
                  style: pw.TextStyle(font: font, fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            ),
          );
        } else {
          cells.add(pw.SizedBox());
        }

        // Period
        cells.add(
          pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Center(
              child: pw.Text(
                (p + 1).toString(),
                style: pw.TextStyle(font: font, fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        );

        // Classrooms
        for (var c in classrooms) {
          final lesson = allLessons.where((l) => l.classroom.value?.id == c.id && l.dayIndex == d && l.periodIndex == p && !l.isUnassigned).firstOrNull;
          if (lesson != null) {
             cells.add(
              pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      lesson.subject.value?.name ?? '',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: font, fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      lesson.teacher.value?.name ?? '',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: font, fontSize: baseFontSize - 1, color: PdfColors.grey700),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            );
          } else {
            cells.add(pw.SizedBox());
          }
        }

        // Background color alternating
        final bgColor = p % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
        dataRows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: cells,
        ));
      }
    }

    final table = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: columnWidths,
      children: [
        ...headerRows,
        ...dataRows,
      ],
    );

    return pw.FittedBox(
      fit: pw.BoxFit.scaleDown,
      child: table,
    );
  }

  pw.Widget _buildCellHeader(String text, pw.Font font, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }
}
