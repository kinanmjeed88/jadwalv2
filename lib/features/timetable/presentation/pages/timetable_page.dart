import 'package:isar/isar.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/lesson.dart';
import '../../../../core/models/classroom.dart';
import '../../../../core/models/settings.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/exceptions/timetable_generation_exception.dart';
import '../providers/timetable_provider.dart';
import '../mappers/conflict_message_mapper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/usecases/excel_export_usecase.dart';
import '../../domain/usecases/pdf_export_usecase.dart';

extension StringExtension on String {
  String cleanSubjectName() {
    return replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }
}

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  final Map<int, GlobalKey> _classroomKeys = {};
  final TransformationController _transformationController = TransformationController();

  Future<void> _exportToExcel() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final settings = await isar.appSettings.where().findFirst() ?? AppSettings();
    final lessons = await isar.lessons.where().findAll();
    final classrooms = await isar.classrooms.where().findAll();

    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }

    final excelData = await ExcelExportUseCase().generateTimetableExcel(
      lessons,
      classrooms,
      settings,
    );

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'timetable.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(excelData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير الجدول إلى Excel بنجاح')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final settings = await isar.appSettings.where().findFirst() ?? AppSettings();
    final lessons = await isar.lessons.where().findAll();
    final classrooms = await isar.classrooms.where().findAll();

    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }

    final pdfData = await PdfExportUseCase().generateTimetablePdf(
      lessons,
      classrooms,
      settings,
    );

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'timetable.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(pdfData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير الجداول إلى PDF بنجاح')),
        );
      }
    }
  }

  Future<void> _sharePDF() async {
    final isar = await ref.read(isarDatabaseProvider.future);
    final settings = await isar.appSettings.where().findFirst() ?? AppSettings();
    final lessons = await isar.lessons.where().findAll();
    final classrooms = await isar.classrooms.where().findAll();

    for (var lesson in lessons) {
      lesson.classroom.loadSync();
      lesson.subject.loadSync();
      lesson.teacher.loadSync();
    }

    final pdfData = await PdfExportUseCase().generateTimetablePdf(
      lessons,
      classrooms,
      settings,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/timetable.pdf');
    await file.writeAsBytes(pdfData);

    Share.shareXFiles([XFile(file.path)], text: 'جداول الحصص المدرسية');
  }

  Future<void> _exportAsImage(int classroomId, String classroomName) async {
    final key = _classroomKeys[classroomId];
    if (key == null) return;

    try {
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (hasAccess) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/timetable_$classroomName.png');
        await file.writeAsBytes(pngBytes);
        await Gal.putImage(file.path, album: 'Jadwal');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حفظ جدول $classroomName كصورة في المعرض')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى منح صلاحية الوصول إلى المعرض لحفظ الصورة')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ الصورة: $e')),
        );
      }
    }
  }

  Future<void> _shareAsImage(int classroomId, String classroomName) async {
     final key = _classroomKeys[classroomId];
    if (key == null) return;

    try {
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/timetable_$classroomName.png');
      await file.writeAsBytes(pngBytes);

      Share.shareXFiles([XFile(file.path)], text: 'جدول حصص $classroomName');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء مشاركة الصورة: $e')),
        );
      }
    }
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1.2);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1 / 1.2);
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(timetableNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الحصص'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة PDF',
            onPressed: _sharePDF,
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filePdf),
            tooltip: 'تصدير PDF',
            onPressed: _exportToPDF,
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.fileExcel),
            tooltip: 'تصدير Excel',
            onPressed: _exportToExcel,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: lessonsAsync.when(
        data: (lessons) {
          return FutureBuilder<AppSettings>(
            future: ref.read(isarDatabaseProvider.future).then((isar) => isar.appSettings.where().findFirst().then((value) => value ?? AppSettings())),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final settings = snapshot.data!;

              return FutureBuilder<List<Classroom>>(
                future: ref.read(isarDatabaseProvider.future).then((isar) => isar.classrooms.where().findAll()),
                builder: (context, classroomSnapshot) {
                  if (classroomSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final classrooms = classroomSnapshot.data!;

                  if (classrooms.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  classrooms.sort((a, b) {
                     final int gradeCmp = (a.grade ?? '').compareTo(b.grade ?? '');
                     if (gradeCmp != 0) return gradeCmp;
                     return a.name.compareTo(b.name);
                  });

                  for (var c in classrooms) {
                    _classroomKeys.putIfAbsent(c.id, () => GlobalKey());
                  }

                  return _buildTimetableGrid(lessons, classrooms, settings);
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري توليد الجدول، قد يستغرق الأمر بعض الوقت...'),
            ],
          ),
        ),
        error: (err, stack) {
          if (err is TimetableGenerationException) {
             return _buildEmptyState(context);
          }
          return Center(child: Text('حدث خطأ: $err'));
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn_zoom_in",
            onPressed: () {
              final currentScale = _transformationController.value.getMaxScaleOnAxis();
              final newScale = (currentScale + 0.1).clamp(0.1, 5.0);
              _transformationController.value = Matrix4.identity()..scale(newScale);
            },
            tooltip: 'تكبير',
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "btn_zoom_out",
            onPressed: () {
              final currentScale = _transformationController.value.getMaxScaleOnAxis();
              final newScale = (currentScale - 0.1).clamp(0.1, 5.0);
              _transformationController.value = Matrix4.identity()..scale(newScale);
            },
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('لا يوجد جدول مولد حالياً'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await ref.read(timetableNotifierProvider.notifier).generateTimetable();
              } catch (e) {
                if (!mounted) return;
                if (e is TimetableGenerationException) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تعذر توليد الجدول للأسباب التالية:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      content: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: e.reasons.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text('• ${ConflictMessageMapper.toArabicMessage(r)}', style: const TextStyle(fontSize: 16, height: 1.5)),
                            )).toList(),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حسناً', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('خطأ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      content: Text(e.toString(), style: const TextStyle(fontSize: 16, height: 1.5)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حسناً', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            label: const Text('توليد الجدول'),
            icon: const Icon(Icons.autorenew),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(List<Lesson> lessons, List<Classroom> classrooms, AppSettings settings) {
    if (classrooms.isEmpty) return const Center(child: Text('لا توجد فصول دراسية'));

    final masterKeyId = classrooms.first.id;
    if (!_classroomKeys.containsKey(masterKeyId)) {
        _classroomKeys[masterKeyId] = GlobalKey();
    }

    final displayDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'].sublist(0, settings.daysPerWeek);

    Map<String, Lesson> lessonMap = {};
    for (var lesson in lessons) {
      if (lesson.dayIndex != null && lesson.periodIndex != null && lesson.classroom.value != null) {
        lessonMap['${lesson.classroom.value!.id}_${lesson.dayIndex}_${lesson.periodIndex}'] = lesson;
      }
    }

    List<TableRow> rows = [];

    List<Widget> headerCells = [
      Container(padding: const EdgeInsets.all(8.0), color: Colors.teal.shade200, child: const Center(child: Text('اليوم', style: TextStyle(fontWeight: FontWeight.bold)))),
      Container(padding: const EdgeInsets.all(8.0), color: Colors.teal.shade200, child: const Center(child: Text('الحصة', style: TextStyle(fontWeight: FontWeight.bold)))),
    ];

    for (int c = 0; c < classrooms.length; c++) {
      var classroom = classrooms[c];
      bool isFirstInGrade = false;
      if (c == 0 || ((classrooms[c - 1].grade as String?) ?? '') != ((classroom.grade as String?) ?? '')) {
        isFirstInGrade = true;
      }
      bool isLastInGrade = false;
      if (c == classrooms.length - 1 || ((classrooms[c + 1].grade as String?) ?? '') != ((classroom.grade as String?) ?? '')) {
        isLastInGrade = true;
      }

      headerCells.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.teal.shade200,
            border: Border(
              right: isFirstInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
              left: isLastInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Center(
            child: Text((classroom.name as String?) ?? 'فصل', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        )
      );
    }

    rows.add(TableRow(
      decoration: BoxDecoration(color: Colors.teal.shade100),
      children: headerCells
    ));

    for (int d = 0; d < displayDays.length; d++) {
      for (int p = 0; p < settings.periodsPerDay; p++) {
        List<Widget> cells = [];

        if (p == 0) {
          cells.add(Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Text(displayDays[d],
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ));
        } else {
          cells.add(const SizedBox.shrink());
        }

        cells.add(Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text((p + 1).toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ));

        for (int c = 0; c < classrooms.length; c++) {
          var classroom = classrooms[c];
          bool isFirstInGrade = false;
          if (c == 0 || ((classrooms[c - 1].grade as String?) ?? '') != ((classroom.grade as String?) ?? '')) {
            isFirstInGrade = true;
          }
          bool isLastInGrade = false;
          if (c == classrooms.length - 1 || ((classrooms[c + 1].grade as String?) ?? '') != ((classroom.grade as String?) ?? '')) {
            isLastInGrade = true;
          }
          final lesson = lessonMap['${classroom.id}_${d}_${p}'];
          cells.add(_buildCell(lesson, classroom, d, p, isFirstInGrade, isLastInGrade));
        }

        rows.add(TableRow(
          decoration: BoxDecoration(
            color: p % 2 == 0 ? Colors.grey.shade50 : Colors.white
          ),
          children: cells,
        ));
      }
    }

    Widget buildDataTable() {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade700, width: 1.5),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            defaultColumnWidth: const FixedColumnWidth(150.0), 
            columnWidths: const {
              0: FixedColumnWidth(60.0), 
              1: FixedColumnWidth(60.0), 
            },
            children: rows,
          ),
        ),
      );
    }

    final unassigned = lessons.where((l) => l.isUnassigned).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          child: LayoutBuilder(
            builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: -9999,
              left: -9999,
              child: IgnorePointer(
                child: RepaintBoundary(
                  key: _classroomKeys[masterKeyId],
                  child: buildDataTable(),
                ),
              ),
            ),
            
            Positioned.fill(
              child: Container(
                color: Colors.white,
                
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(5000.0),
                  minScale: 0.1,
                  maxScale: 5.0,
                  constrained: false,
                  scaleEnabled: true,
                  panEnabled: true,
                  alignment: Alignment.center,
                  transformationController: _transformationController,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: buildDataTable(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
        ),
      ],
    );
  }

  Widget _buildCell(Lesson? lesson, Classroom classroom, int dayIndex, int periodIndex, bool isFirstInGrade, bool isLastInGrade) {
    if (lesson == null) {
      return DragTarget<Lesson>(
        onWillAcceptWithDetails: (details) {
          final incoming = details.data;

          if (incoming.isPinned) return false;

          if (incoming.subject.value != null && (incoming.subject.value?.allowedPeriods.isNotEmpty ?? false) && !(incoming.subject.value?.allowedPeriods.contains(periodIndex) ?? false)) return false;
          if (incoming.teacher.value != null && (incoming.teacher.value?.unavailableDays.contains(dayIndex) ?? false)) return false;

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
            height: 50,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? Colors.green.withValues(alpha: 0.3)
                  : (rejectedData.isNotEmpty ? Colors.red.withValues(alpha: 0.3) : Colors.transparent),
              border: Border(
                right: isFirstInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
                left: isLastInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
              ),
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
        final subjectName = (lesson.subject.value?.name ?? 'غير محدد').cleanSubjectName();
        final teacherName = lesson.teacher.value?.name.split(' ').first ?? 'فارغ';
        return LongPressDraggable<Lesson>(
          data: lesson,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.teal.withValues(alpha: 0.8),
              padding: const EdgeInsets.all(8),
              child: Text(subjectName,
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
          childWhenDragging:
              Container(color: Colors.grey.shade200, height: 50),
          child: GestureDetector(
            onDoubleTap: () {
              ref.read(timetableNotifierProvider.notifier).togglePin(lesson);
            },
            child: Container(
              height: 50,
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: lesson.isPinned
                    ? Colors.orange.shade100
                    : (candidateData.isNotEmpty ? Colors.red.shade100 : Colors.transparent),
                border: Border(
                  right: isFirstInGrade
                    ? const BorderSide(color: Colors.black, width: 3.0)
                    : (lesson.isPinned ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none),
                  left: isLastInGrade
                    ? const BorderSide(color: Colors.black, width: 3.0)
                    : (lesson.isPinned ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none),
                  top: lesson.isPinned ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
                  bottom: lesson.isPinned ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(subjectName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(teacherName,
                            style: const TextStyle(fontSize: 8, color: Colors.grey),
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
