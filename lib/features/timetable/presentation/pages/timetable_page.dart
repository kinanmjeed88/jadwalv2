import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:isar/isar.dart';

import '../providers/timetable_provider.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../domain/usecases/pdf_export_usecase.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../management/presentation/providers/management_provider.dart';

class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(timetableNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول المدرسي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير كـ PDF',
            onPressed: () async {
              final isar = await ref.read(isarDatabaseProvider.future);
              final lessons = await isar.lessons.where().findAll();
              final classRooms = await isar.collection<Classroom>().where().findAll();

              final settingsList = await isar.appSettings.where().findAll();
              final settings = settingsList.isNotEmpty
                  ? settingsList.first
                  : (AppSettings()..periodsPerDay = 7);

              final pdfUsecase = PdfExportUseCase();
              final pdfBytes = await pdfUsecase.generateTimetablePdf(
                  lessons, classRooms, settings.periodsPerDay);

              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
            },
          )
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          return timetableAsync.when(
            data: (lessons) {
              if (lessons.isEmpty) {
                return const Center(child: Text('لا يوجد حصص مضافة. اذهب للإدارة لتعيين حصص.'));
              }
              return _buildTimetableGrid(context, ref, lessons, settings);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('حدث خطأ: \$e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ في الإعدادات: \$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ref.read(timetableNotifierProvider.notifier).generateTimetable();
          final lessons = await ref.read(timetableNotifierProvider.future);
          if (context.mounted) {
            final unassigned = lessons.where((l) => l.isUnassigned).toList();
            if (unassigned.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم توليد الجدول، ولكن فشل تعيين \${unassigned.length} حصة بسبب القيود.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم توليد الجدول بالكامل بنجاح!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
        label: const Text('توليد الجدول آلياً'),
        icon: const Icon(Icons.autorenew),
      ),
    );
  }

  Widget _buildTimetableGrid(BuildContext context, WidgetRef ref, List<Lesson> lessons, AppSettings settings) {
    final assigned = lessons.where((l) => !l.isUnassigned).toList();
    final unassigned = lessons.where((l) => l.isUnassigned).toList();

    // Group assigned lessons by classroom for a tabbed or paginated view
    final classrooms = assigned.map((l) => l.classroom.value).where((c) => c != null).toSet().toList();

    if (classrooms.isEmpty && unassigned.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(child: Text('جميع الحصص المضافة لم يتم جدولتها بعد. اضغط توليد.')),
          const SizedBox(height: 16),
          Text('(\${unassigned.length} حصة بانتظار التوزيع)', style: const TextStyle(color: Colors.red)),
        ],
      );
    }

    return Column(
      children: [
        if (unassigned.isNotEmpty)
          Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(8.0),
            child: Text('يوجد \${unassigned.length} دروس غير مجدولة (استعصاء أو لم يتم التوليد)',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        Expanded(
          child: DefaultTabController(
            length: classrooms.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: classrooms.map((c) => Tab(text: c!.name)).toList(),
                  labelColor: Colors.teal,
                  unselectedLabelColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    children: classrooms.map((c) {
                      return _buildClassroomTable(assigned.where((l) => l.classroom.value?.id == c!.id).toList(), settings, ref);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassroomTable(List<Lesson> classLessons, AppSettings settings, WidgetRef ref) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DataTable(
            border: TableBorder.all(color: Colors.grey.shade300),
            headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
            columns: [
              const DataColumn(label: Text('اليوم / الحصة', style: TextStyle(fontWeight: FontWeight.bold))),
              for (int p = 0; p < settings.periodsPerDay; p++)
                DataColumn(label: Text('الحصة \${p + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: [
              for (int d = 0; d < displayDays.length; d++)
                DataRow(cells: [
                  DataCell(Text(displayDays[d], style: const TextStyle(fontWeight: FontWeight.bold))),
                  for (int p = 0; p < settings.periodsPerDay; p++)
                    DataCell(
                      _buildCell(classLessons, d, p, ref),
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(List<Lesson> classLessons, int dayIndex, int periodIndex, WidgetRef ref) {
    final lesson = classLessons.where((l) => l.dayIndex == dayIndex && l.periodIndex == periodIndex).firstOrNull;

    if (lesson == null) {
      return const SizedBox(width: 100, height: 60);
    }

    return DragTarget<Lesson>(
      onWillAcceptWithDetails: (details) {
        final incoming = details.data;
        return incoming.id != lesson.id;
      },
      onAcceptWithDetails: (details) async {
        final incoming = details.data;
        final success = await ref.read(timetableNotifierProvider.notifier).swapLessons(incoming, lesson);
        if (!success) {
          // Can't show snackbar easily here without a context that guarantees scaffolding
          // The provider could be updated to throw or handle UI differently.
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Draggable<Lesson>(
          data: lesson,
          feedback: Material(
            child: Container(
              color: Colors.teal.withValues(alpha: 0.8),
              padding: const EdgeInsets.all(8),
              child: Text('\${lesson.subject.value?.name}', style: const TextStyle(color: Colors.white)),
            ),
          ),
          childWhenDragging: Container(color: Colors.grey.shade200, width: 100, height: 60),
          child: Container(
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty ? Colors.teal.shade100 : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(lesson.subject.value?.name ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                Text(lesson.teacher.value?.name ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}
