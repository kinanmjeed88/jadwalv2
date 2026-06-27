import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:isar/isar.dart';

import '../providers/timetable_provider.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/utils/period_mapper.dart';
import '../../domain/usecases/pdf_export_usecase.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../management/presentation/providers/management_provider.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  final Map<int, GlobalKey> _classroomKeys = {};
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final timetableAsync = ref.watch(timetableNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول المدرسي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'تصدير الجدول',
            onPressed: () => _showExportOptions(context),
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
              return _buildTimetableGrid(context, lessons, settings);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('حدث خطأ: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ في الإعدادات: $e')),
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
                  content: Text('تم توليد الجدول، ولكن فشل تعيين ' + unassigned.length.toString() + ' حصة بسبب القيود.'),
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

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('تصدير كـ PDF'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _exportToPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('تصدير كـ صورة (الشعبة الحالية)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _exportToImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportToPdf() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final lessons = await isar.lessons.where().findAll();
    final classRooms = await isar.collection<Classroom>().where().findAll();
    final settingsList = await isar.appSettings.where().findAll();
    final settings = settingsList.isNotEmpty
        ? settingsList.first
        : (AppSettings()..periodsPerDay = 7);

    final pdfUsecase = PdfExportUseCase();
    // We will update generateTimetablePdf later to accept AppSettings
    final pdfBytes = await pdfUsecase.generateTimetablePdf(
        lessons, classRooms, settings);

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ ملف PDF',
      fileName: 'timetable.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: pdfBytes,
    );

    if (outputFile != null) {
      if (!outputFile.endsWith('.pdf')) {
        outputFile += '.pdf';
      }
      final file = File(outputFile);
      await file.writeAsBytes(pdfBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الملف بنجاح: $outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _exportToImage() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final lessons = await isar.lessons.where().findAll();
    final assigned = lessons.where((l) => !l.isUnassigned).toList();
    final classrooms = assigned.map((l) => l.classroom.value).where((c) => c != null).toSet().toList();

    if (classrooms.isEmpty || _currentTabIndex >= classrooms.length) return;

    final currentClassroom = classrooms[_currentTabIndex];
    final key = _classroomKeys[currentClassroom!.id];

    if (key == null || key.currentContext == null) return;

    try {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ كـ صورة',
        fileName: 'timetable_' + currentClassroom.name + '.png',
        type: FileType.image,
        bytes: pngBytes,
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.png')) {
          outputFile += '.png';
        }
        final file = File(outputFile);
        await file.writeAsBytes(pngBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الصورة بنجاح: $outputFile'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصدير الصورة: ' + e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTimetableGrid(BuildContext context, List<Lesson> lessons, AppSettings settings) {
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
          Text('(' + unassigned.length.toString() + ' حصة بانتظار التوزيع)', style: const TextStyle(color: Colors.red)),
        ],
      );
    }

    return Column(
      children: [
        if (unassigned.isNotEmpty)
          Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(8.0),
            child: Text('يوجد ' + unassigned.length.toString() + ' دروس بانتظار التوزيع (تضارب أو لم يتم التوليد)',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        Expanded(
          child: DefaultTabController(
            length: classrooms.length,
            child: Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                Future.microtask(() {
                  tabController.addListener(() {
                    if (!tabController.indexIsChanging && mounted) {
                      setState(() {
                        _currentTabIndex = tabController.index;
                      });
                    }
                  });
                });
                return Column(
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
                          return _buildClassroomTable(c!.id, assigned.where((l) => l.classroom.value?.id == c.id).toList(), settings);
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassroomTable(int classroomId, List<Lesson> classLessons, AppSettings settings) {
    if (!_classroomKeys.containsKey(classroomId)) {
      _classroomKeys[classroomId] = GlobalKey();
    }
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: RepaintBoundary(
          key: _classroomKeys[classroomId],
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: DataTable(
              border: TableBorder.all(color: Colors.grey.shade300),
              headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
              columns: [
                const DataColumn(label: Text('اليوم / الحصة', style: TextStyle(fontWeight: FontWeight.bold))),
                for (int p = 0; p < settings.periodsPerDay; p++)
                  DataColumn(label: Text(PeriodMapper.toArabicName(p), style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                for (int d = 0; d < displayDays.length; d++)
                  DataRow(cells: [
                    DataCell(Text(displayDays[d], style: const TextStyle(fontWeight: FontWeight.bold))),
                    for (int p = 0; p < settings.periodsPerDay; p++)
                      DataCell(
                        _buildCell(classLessons, d, p),
                      ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(List<Lesson> classLessons, int dayIndex, int periodIndex) {
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
        final subjectName = lesson.subject.value?.name ?? 'غير محدد';
        final teacherName = lesson.teacher.value?.name ?? 'غير محدد';
        return Draggable<Lesson>(
          data: lesson,
          feedback: Material(
            child: Container(
              color: Colors.teal.withValues(alpha: 0.8),
              padding: const EdgeInsets.all(8),
              child: Text(subjectName, style: const TextStyle(color: Colors.white)),
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
                Text(subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                Text(teacherName,
                    style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}
