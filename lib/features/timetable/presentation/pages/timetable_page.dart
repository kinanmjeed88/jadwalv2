import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timetable_provider.dart';
import '../../../../core/models/lesson.dart';
import '../../domain/usecases/pdf_export_usecase.dart';
import '../../../../core/providers/database_provider.dart';
import 'package:printing/printing.dart';
import 'package:isar/isar.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';

class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(timetableNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول المدرسي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final isar = await ref.read(isarDatabaseProvider.future);
              final lessons = await isar.lessons.where().findAll();
              final classRooms = await isar.collection<Classroom>().where().findAll();

              final settingsList = await isar.appSettings.where().findAll();
              final settings = settingsList.isNotEmpty ? settingsList.first : (AppSettings()..periodsPerDay = 7);

              final pdfUsecase = PdfExportUseCase();
              final pdfBytes = await pdfUsecase.generateTimetablePdf(lessons, classRooms, settings.periodsPerDay);

              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
            },
          )
        ],
      ),
      body: timetableAsync.when(
        data: (lessons) {
          if (lessons.isEmpty) {
            return const Center(child: Text('لا يوجد جدول مولد حالياً'));
          }
          return _buildTimetableGrid(context, ref, lessons);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: \$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(timetableNotifierProvider.notifier).generateTimetable();
        },
        label: const Text('توليد الجدول'),
        icon: const Icon(Icons.autorenew),
      ),
    );
  }

  Widget _buildTimetableGrid(BuildContext context, WidgetRef ref, List<Lesson> lessons) {
    final assigned = lessons.where((l) => !l.isUnassigned).toList();
    final unassigned = lessons.where((l) => l.isUnassigned).toList();

    return Column(
      children: [
        if (unassigned.isNotEmpty)
          Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(8.0),
            child: Text('يوجد \${unassigned.length} دروس غير مجدولة (استعصاء)', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // 5 Days
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: assigned.length, // Rough representation. Proper grid needs strict day/period mapping
            itemBuilder: (context, index) {
              final lesson = assigned[index];
              return Draggable<Lesson>(
                data: lesson,
                feedback: Material(
                  child: Container(
                    color: Colors.teal.withOpacity(0.7),
                    padding: const EdgeInsets.all(8),
                    child: Text('\${lesson.subject.value?.name}', style: const TextStyle(color: Colors.white)),
                  ),
                ),
                childWhenDragging: Container(color: Colors.grey.shade300),
                child: DragTarget<Lesson>(
                  onWillAccept: (incoming) {
                    return incoming != null && incoming.id != lesson.id;
                  },
                  onAccept: (incoming) async {
                    final success = await ref.read(timetableNotifierProvider.notifier).swapLessons(incoming, lesson);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لا يمكن التبديل لوجود تعارض')),
                      );
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      decoration: BoxDecoration(
                        color: candidateData.isNotEmpty ? Colors.teal.shade100 : Colors.teal.shade50,
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(lesson.subject.value?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(lesson.teacher.value?.name ?? '', style: const TextStyle(fontSize: 10)),
                            Text(lesson.classroom.value?.name ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
