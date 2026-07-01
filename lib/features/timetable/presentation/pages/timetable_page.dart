import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';

import '../../../../core/models/lesson.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/teacher.dart';
import '../../../../core/providers/database_provider.dart';
import '../../domain/usecases/pdf_export_usecase.dart';
import '../providers/timetable_provider.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  final Map<int, GlobalKey> _classroomKeys = {};
  double _zoomLevel = 1.0;

  Future<void> _exportTeacherPdf() async {
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

      final teachers = await isar.collection<Teacher>().where().findAll();
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
            content: Text('تم حفظ الملف بنجاح: $outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final isar = await ref.read(isarDatabaseProvider.future);

      // Load and guarantee all links are resolved within a single transaction
      final List<Lesson> lessons = isar.txnSync(() {
        final all = isar.lessons.where().findAllSync();
        for (var lesson in all) {
          lesson.classroom.loadSync();
          lesson.subject.loadSync();
          lesson.teacher.loadSync();
        }
        return all;
      });

      final classRooms = await isar.collection<Classroom>().where().findAll();
      final settingsList = await isar.appSettings.where().findAll();
      final settings = settingsList.isNotEmpty
          ? settingsList.first
          : (AppSettings()..periodsPerDay = 7);

      final pdfUsecase = PdfExportUseCase();
      final pdfBytes =
          await pdfUsecase.generateTimetablePdf(lessons, classRooms, settings);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف PDF',
        fileName: 'timetable.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الملف بنجاح: $outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToImage() async {
    try {
      final boundary = _classroomKeys[0]?.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) throw 'تعذر العثور على منطقة الجدول لالتقاطها';

      // Build the image with high pixel ratio for 300DPI-like quality
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw 'فشل في تحويل الجدول إلى بيانات صورة';

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/timetable_export.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التقاط الجدول بنجاح، جاري المشاركة...'),
            backgroundColor: Colors.green,
          ),
        );
        await Share.shareXFiles([XFile(file.path)], text: 'جدول الدروس (صورة)');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصدير الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(timetableNotifierProvider);
    final settingsAsync =
        ref.watch(isarDatabaseProvider).whenData((isar) async {
      final settingsList = await isar.appSettings.where().findAll();
      return settingsList.isNotEmpty
          ? settingsList.first
          : (AppSettings()..periodsPerDay = 7);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الدروس'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير جدول الفصول كـ PDF',
            onPressed: _exportToPdf,
          ),
          IconButton(
            icon: const Icon(Icons.person_pin_circle),
            tooltip: 'تصدير جدول المدرسين كـ PDF',
            onPressed: _exportTeacherPdf,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'تصدير كـ صورة',
            onPressed: _exportToImage,
          ),
        ],
      ),
      body: lessonsAsync.when(
        data: (lessons) {
          return settingsAsync.when(
            data: (settingsFuture) => FutureBuilder<AppSettings>(
              future: settingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final settings =
                    snapshot.data ?? (AppSettings()..periodsPerDay = 7);
                return _buildTimetableGrid(context, lessons, settings);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('خطأ في جلب الإعدادات: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('حدث خطأ: $e')),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn_zoom_in",
            onPressed: () => setState(() => _zoomLevel += 0.1),
            tooltip: 'تكبير',
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "btn_zoom_out",
            onPressed: () =>
                setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 3.0)),
            tooltip: 'تصغير',
            child: const Icon(Icons.zoom_out),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: "btn_generate",
            onPressed: () {
              ref.read(timetableNotifierProvider.notifier).generateTimetable();
            },
            label: const Text('توليد الجدول'),
            icon: const Icon(Icons.autorenew),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(
      BuildContext context, List<Lesson> lessons, AppSettings settings) {
    final assigned = lessons.where((l) => !l.isUnassigned).toList();
    final unassigned = lessons.where((l) => l.isUnassigned).toList();

    final uniqueClassrooms = <int, Classroom>{};
    for (var lesson in assigned) {
      if (lesson.classroom.value != null) {
        uniqueClassrooms[lesson.classroom.value!.id] = lesson.classroom.value!;
      }
    }
    final classrooms = uniqueClassrooms.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    // ⚡ Bolt Optimization: O(n) pass to build a composite map for O(1) lookups
    // Replaces O(d * p * c * n) rendering complexity with O(d * p * c)
    final Map<String, Lesson> lessonMap = {};
    for (var lesson in assigned) {
      final cId = lesson.classroom.value?.id;
      if (cId != null) {
        lessonMap['${cId}_${lesson.dayIndex}_${lesson.periodIndex}'] = lesson;
      }
    }

    if (classrooms.isEmpty && unassigned.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(
              child:
                  Text('جميع الدروس المضافة لم يتم جدولتها بعد. اضغط توليد.')),
          const SizedBox(height: 16),
          Text('(${unassigned.length} حصة بانتظار التوزيع)',
              style: const TextStyle(color: Colors.red)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings.schoolName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              settings.schoolName,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
              textAlign: TextAlign.center,
            ),
          ),
        if (unassigned.isNotEmpty)
          Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(8.0),
            child: Text(
                'يوجد ${unassigned.length} دروس بانتظار التوزيع (تضارب أو لم يتم التوليد)',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
        Expanded(
          child: _buildMasterGrid(assigned, classrooms, settings, lessonMap),
        ),
      ],
    );
  }

  Widget _buildMasterGrid(List<Lesson> assigned, List<Classroom> classrooms,
      AppSettings settings, Map<String, Lesson> lessonMap) {
    if (classrooms.isEmpty) {
      return const Center(child: Text('لا يوجد بيانات لعرضها.'));
    }

    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();
    final int masterKeyId = 0; // use 0 for the master grid
    if (!_classroomKeys.containsKey(masterKeyId)) {
      _classroomKeys[masterKeyId] = GlobalKey();
    }

    // Build Rows
    List<DataRow> rows = [];
    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < settings.periodsPerDay; p++) {
        List<DataCell> cells = [];

        // Vertical merging logic: only show day name on the first period of the day
        if (p == 0) {
          // This cell would ideally span vertically, but DataTable does not support rowspans.
          // We can simulate it by showing the text only on the first row, or center it, etc.
          // For a true Master Grid in flutter DataTable, we just place the day on the first cell.
          cells.add(DataCell(Container(
            alignment: Alignment.center,
            child: Text(displayDays[d],
                style: const TextStyle(fontWeight: FontWeight.bold)),
          )));
        } else {
          cells.add(DataCell(const SizedBox.shrink()));
        }

        // Sequence column
        cells.add(DataCell(Container(
          alignment: Alignment.center,
          child: Text((p + 1).toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        )));

        // Classrooms columns
        for (var classroom in classrooms) {
          final lesson = lessonMap['${classroom.id}_${d}_${p}'];
          cells.add(DataCell(_buildCell(lesson, classroom, d, p)));
        }

        rows.add(DataRow(
          color: p % 2 == 0
              ? WidgetStateProperty.all(Colors.grey.shade50)
              : WidgetStateProperty.all(Colors.white),
          cells: cells,
        ));
      }
    }

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20.0),
      minScale: 0.1,
      maxScale: 5.0,
      scaleEnabled: true,
      panEnabled: true,
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _classroomKeys[masterKeyId],
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Transform.scale(
                  scale: _zoomLevel,
                  alignment: Alignment.topRight,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16.0),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: DataTable(
                        border: TableBorder.all(color: Colors.grey.shade400),
                        headingRowColor:
                            WidgetStateProperty.all(Colors.teal.shade100),
                        columnSpacing: 8.0,
                        horizontalMargin: 8.0,
                        dataRowMinHeight: 45.0,
                        dataRowMaxHeight: 60.0,
                        headingRowHeight: 45.0,
                        columns: [
                          const DataColumn(
                              label: Text('اليوم',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataColumn(
                              label: Text('الدرس',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          for (var classroom in classrooms)
                            DataColumn(
                                label: Text(classroom.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                        ],
                        rows: rows,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCell(Lesson? lesson, Classroom classroom, int dayIndex, int periodIndex) {
    if (lesson == null) {
      return DragTarget<Lesson>(
        onWillAcceptWithDetails: (details) {
          final incoming = details.data;

          if (incoming.isPinned) return false;

          // Basic constraint checks for visual feedback without full async DB read
          // 1. Same subject already has this period allowed
          if (incoming.subject.value != null && incoming.subject.value!.allowedPeriods.isNotEmpty && !incoming.subject.value!.allowedPeriods.contains(periodIndex)) return false;
          // 2. Teacher unavailable days
          if (incoming.teacher.value != null && incoming.teacher.value!.unavailableDays.contains(dayIndex)) return false;

          return true;
        },
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
              color: candidateData.isNotEmpty
                  ? Colors.green.withValues(alpha: 0.3)
                  : (rejectedData.isNotEmpty ? Colors.red.withValues(alpha: 0.3) : Colors.transparent),
            ),
          );
        },
      );
    }

    return DragTarget<Lesson>(
      onWillAcceptWithDetails: (details) {
        final incoming = details.data;
        return incoming.id != lesson.id && !lesson.isPinned;
      },
      onAcceptWithDetails: (details) async {
        final incoming = details.data;
        final (success, errorMessage) = await ref
            .read(timetableNotifierProvider.notifier)
            .swapLessons(incoming, lesson);

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage ?? 'حدث خطأ أثناء التبديل'),
              backgroundColor: Colors.red,
            ),
          );
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
              child: Text(subjectName,
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
          childWhenDragging:
              Container(color: Colors.grey.shade200, width: 80, height: 40),
          child: InkWell(
            onLongPress: () {
              ref.read(timetableNotifierProvider.notifier).togglePin(lesson);
            },
            child: Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: lesson.isPinned
                    ? Colors.orange.shade100
                    : (candidateData.isNotEmpty ? Colors.red.shade100 : Colors.teal.shade50), // Show invalid by default on hover, valid handled elsewhere
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
          ),
        );
      },
    );
  }
}
