

import 'package:excel/excel.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

class ExcelExportUseCase {
  Future<List<int>> generateTimetableExcel(List<Lesson> lessons, List<Classroom> classrooms, AppSettings settings) async {
    final excel = Excel.createExcel();
    final sheetName = 'الجدول الأسبوعي';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Header
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#E0F2F1'),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    int colIndex = 0;

    // Principal Name Row
    var principalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    principalCell.value = TextCellValue('المدير : ${settings.principalName}');
    principalCell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    if (classrooms.isNotEmpty) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 1 + classrooms.length, rowIndex: 0),
      );
    }

    var dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: 1));
    dayCell.value = TextCellValue('اليوم');
    dayCell.cellStyle = headerStyle;

    var periodCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: 1));
    periodCell.value = TextCellValue('الدرس');
    periodCell.cellStyle = headerStyle;

    for (var classroom in classrooms) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: 1));
      cell.value = TextCellValue(classroom.name);
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E0F2F1'),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Medium),
        rightBorder: Border(borderStyle: BorderStyle.Medium),
      );
    }

    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int periodsPerDay = settings.periodsPerDay;

    final Map<String, Lesson> lessonMap = {};
    for (final l in lessons) {
      if (!l.isUnassigned) {
        final cId = l.classroom.value?.id;
        if (cId != null) {
          lessonMap['${cId}_${l.dayIndex}_${l.periodIndex}'] = l;
        }
      }
    }

    int rowIndex = 2;

    for (int d = 0; d < displayDays.length; d++) {
      int startRowOfDay = rowIndex;

      for (int p = 0; p < periodsPerDay; p++) {
        colIndex = 0;

        final baseStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
        );

        var dCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex));
        dCell.value = TextCellValue(displayDays[d]);
        dCell.cellStyle = baseStyle;

        var pCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex));
        pCell.value = TextCellValue((p + 1).toString());
        pCell.cellStyle = baseStyle;

        for (var classroom in classrooms) {
          final lesson = lessonMap['${classroom.id}_${d}_${p}'];
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex));

          if (lesson != null) {
            final subjectName = lesson.subject.value?.name ?? '-';
            final teacherName = lesson.teacher.value != null ? lesson.teacher.value!.name.split(' ').first : '-';
            cell.value = TextCellValue('$subjectName\n$teacherName');

            String hexColor = _getSubjectColor(subjectName);

            cell.cellStyle = CellStyle(
              horizontalAlign: HorizontalAlign.Center,
              verticalAlign: VerticalAlign.Center,
              topBorder: Border(borderStyle: BorderStyle.Thin),
              bottomBorder: Border(borderStyle: BorderStyle.Thin),
              leftBorder: Border(borderStyle: BorderStyle.Thin),
              rightBorder: Border(borderStyle: BorderStyle.Thin),
              backgroundColorHex: ExcelColor.fromHexString(hexColor),
              textWrapping: TextWrapping.WrapText,
            );
          } else {
             cell.cellStyle = baseStyle;
          }
        }
        rowIndex++;
      }

      // Merge Day Cells
      if (rowIndex - 1 > startRowOfDay) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRowOfDay),
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex - 1)
        );
      }
    }

    // Find consecutive identical lessons and merge them per classroom per day
    for (int d = 0; d < displayDays.length; d++) {
      for (int c = 0; c < classrooms.length; c++) {
        final classroom = classrooms[c];
        int col = 2 + c;
        int pStart = 0;

        while (pStart < periodsPerDay) {
          final lessonStart = lessonMap['${classroom.id}_${d}_${pStart}'];
          if (lessonStart == null) {
            pStart++;
            continue;
          }

          int pEnd = pStart;
          while (pEnd + 1 < periodsPerDay) {
            final nextLesson = lessonMap['${classroom.id}_${d}_${pEnd + 1}'];
            if (nextLesson != null &&
                nextLesson.subject.value?.id == lessonStart.subject.value?.id &&
                nextLesson.teacher.value?.id == lessonStart.teacher.value?.id) {
              pEnd++;
            } else {
              break;
            }
          }

          if (pEnd > pStart) {
            int rowStart = 2 + (d * periodsPerDay) + pStart;
            int rowEnd = 2 + (d * periodsPerDay) + pEnd;
            sheet.merge(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowStart),
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowEnd)
            );
          }

          pStart = pEnd + 1;
        }
      }
    }

    return excel.encode()!;
  }

  String _getSubjectColor(String subject) {
    final colors = ['#FFCDD2', '#F8BBD0', '#E1BEE7', '#D1C4E9', '#C5CAE9', '#BBDEFB', '#B3E5FC', '#B2EBF2', '#B2DFDB', '#C8E6C9', '#DCEDC8', '#F0F4C3', '#FFF9C4', '#FFECB3', '#FFE0B2', '#FFCCBC', '#D7CCC8', '#F5F5F5', '#CFD8DC'];
    int hash = subject.hashCode.abs();
    return colors[hash % colors.length];
  }
}
