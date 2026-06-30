import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

class PdfExportUseCase {
  String getAcademicYear() {
    final now = DateTime.now();
    int startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
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


    switch (settings.exportPageSize) {
      case 'A3':
        format = PdfPageFormat.a3;

        break;
      case 'Custom':
        final double width =
            (settings.customPageWidth ?? 21.0) * PdfPageFormat.cm;
        final double height =
            (settings.customPageHeight ?? 29.7) * PdfPageFormat.cm;
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

    // Determine layout constraints dynamically based on available width
    // margins are 20 on each side (total 40)
    final double availableWidth = format.availableWidth - 40;

    // We want a minimum width per classroom column. Let's say 50pt.
    // Proportions: Day (0.8), Period (0.6) = 1.4 units. Each classroom = 1.0 unit.
    // Total units = 1.4 + maxCapacity.
    // We need: availableWidth / (1.4 + maxCapacity) >= 50
    // So: 1.4 + maxCapacity <= availableWidth / 50
    // maxCapacity <= (availableWidth / 50) - 1.4

    int maxCapacity = ((availableWidth / 50) - 1.4).floor();
    if (maxCapacity < 1) maxCapacity = 1;

    int totalClassroomsCount = classrooms.length;
    if (totalClassroomsCount < maxCapacity) {
      maxCapacity = totalClassroomsCount;
    }

    // Collect all classrooms sorted by grade and id
    final orderedClassrooms = <Classroom>[];
    for (var g in gradeNames) {
      orderedClassrooms.addAll(classroomsByGrade[g]!);
    }

    // Split classrooms into chunks based on maxCapacity
    for (int i = 0; i < orderedClassrooms.length; i += maxCapacity) {
      final chunkClassrooms = orderedClassrooms.sublist(
          i,
          i + maxCapacity > orderedClassrooms.length
              ? orderedClassrooms.length
              : i + maxCapacity);

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
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    pw.Directionality(
                      textDirection: pw.TextDirection.rtl,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                        pw.Expanded(
                          flex: 15,
                          child: pw.Text(
                            settings.schoolName,
                            style: pw.TextStyle(
                                fontSize: 14,
                                font: font,
                                fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Expanded(
                          flex: 20,
                          child: pw.Column(children: [
                            pw.Text(
                              'جدول الدروس الأسبوعي',
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  font: font,
                                  fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                              textDirection: pw.TextDirection.rtl,
                            ),
                            pw.Text(
                              'العام الدراسي: ${getAcademicYear()}',
                              style: pw.TextStyle(fontSize: 12, font: font),
                              textAlign: pw.TextAlign.center,
                              textDirection: pw.TextDirection.rtl,
                            ),
                          ]),
                        ),
                        pw.Expanded(
                          flex: 15,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'توقيع المدير',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  font: font,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                                textDirection: pw.TextDirection.rtl,
                              ),
                                pw.SizedBox(height: 30), // Empty space for handwritten signature
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    // Master Table
                    pw.Expanded(
                      child: pw.LayoutBuilder(
                        builder: (pw.Context context, pw.BoxConstraints? constraints) {
                          return _buildMasterTable(chunkClassrooms, lessons,
                              settings, font, constraints, maxCapacity);
                        },
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    // Footer / Principal
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'مدير المدرسة / ${settings.principalName}',
                            style: pw.TextStyle(
                                fontSize: 14,
                                font: font,
                                fontWeight: pw.FontWeight.bold),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ])
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
      pw.BoxConstraints? constraints,
      int maxCapacity) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    // Calculate fixed widths based on available page width
    // margins are 20 on each side (total 40)
    final double availableWidth = constraints?.maxWidth ?? 500.0;

    // Use maxCapacity or actual length, whichever is greater (to avoid overflow, but typically classrooms <= maxCapacity in portrait)
    // Actually, user wants unitWidth to be calculated strictly using maxCapacity or total classrooms if total < maxCapacity.
    // Wait, the instructions say:
    // "For A4 Portrait, maxCapacity = 6. For A3 Portrait, maxCapacity = 10."
    // "If the total classrooms in the school is less than maxCapacity, use the actual number of classrooms."
    // "For Landscape orientation... adjust maxCols to the total classrooms."
    int columnsToFit = classrooms.length;
    if (settings.exportOrientation != 'Landscape') {
      columnsToFit =
          maxCapacity; // Enforce maxCapacity for fixed cell sizes in Portrait chunks
    }

    // Proportions: Day (0.8), Period (0.6), Classrooms (1.0 each up to columnsToFit)
    final double totalProportions = 0.8 + 0.6 + columnsToFit;
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
          for (var c in classrooms)
            _buildCellHeader(c.name, font, baseFontSize),
        ],
      )
    ];

    // Optimize lesson lookup
    final Map<String, Lesson> lessonMap = {};
    int lessonsToRenderCount = 0;
    for (final l in allLessons) {
      if (!l.isUnassigned) {
        final cId = l.classroom.value?.id;
        if (cId != null) {
          lessonMap['${cId}_${l.dayIndex}_${l.periodIndex}'] = l;
          lessonsToRenderCount++;
        }
      }
    }

    print("Total lessons to render in this master table: $lessonsToRenderCount");

    final dataRows = <pw.TableRow>[];

    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < periodsPerDay; p++) {
        final cells = <pw.Widget>[];

        // Day cell (only on first period)
        if (p == 0) {
          cells.add(
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                displayDays[d],
                style: pw.TextStyle(
                    font: font,
                    fontSize: baseFontSize,
                    fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
            ),
          );
        } else {
          cells.add(pw.SizedBox());
        }

        // Period
        cells.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              (p + 1).toString(),
              style: pw.TextStyle(
                  font: font,
                  fontSize: baseFontSize,
                  fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        );

        // Classrooms
        for (var c in classrooms) {
          final lesson = lessonMap['${c.id}_${d}_${p}'];
          if (lesson != null) {
            cells.add(
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      lesson.subject.value?.name ?? '',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: baseFontSize,
                          fontWeight: pw.FontWeight.bold),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      lesson.teacher.value?.name ?? '',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: baseFontSize - 1,
                          color: PdfColors.grey700),
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

        // Background color alternating (Zebra Striping)
        final bgColor = p % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
        dataRows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: cells,
        ));
      }
    }

    final table = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: columnWidths,
      children: [
        ...headerRows,
        ...dataRows,
      ],
    );

    return table; // Removed FittedBox
  }

  pw.Widget _buildCellHeader(String text, pw.Font font, double fontSize) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            font: font, fontSize: fontSize, fontWeight: pw.FontWeight.bold),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
