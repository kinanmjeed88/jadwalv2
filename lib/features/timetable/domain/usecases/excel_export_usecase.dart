import 'package:excel/excel.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/utils/string_utils.dart';

class ExcelExportUseCase {
  String getAcademicYear() {
    final now = DateTime.now();
    int startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear/${startYear + 1}';
  }

  Future<List<int>> generateTimetableExcel(List<Lesson> lessons, List<Classroom> classrooms, AppSettings settings) async {
    final excel = Excel.createExcel();
    final sheetName = 'الجدول الأسبوعي';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    int classroomsCount = classrooms.length;
    int totalCols = classroomsCount + 2;

    // Set Column Widths (Right-to-Left perspective visually mapping indices)
    sheet.setColumnWidth(totalCols - 1, 12.0); // Day Column (Rightmost)
    sheet.setColumnWidth(totalCols - 2, 12.0); // Period Column
    for (int i = 0; i < classroomsCount; i++) {
      sheet.setColumnWidth(totalCols - 3 - i, 25.0); // Classrooms moving left
    }

    // Set Header Row Heights
    sheet.setRowHeight(0, 30.0);
    sheet.setRowHeight(1, 30.0);
    sheet.setRowHeight(2, 30.0);
    sheet.setRowHeight(3, 30.0);

    // Data Row Heights
    final int daysCount = settings.daysPerWeek;
    final int periodsCount = settings.periodsPerDay;
    final int totalLessonRows = daysCount * periodsCount;

    for (int r = 4; r < 4 + totalLessonRows; r++) {
      sheet.setRowHeight(r, 45.0);
    }

    String schoolName = (settings.schoolName as String?) ?? '';
    String principalName = (settings.principalName as String?) ?? '';
    String academicYear = getAcademicYear();

    final centerMergeStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Row 0
    // School Name (Rightmost in standard, but Leftmost visually RTL mapping? Wait, let's look at issue:
    // "اليمين (العمود الأول Index 0): اكتب اسم المدرسة"
    var cellSchool = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    cellSchool.value = TextCellValue('اسم المدرسة: $schoolName');
    cellSchool.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Title merged in center
    if (totalCols > 2) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: totalCols - 2, rowIndex: 0)
      );
      var cellTitle = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
      cellTitle.value = TextCellValue('جدول الدروس الأسبوعي');
      cellTitle.cellStyle = centerMergeStyle;
    }

    // Principal Name (اليسار (العمود الأخير totalCols - 1): اكتب المدير)
    var cellPrincipal = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0));
    cellPrincipal.value = TextCellValue('المدير: $principalName');
    cellPrincipal.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );


    // Row 1: Academic Year
    if (totalCols > 2) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: totalCols - 2, rowIndex: 1)
      );
      var cellYear = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1));
      cellYear.value = TextCellValue('العام الدراسي: $academicYear');
      cellYear.cellStyle = centerMergeStyle;
    }

    // Row 2 is Empty

    // Row 3: Column Headers
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

    var dayCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 3));
    dayCell.value = TextCellValue('اليوم');
    dayCell.cellStyle = headerStyle;

    var periodCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 2, rowIndex: 3));
    periodCell.value = TextCellValue('الدرس');
    periodCell.cellStyle = headerStyle;

    for (int i = 0; i < classrooms.length; i++) {
      var classroom = classrooms[i];
      String cName = (classroom.name as String?) ?? '';
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 3 - i, rowIndex: 3));
      cell.value = TextCellValue(cName);
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
        l.teacher.loadSync();
        l.subject.loadSync();
        l.classroom.loadSync();
        final cId = l.classroom.value?.id;
        if (cId != null) {
          lessonMap['${cId}_${l.dayIndex}_${l.periodIndex}'] = l;
        }
      }
    }

    int rowIndex = 4;

    for (int d = 0; d < displayDays.length; d++) {
      int startRowOfDay = rowIndex;

      for (int p = 0; p < periodsPerDay; p++) {
        final baseStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
        );

        var dCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: rowIndex));
        dCell.value = TextCellValue(displayDays[d]);
        dCell.cellStyle = baseStyle;

        var pCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 2, rowIndex: rowIndex));
        pCell.value = TextCellValue((p + 1).toString());
        pCell.cellStyle = baseStyle;

        for (int c = 0; c < classrooms.length; c++) {
          var classroom = classrooms[c];
          final lesson = lessonMap['${classroom.id}_${d}_${p}'];
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalCols - 3 - c, rowIndex: rowIndex));

          if (lesson != null) {
            String subjectName = ((lesson.subject.value?.name as String?) ?? '-').cleanSubjectName();
            String teacherName = '-';
            if (lesson.teacher.value != null) {
              teacherName = ((lesson.teacher.value!.name as String?) ?? '-').split(' ').first;
            }
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
          CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: startRowOfDay),
          CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: rowIndex - 1)
        );
      }
    }

    // Find consecutive identical lessons and merge them per classroom per day
    for (int d = 0; d < displayDays.length; d++) {
      for (int c = 0; c < classrooms.length; c++) {
        final classroom = classrooms[c];
        int col = totalCols - 3 - c;
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
            int rowStart = 4 + (d * periodsPerDay) + pStart;
            int rowEnd = 4 + (d * periodsPerDay) + pEnd;
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
    if (subject == '-') return '#FFFFFF';
    final colors = ['#FFCDD2', '#F8BBD0', '#E1BEE7', '#D1C4E9', '#C5CAE9', '#BBDEFB', '#B3E5FC', '#B2EBF2', '#B2DFDB', '#C8E6C9', '#DCEDC8', '#F0F4C3', '#FFF9C4', '#FFECB3', '#FFE0B2', '#FFCCBC', '#D7CCC8', '#F5F5F5', '#CFD8DC'];
    int hash = subject.hashCode.abs();
    return colors[hash % colors.length];
  }
}
