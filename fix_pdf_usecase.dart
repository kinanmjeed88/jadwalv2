import 'dart:io';

void main() {
  var file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    "import '../../../../core/models/settings.dart';",
    "import '../../../../core/models/settings.dart';\nimport '../../../../core/models/teacher.dart';"
  );

  // Add generateTeacherTimetablePdf method
  var lines = content.split('\n');
  int insertIdx = lines.indexWhere((l) => l.contains('Future<Uint8List> generateTimetablePdf'));

  String newMethod = '''
  Future<Uint8List> generateTeacherTimetablePdf(List<Lesson> lessons,
      List<Teacher> teachers, AppSettings settings) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final font = pw.Font.ttf(fontData);

    PdfPageFormat format = PdfPageFormat.a4;
    if (settings.exportOrientation == 'Landscape') {
      format = format.landscape;
    }

    final Map<String, Lesson> lessonMap = {};
    for (final l in lessons) {
      if (!l.isUnassigned) {
        final tId = l.teacher.value?.id;
        if (tId != null) {
          lessonMap['\${tId}_\${l.dayIndex}_\${l.periodIndex}'] = l;
        }
      }
    }

    for (var teacher in teachers) {
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
            return pw.Column(
              children: [
                _buildHeader(settings, font),
                pw.SizedBox(height: 10),
                pw.Text('جدول المدرس: \${teacher.name}', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 15),
                _buildTeacherTable(teacher, lessonMap, settings, font, format.availableWidth - 40),
                pw.Spacer(),
                _buildFooter(settings, font),
              ]
            );
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
        final lesson = lessonMap['\${teacher.id}_\${d}_\${p}'];
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
''';

  if (insertIdx != -1) {
    lines.insert(insertIdx, newMethod);
  }

  file.writeAsStringSync(lines.join('\n'));
}
