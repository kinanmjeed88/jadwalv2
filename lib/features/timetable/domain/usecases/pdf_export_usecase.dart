import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/teacher.dart';

const double _highResFactor = 3.0;

class PdfExportUseCase {
  String getAcademicYear() {
    final now = DateTime.now();
    int startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  Future<Uint8List> generateTeacherTimetablePdf(List<Lesson> lessons,
      List<Teacher> teachers, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    PdfPageFormat format = PdfPageFormat.a4.landscape;

    final PdfPageFormat highResFormat = PdfPageFormat(
      format.width * _highResFactor,
      format.height * _highResFactor,
      marginTop: 20 * _highResFactor,
      marginBottom: 20 * _highResFactor,
      marginLeft: 20 * _highResFactor,
      marginRight: 20 * _highResFactor,
    );

    for (var teacher in teachers) {
      final teacherLessons = lessons.where((l) => !l.isUnassigned && l.teacher.value?.id == teacher.id).toList();

      final Map<String, Lesson> lessonMap = {};
      for (final l in teacherLessons) {
        lessonMap['${teacher.id}_${l.dayIndex}_${l.periodIndex}'] = l;
      }

      doc.addPage(
        pw.Page(
          pageFormat: highResFormat,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.all(20 * _highResFactor),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (pw.Context context) {
            String teacherName = (teacher.name as String?) ?? 'بدون اسم';
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  _buildHeader(settings, font,
                      subtitle: 'جدول المدرس: $teacherName'),
                  pw.SizedBox(height: 15 * _highResFactor),
                  pw.Expanded(
                    child: _buildTeacherTable(teacher, lessonMap, settings,
                        font, highResFormat.availableHeight - (120 * _highResFactor)),
                  ),
                  _buildFooter(settings, font, context),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildTeacherTable(Teacher teacher, Map<String, Lesson> lessonMap,
      AppSettings settings, pw.Font font, double availableHeight) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    final int totalCols = 1 + periodsPerDay;

    final Map<int, pw.TableColumnWidth> columnWidths = {
      totalCols - 1: const pw.FlexColumnWidth(0.5),
      for (int i = 0; i < periodsPerDay; i++)
        totalCols - 2 - i: const pw.FlexColumnWidth(1.0),
    };

    final double rowHeight = availableHeight / (1 + displayDays.length);

    final List<pw.TableRow> rows = [];

    // Header Row
    final headerCells = <pw.Widget>[
      _buildCell('اليوم / الحصة', font, isHeader: true, height: rowHeight),
      for (int p = 0; p < periodsPerDay; p++)
        _buildCell((p + 1).toString(), font, isHeader: true, height: rowHeight),
    ];
    rows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: headerCells.reversed.toList(),
      ),
    );

    for (int d = 0; d < displayDays.length; d++) {
      final cells = <pw.Widget>[];
      cells.add(
          _buildCell(displayDays[d], font, isBold: true, height: rowHeight));

      for (int p = 0; p < periodsPerDay; p++) {
        final lesson = lessonMap['${teacher.id}_${d}_${p}'];
        if (lesson != null) {
          String subjectName = (lesson.subject.value?.name as String?) ?? '';
          String classroomName =
              (lesson.classroom.value?.name as String?) ?? '';
          cells.add(
            pw.Container(
              height: rowHeight,
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.all(2 * _highResFactor),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  left: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  right: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  top: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                ),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Text(
                    subjectName,
                    textAlign: pw.TextAlign.center,
                    softWrap: true,
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                        font: font,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10 * _highResFactor,
                    ),
                  ),
                  pw.Text(
                    classroomName,
                    textAlign: pw.TextAlign.center,
                    softWrap: true,
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      font: font,
                      color: PdfColors.grey700,
                      fontSize: 9 * _highResFactor,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          cells.add(pw.Container(
            height: rowHeight,
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                left: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                right: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
              ),
            ),
          ));
        }
      }

      final bgColor = d % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: bgColor),
        children: cells.reversed.toList(),
      ));
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5 * _highResFactor),
        columnWidths: columnWidths,
        children: rows,
      ),
    );
  }
  Future<Uint8List> generateTimetablePdf(List<Lesson> lessons,
      List<Classroom> classrooms, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    classrooms.sort((a, b) {
      String aGrade = (a.grade as String?) ?? '';
      String bGrade = (b.grade as String?) ?? '';
      int cmp = aGrade.compareTo(bGrade);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    PdfPageFormat baseFormat;
    switch (settings.exportPageSize) {
      case 'A3':
        baseFormat = PdfPageFormat.a3;
        break;
      case 'A5':
        baseFormat = PdfPageFormat.a5;
        break;
      case 'A4':
      default:
        baseFormat = PdfPageFormat.a4;
        break;
    }

    PdfPageFormat format = settings.exportOrientation == 'Portrait'
        ? baseFormat.portrait
        : baseFormat.landscape;

    final PdfPageFormat highResFormat = PdfPageFormat(
      format.width * _highResFactor,
      format.height * _highResFactor,
      marginTop: 20 * _highResFactor,
      marginBottom: 20 * _highResFactor,
      marginLeft: 20 * _highResFactor,
      marginRight: 20 * _highResFactor,
    );

    final List<List<Classroom>> chunks = [];
    if (settings.exportPageSize == 'A4') {
      // Group by Grade
      Map<String, List<Classroom>> gradeMap = {};
      for (var c in classrooms) {
        String grade = (c.grade as String?) ?? 'بدون صف';
        gradeMap.putIfAbsent(grade, () => []).add(c);
      }
      for (var gradeList in gradeMap.values) {
        chunks.add(gradeList);
      }
    } else if (settings.exportPageSize == 'A3') {
      // Draw all classrooms in a single page
      if (classrooms.isNotEmpty) {
        chunks.add(classrooms);
      }
    } else {
      // A5 or other, arbitrary chunking
      int maxCapacity = 2;
      for (int i = 0; i < classrooms.length; i += maxCapacity) {
        chunks.add(classrooms.sublist(
            i,
            i + maxCapacity > classrooms.length
                ? classrooms.length
                : i + maxCapacity));
      }
    }

    final Map<String, Lesson> lessonMap = {};
    for (final l in lessons) {
      if (!l.isUnassigned) {
        l.teacher.loadSync();
        l.subject.loadSync();
        l.classroom.loadSync();
        final cId = l.classroom.value?.id;
        if (cId != null) {
          lessonMap['${cId}_${l.dayIndex}_${l.periodIndex}'] = l;
        }
      }
    }

    for (var chunk in chunks) {
      doc.addPage(
        pw.Page(
          pageFormat: highResFormat,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.all(20 * _highResFactor),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  _buildHeader(settings, font),
                  pw.SizedBox(height: 15 * _highResFactor),
                  pw.Expanded(
                    child: _buildMasterTable(chunk, lessonMap, settings, font,
                        highResFormat.availableHeight - (120 * _highResFactor)),
                  ),
                  _buildFooter(settings, font, context),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildHeader(AppSettings settings, pw.Font font,
      {String? subtitle}) {
    String schoolName = (settings.schoolName as String?) ?? '';
    String principalName = (settings.principalName as String?) ?? '';
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              schoolName,
              style: pw.TextStyle(
                  fontSize: 14 * _highResFactor, font: font, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(children: [
              pw.Text(
                'جدول الدروس الأسبوعي',
                style: pw.TextStyle(
                    fontSize: 18 * _highResFactor, font: font, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if (subtitle != null) ...[
                pw.SizedBox(height: 4 * _highResFactor),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                      fontSize: 16 * _highResFactor, font: font, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              pw.SizedBox(height: 4 * _highResFactor),
              pw.Text(
                'العام الدراسي: ${getAcademicYear()}',
                style: pw.TextStyle(fontSize: 12 * _highResFactor, font: font),
                textAlign: pw.TextAlign.center,
              ),
            ]),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              'المدير : $principalName',
              style: pw.TextStyle(
                  fontSize: 12 * _highResFactor, font: font, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(
      AppSettings settings, pw.Font font, pw.Context context) {
    return pw.Container(
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.only(top: 10 * _highResFactor),
        child: pw.Text(
          'صفحة ${context.pageNumber} من ${context.pagesCount}',
          style: pw.TextStyle(
              fontSize: 12 * _highResFactor, font: font, fontWeight: pw.FontWeight.normal),
          textDirection: pw.TextDirection.rtl,
        ));
  }

  pw.Widget _buildMasterTable(
      List<Classroom> chunk,
      Map<String, Lesson> lessonMap,
      AppSettings settings,
      pw.Font font,
      double availableHeight) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    bool isA3Layout = chunk.length > 4;

    final int totalCols = 2 + chunk.length;

    final Map<int, pw.TableColumnWidth> columnWidths = {
      totalCols - 1: isA3Layout
          ? const pw.FlexColumnWidth(1.0)
          : const pw.FlexColumnWidth(0.5),
      totalCols - 2: isA3Layout
          ? const pw.FlexColumnWidth(1.0)
          : const pw.FlexColumnWidth(0.3),
      for (int i = 0; i < chunk.length; i++)
        totalCols - 3 - i: isA3Layout
            ? const pw.FlexColumnWidth(1.0)
            : const pw.FlexColumnWidth(2.0),
    };

    final double rowHeight =
        availableHeight / (1 + displayDays.length * periodsPerDay);

    final List<pw.TableRow> rows = [];

    // Header Row
    final headerCells = <pw.Widget>[
      _buildCell('اليوم', font, isHeader: true, height: rowHeight),
      _buildCell('الدرس', font, isHeader: true, height: rowHeight),
      for (int c = 0; c < chunk.length; c++)
        _buildCell(
          (chunk[c].name as String?) ?? '',
          font,
          isHeader: true,
          height: rowHeight,
        ),
    ];
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.teal100),
        children: headerCells.reversed.toList(),
      ),
    );

    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < periodsPerDay; p++) {
        final cells = <pw.Widget>[];

        bool isLastPeriodOfDay = p == periodsPerDay - 1;

        // Day Cell Logic
        if (p == 0) {
          cells.add(
            _buildCell(displayDays[d], font,
                isBold: true,
                hideBottomBorder: !isLastPeriodOfDay,
                height: rowHeight),
          );
        } else {
          cells.add(
            pw.Container(
              height: rowHeight,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: isLastPeriodOfDay
                      ? pw.BorderSide(
                          color: PdfColors.grey400, width: 0.5 * _highResFactor)
                      : pw.BorderSide.none,
                  left:
                      pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  right:
                      pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                ),
              ),
              child: pw.SizedBox(),
            ),
          );
        }

        // Period Cell Logic
        cells.add(
          _buildCell((p + 1).toString(), font, isBold: true, height: rowHeight),
        );

        // Classrooms Cells Logic
        for (int c = 0; c < chunk.length; c++) {
          final classroom = chunk[c];

          final lesson = lessonMap['${classroom.id}_${d}_${p}'];

          pw.Widget cellContent = pw.SizedBox();
          if (lesson != null) {
            String subjectName = (lesson.subject.value?.name as String?) ?? '';
            String teacherName = 'فارغ';
            if (lesson.teacher.value != null) {
              teacherName = ((lesson.teacher.value!.name as String?) ?? 'فارغ')
                  .split(' ')
                  .first;
            }

            cellContent = pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                pw.Expanded(
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      subjectName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          font: font, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      teacherName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: font, color: PdfColors.grey700),
                    ),
                  ),
                ),
              ],
            );
          }

          cells.add(
            pw.Container(
              height: rowHeight,
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.all(1 * _highResFactor),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom:
                      pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  left:
                      pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                  right:
                      pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
                ),
              ),
              child: cellContent,
            ),
          );
        }

        final bgColor = p % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
        rows.add(pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: cells.reversed.toList(),
        ));
      }
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5 * _highResFactor),
        columnWidths: columnWidths,
        children: rows,
      ),
    );
  }

  pw.Widget _buildCell(String text, pw.Font font,
      {bool isHeader = false,
      bool isBold = false,
      bool hideBottomBorder = false,
      double? height}) {
    return pw.Container(
      height: height,
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.all(4 * _highResFactor),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: hideBottomBorder
              ? pw.BorderSide.none
              : pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
          left: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
          right: pw.BorderSide(color: PdfColors.grey400, width: 0.5 * _highResFactor),
        ),
      ),
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontWeight: (isHeader || isBold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }
}