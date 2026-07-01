import 'dart:io';

void main() {
  var file = File('lib/features/timetable/presentation/pages/timetable_page.dart');
  var content = file.readAsStringSync();

  // Add Teacher PDF export button
  content = content.replaceFirst(
    '''          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير كـ PDF',
            onPressed: _exportToPdf,
          ),''',
    '''          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير جدول الفصول كـ PDF',
            onPressed: _exportToPdf,
          ),
          IconButton(
            icon: const Icon(Icons.person_pin_circle),
            tooltip: 'تصدير جدول المدرسين كـ PDF',
            onPressed: _exportTeacherPdf,
          ),'''
  );

  // Add _exportTeacherPdf method
  content = content.replaceFirst(
    '''  Future<void> _exportToPdf() async {''',
    '''  Future<void> _exportTeacherPdf() async {
    try {
      final isar = await ref.read(isarDatabaseProvider.future);

      final List<Lesson> lessons = isar.txnSync(() {
        final all = isar.lessons.where().findAllSync();
        for (var lesson in all) {
          lesson.classroom.loadSync();
          lesson.subject.loadSync();
          lesson.teacher.loadSync();
        }
        return all;
      });

      final teachers = await isar.teachers.where().findAll();
      final settingsList = await isar.appSettings.where().findAll();
      final settings = settingsList.isNotEmpty
          ? settingsList.first
          : (AppSettings()..periodsPerDay = 7);

      final pdfUsecase = PdfExportUseCase();
      final pdfBytes =
          await pdfUsecase.generateTeacherTimetablePdf(lessons, teachers, settings);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف PDF',
        fileName: 'teachers_timetable.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الملف بنجاح: \$outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {'''
  );

  // Replace _buildCell call in _buildMasterGrid
  content = content.replaceAll(
    "cells.add(DataCell(_buildCell(lesson)));",
    "cells.add(DataCell(_buildCell(lesson, classroom, d, p)));"
  );

  // Update _buildCell signature and logic
  content = content.replaceFirst(
    '''  Widget _buildCell(Lesson? lesson) {
    if (lesson == null) {
      return const SizedBox(width: 80, height: 40);
    }''',
    '''  Widget _buildCell(Lesson? lesson, Classroom classroom, int dayIndex, int periodIndex) {
    if (lesson == null) {
      return DragTarget<Lesson>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) async {
          final incoming = details.data;
          final (success, errorMessage) = await ref
              .read(timetableNotifierProvider.notifier)
              .moveLessonToEmpty(incoming, dayIndex, periodIndex);

          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage ?? 'حدث خطأ أثناء النقل'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            width: 80,
            height: 40,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty ? Colors.green.withValues(alpha: 0.3) : Colors.transparent,
            ),
          );
        },
      );
    }'''
  );

  // Add pinning UI
  content = content.replaceFirst(
    '''          child: Container(
            width: 80, // slightly narrower
            height: 40, // slightly shorter
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? Colors.teal.shade100
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(subjectName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis),
                Text(teacherName,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),''',
    '''          child: InkWell(
            onLongPress: () {
              ref.read(timetableNotifierProvider.notifier).togglePin(lesson);
            },
            child: Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: lesson.isPinned
                    ? Colors.orange.shade100
                    : (candidateData.isNotEmpty ? Colors.teal.shade100 : Colors.transparent),
                border: lesson.isPinned ? Border.all(color: Colors.orange, width: 2) : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(subjectName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        Text(teacherName,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (lesson.isPinned)
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: Icon(Icons.lock, size: 12, color: Colors.orange),
                    ),
                ],
              ),
            ),
          ),'''
  );

  file.writeAsStringSync(content);
}
