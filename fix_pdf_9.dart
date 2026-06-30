import 'dart:io';

void main() {
  final file = File('lib/features/timetable/domain/usecases/pdf_export_usecase.dart');
  String content = file.readAsStringSync();

  final regex = RegExp(r"    // Determine layout constraints\s+int maxCapacity = 6; // Default A4\s+if \(settings.exportPageSize == 'A3'\) maxCapacity = 10;[\s\S]*?if \(totalClassroomsCount < maxCapacity\) \{\s+maxCapacity = totalClassroomsCount;\s+\}\s+if \(settings.exportOrientation == 'Landscape' &&\s+settings.exportPageSize != 'Custom'\) \{\s+gradesPerPage =\s+gradeNames.length; // Fit all in one page for Landscape if possible\s+maxCapacity =\s+totalClassroomsCount; // In landscape, we show all classrooms, so scale width based on total\s+\}\s+// Split grades into chunks \(Atomic Grouping\)\s+for \(int i = 0; i < gradeNames.length; i \+= gradesPerPage\) \{\s+final chunkGrades = gradeNames.sublist\(\s+i,\s+i \+ gradesPerPage > gradeNames.length\s+\? gradeNames.length\s+: i \+ gradesPerPage\);\s+// Collect all classrooms for this chunk\s+final chunkClassrooms = <Classroom>\[\];\s+for \(var g in chunkGrades\) \{\s+chunkClassrooms.addAll\(classroomsByGrade\[g\]!\);\s+\}\s+if \(chunkClassrooms.isEmpty\) continue;\s+doc.addPage\(");

  final replaceStr = '''
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
''';

  content = content.replaceFirst(regex, replaceStr);

  file.writeAsStringSync(content);
}
