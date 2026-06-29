import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:bidi/bidi.dart' as bidi;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

class PdfExportUseCase {
  String _shape(String text) {
    if (text.isEmpty) return text;
    // 1. Reshape the letters (connect them correctly)
    final reshaper = ArabicReshaper();
    final reshaped = reshaper.reshape(text);
    // 2. Apply Bidi algorithm to fix RTL character order for the PDF engine
    final visual = bidi.logicalToVisual(reshaped);
    // Return String from the Runes list returned by logicalToVisual
    return String.fromCharCodes(visual);
  }

  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    // Filter assigned lessons only to determine active classrooms
    final assignedLessons = lessons.where((l) => !l.isUnassigned).toList();
    final activeClassroomIds = assignedLessons.map((l) => l.classroom.value?.id).whereType<int>().toSet();
    final activeClassrooms = classrooms.where((c) => activeClassroomIds.contains(c.id)).toList();

    // Sort classrooms by id to keep consistent order
    activeClassrooms.sort((a, b) => a.id.compareTo(b.id));

    // Dynamic academic year based on current date
    final now = DateTime.now();
    final currentYear = now.year;
    // If month is before July, we are in the second half of the academic year
    final academicYear = now.month < 7 ? '${currentYear - 1}/$currentYear' : '$currentYear/${currentYear + 1}';

    PdfPageFormat format;

    switch (settings.exportPageSize) {
      case 'A3':
        format = PdfPageFormat.a3;
        break;
      case 'Custom':
        final double width = (settings.customPageWidth ?? 21.0) * PdfPageFormat.cm;
        final double height = (settings.customPageHeight ?? 29.7) * PdfPageFormat.cm;
        format = PdfPageFormat(width, height);
        break;
      case 'A4':
      default:
        format = PdfPageFormat.a4;
        break;
    }

    if (settings.exportPageSize != 'Custom') {
      if (settings.exportOrientation == 'Landscape') {
        format = format.landscape;
      } else {
        format = format.portrait;
      }
    }

    if (activeClassrooms.isEmpty) return doc.save();

    // Do NOT split table, single table for all classrooms. If too large, font scaling will handle it
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
                  // Top Header Only
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          _shape('${settings.schoolName} | السنة: $academicYear'),
                          style: pw.TextStyle(fontSize: 14, font: font, fontWeight: pw.FontWeight.bold),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          _shape('جدول الدروس الأسبوعي'),
                          style: pw.TextStyle(fontSize: 18, font: font, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          _shape('مدير المدرسة / ${settings.principalName}'),
                          style: pw.TextStyle(fontSize: 14, font: font, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.left,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                  // Single Master Table for ALL Classrooms
                  pw.Expanded(
                    child: _buildMasterTable(activeClassrooms, assignedLessons, settings, font, format),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

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

    // Calculate fixed widths based on available page width
    // margins are 20 on each side (total 40)
    final double availableWidth = format.availableWidth - 40;

    // Proportions: Day (0.8), Period (0.6), Classrooms (1.0 each)
    final double totalProportions = 0.8 + 0.6 + classrooms.length;
    final double unitWidth = availableWidth / totalProportions;

    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: pw.FixedColumnWidth(unitWidth * 0.8), // Day
      1: pw.FixedColumnWidth(unitWidth * 0.6), // Period
      for (int i = 0; i < classrooms.length; i++)
        i + 2: pw.FixedColumnWidth(unitWidth * 1.0),
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
                  _shape(displayDays[d]),
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
                      _shape(lesson.subject.value?.name ?? ''),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: font, fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      _shape(lesson.teacher.value?.name ?? ''),
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

    return table; // Single unified table without FittedBox
  }

  pw.Widget _buildCellHeader(String text, pw.Font font, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Text(
          _shape(text),
          style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }
}
