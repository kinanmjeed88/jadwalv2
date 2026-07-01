import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/teacher.dart';

class PdfExportUseCase {
  String getAcademicYear() {
    final now = DateTime.now();
    int startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  Future<Uint8List> generateTeacherTimetablePdf(List<Lesson> lessons,
      List<Teacher> teachers, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    PdfPageFormat format = PdfPageFormat.a4.landscape;

    final Map<String, Lesson> lessonMap = {};
    for (final l in lessons) {
      if (!l.isUnassigned) {
        final tId = l.teacher.value?.id;
        if (tId != null) {
          lessonMap['${tId}_${l.dayIndex}_${l.periodIndex}'] = l;
        }
      }
    }

    for (var teacher in teachers) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          header: (pw.Context context) => _buildHeader(settings, font, subtitle: 'جدول المدرس: ${teacher.name}'),
          footer: (pw.Context context) => _buildFooter(settings, font, context),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 15),
              _buildTeacherTable(teacher, lessonMap, settings, font, format.availableWidth - 40),
            ];
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildTeacherTable(
      Teacher teacher,
      Map<String, Lesson> lessonMap,
      AppSettings settings,
      pw.Font font,
      double availableWidth) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    final double unitWidth = availableWidth / (1.4 + periodsPerDay);

    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: pw.FixedColumnWidth(unitWidth * 1.4), // Day
      for (int i = 0; i < periodsPerDay; i++)
        i + 1: pw.FixedColumnWidth(unitWidth * 1.0),
    };

    final List<pw.TableRow> rows = [];

    // Header Row
    rows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: [
          _buildCell('اليوم / الحصة', font, 12, isHeader: true),
          for (int p = 0; p < periodsPerDay; p++)
            _buildCell((p + 1).toString(), font, 12, isHeader: true),
        ],
      ),
    );

    for (int d = 0; d < displayDays.length; d++) {
      final cells = <pw.Widget>[];
      cells.add(_buildCell(displayDays[d], font, 12, isBold: true));

      for (int p = 0; p < periodsPerDay; p++) {
        final lesson = lessonMap['${teacher.id}_${d}_${p}'];
        if (lesson != null) {
          cells.add(
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(2),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    lesson.subject.value?.name ?? '',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    lesson.classroom.value?.name ?? '',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          );
        } else {
          cells.add(pw.SizedBox());
        }
      }

      final bgColor = d % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: cells,
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    // Sort classrooms by id to keep consistent order
    classrooms.sort((a, b) => a.id.compareTo(b.id));

    PdfPageFormat format = PdfPageFormat.a3.landscape;

    // Determine layout constraints
    final double margins = 40.0; // 20 each side
    final double availableWidth = format.width - margins;

    // Minimum acceptable width for a classroom column is 50pt
    // Day (0.8 unit) + Period (0.6 unit) + Classrooms (1.0 unit each)
    // totalUnits = 1.4 + classroomCount
    // availableWidth / (1.4 + classroomCount) >= 50
    // 1.4 + classroomCount <= availableWidth / 50
    // classroomCount <= (availableWidth / 50) - 1.4

    int maxCapacity = ((availableWidth / 50) - 1.4).floor();
    if (maxCapacity < 1) maxCapacity = 1;

    // In Landscape, we try to fit more, but still need a limit to keep it readable.
    // If the user didn't specify a limit, we use the calculated one.

    final List<List<Classroom>> horizontalChunks = [];
    for (int i = 0; i < classrooms.length; i += maxCapacity) {
      horizontalChunks.add(classrooms.sublist(
          i,
          i + maxCapacity > classrooms.length
              ? classrooms.length
              : i + maxCapacity));
    }

    // Build the lesson map once with full data guarantee
    final Map<String, Lesson> lessonMap = {};
    for (final l in lessons) {
      if (!l.isUnassigned) {
        final cId = l.classroom.value?.id;
        if (cId != null) {
          lessonMap['${cId}_${l.dayIndex}_${l.periodIndex}'] = l;
        }
      }
    }

    for (var chunk in horizontalChunks) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          header: (pw.Context context) => _buildHeader(settings, font),
          footer: (pw.Context context) => _buildFooter(settings, font, context),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 15),
              _buildMasterTable(chunk, lessonMap, settings, font, format.availableWidth - 40),
            ];
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildHeader(AppSettings settings, pw.Font font, {String? subtitle}) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              settings.schoolName,
              style: pw.TextStyle(
                  fontSize: 14, font: font, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(children: [
              pw.Text(
                'جدول الدروس الأسبوعي',
                style: pw.TextStyle(
                    fontSize: 18, font: font, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                      fontSize: 16, font: font, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Text(
                'العام الدراسي: ${getAcademicYear()}',
                style: pw.TextStyle(fontSize: 12, font: font),
                textAlign: pw.TextAlign.center,
              ),
            ]),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.SizedBox(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(AppSettings settings, pw.Font font, pw.Context context) {
    return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'صفحة ${context.pageNumber} من ${context.pagesCount}',
          style: pw.TextStyle(
              fontSize: 12, font: font, fontWeight: pw.FontWeight.normal),
          textDirection: pw.TextDirection.rtl,
        ));
  }

  pw.Widget _buildMasterTable(
      List<Classroom> chunk,
      Map<String, Lesson> lessonMap,
      AppSettings settings,
      pw.Font font,
      double availableWidth) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    // Dynamic width calculation
    final double totalProportions = 0.8 + 0.6 + chunk.length;
    final double unitWidth = availableWidth / totalProportions;

    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: pw.FixedColumnWidth(unitWidth * 0.8), // Day
      1: pw.FixedColumnWidth(unitWidth * 0.6), // Period
      for (int i = 0; i < chunk.length; i++)
        i + 2: pw.FixedColumnWidth(unitWidth * 1.0),
    };

    double baseFontSize = 10.0;
    if (chunk.length > 8) baseFontSize = 8.0;
    if (chunk.length > 12) baseFontSize = 6.0;

    final List<pw.TableRow> rows = [];

    // Header Row
    rows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: [
          _buildCell('اليوم', font, baseFontSize, isHeader: true),
          _buildCell('الدرس', font, baseFontSize, isHeader: true),
          for (var c in chunk)
            _buildCell(c.name, font, baseFontSize, isHeader: true),
        ],
      ),
    );

    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < periodsPerDay; p++) {
        final cells = <pw.Widget>[];

        // Day cell (only on first period or every row if preferred for MultiPage clarity)
        // To handle MultiPage well, repeating the day name or having clear borders is good.
        // But traditional tables only show it once.
        // If it breaks across pages, the day name might be missing on the new page.
        // Let's show it on every row but maybe with lighter text or only if it's the first in page?
        // Actually, for simplicity and standard look:
        cells.add(
          _buildCell(p == 0 ? displayDays[d] : '', font, baseFontSize, isBold: true),
        );

        // Period
        cells.add(
          _buildCell((p + 1).toString(), font, baseFontSize, isBold: true),
        );

        // Classrooms
        for (var c in chunk) {
          final lesson = lessonMap['${c.id}_${d}_${p}'];
          if (lesson != null) {
            cells.add(
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(2),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      lesson.subject.value?.name ?? '',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: font, fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      lesson.teacher.value?.name ?? '',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: font, fontSize: baseFontSize - 1, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );
          } else {
            cells.add(pw.SizedBox());
          }
        }

        final bgColor = p % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: cells,
        ));
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: columnWidths,
      children: rows,
    );
  }

  pw.Widget _buildCell(String text, pw.Font font, double fontSize,
      {bool isHeader = false, bool isBold = false}) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
