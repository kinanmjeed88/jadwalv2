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
import '../../domain/usecases/excel_export_usecase.dart';
import '../providers/timetable_provider.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  final Map<int, GlobalKey> _classroomKeys = {};
  final GlobalKey _exportKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

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

  Future<void> _exportToExcel() async {
    final settingsAsync = ref.read(timetableNotifierProvider);
    final isarAsync = ref.read(isarDatabaseProvider);

    if (settingsAsync is! AsyncData || isarAsync is! AsyncData) return;

    final lessons = settingsAsync.value ?? [];
    final isar = isarAsync.value;
    if (isar == null) return;

    final classrooms = await isar.classrooms.where().findAll();
    final settingsList = await isar.appSettings.where().findAll();
    final settings = settingsList.isNotEmpty ? settingsList.first : (AppSettings()..periodsPerDay = 7);

    final usecase = ExcelExportUseCase();
    final excelBytes = await usecase.generateTimetableExcel(lessons, classrooms, settings);

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/timetable_export.xlsx');
    await file.writeAsBytes(excelBytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير الجدول إلى Excel بنجاح')));
      Share.shareXFiles([XFile(file.path)], text: 'جدول الفصول الأسبوعي');
    }
  }

  Future<void> _exportToImage() async {
    try {
      final boundary = _exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) throw 'تعذر العثور على منطقة الجدول لالتقاطها';

      // Build the image with high pixel ratio for 300DPI-like quality
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
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
    final isarAsync = ref.watch(isarDatabaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الدروس'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'تصدير كـ Excel',
            onPressed: _exportToExcel,
          ),
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
      body: Stack(
        children: [
          lessonsAsync.when(
            data: (lessons) {
              return isarAsync.when(
                data: (isar) => FutureBuilder(
                  future: Future.wait([
                    isar.appSettings.where().findAll(),
                    isar.classrooms.where().findAll(),
                  ]),
                  builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final settingsList = snapshot.data?[0] as List<AppSettings>?;
                    final settings = (settingsList != null && settingsList.isNotEmpty)
                        ? settingsList.first
                        : (AppSettings()..periodsPerDay = 7);
                    final classrooms = (snapshot.data?[1] as List<Classroom>? ?? [])
                        ..sort((a, b) => a.id.compareTo(b.id));

                    return _buildTimetableGrid(context, lessons, classrooms, settings);
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('خطأ في جلب الإعدادات: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('حدث خطأ: $e')),
          ),

          // Off-screen export widget that is painted but invisible and unconstrained
          lessonsAsync.maybeWhen(
            data: (lessons) => isarAsync.maybeWhen(
              data: (isar) => FutureBuilder(
                future: Future.wait([
                  isar.appSettings.where().findAll(),
                  isar.classrooms.where().findAll(),
                ]),
                builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  final settingsList = snapshot.data?[0] as List<AppSettings>?;
                  final settings = (settingsList != null && settingsList.isNotEmpty)
                      ? settingsList.first
                      : (AppSettings()..periodsPerDay = 7);
                  final classrooms = (snapshot.data?[1] as List<Classroom>? ?? [])
                      ..sort((a, b) => a.id.compareTo(b.id));

                  return Positioned(
                    top: -10000,
                    left: -10000,
                    child: IgnorePointer(
                        child: UnconstrainedBox(
                          clipBehavior: Clip.hardEdge,
                        child: IntrinsicHeight(
                          child: _buildExportGrid(lessons, classrooms, settings),
                        ),
                      ),
                    ),
                  );
                },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn_zoom_in",
            onPressed: () {
              final Matrix4 matrix = _transformationController.value.clone();
              final double scale = 1.2;
              matrix[0] *= scale;
              matrix[5] *= scale;
              _transformationController.value = matrix;
            },
            tooltip: 'تكبير',
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "btn_zoom_out",
            onPressed: () {
              final Matrix4 matrix = _transformationController.value.clone();
              final double scale = 1 / 1.2;
              matrix[0] *= scale;
              matrix[5] *= scale;
              _transformationController.value = matrix;
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

  Widget _buildExportGrid(List<Lesson> lessons, List<Classroom> classrooms, AppSettings settings) {
    final assigned = lessons.where((l) => !l.isUnassigned).toList();

    final Map<String, Lesson> lessonMap = {};
    for (var lesson in assigned) {
      final cId = lesson.classroom.value?.id;
      if (cId != null) {
        lessonMap['${cId}_${lesson.dayIndex}_${lesson.periodIndex}'] = lesson;
      }
    }

    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final displayDays = days.take(settings.daysPerWeek).toList();

    List<TableRow> rows = [];

    // Header Row
    List<Widget> headerCells = [
      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('اليوم', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('الدرس', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
    ];

    for (int c = 0; c < classrooms.length; c++) {
      var classroom = classrooms[c];
      bool isFirstInGrade = false;
      if (c == 0 || classrooms[c - 1].grade != classroom.grade) {
        isFirstInGrade = true;
      }
      bool isLastInGrade = false;
      if (c == classrooms.length - 1 || classrooms[c + 1].grade != classroom.grade) {
        isLastInGrade = true;
      }
      headerCells.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            border: Border(
              right: isFirstInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
              left: isLastInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
            ),
          ),
          child: Center(
            child: Text(classroom.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )
      );
    }

    rows.add(TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ));
        } else {
          cells.add(const SizedBox.shrink());
        }

        cells.add(Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text((p + 1).toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ));

        for (int c = 0; c < classrooms.length; c++) {
          var classroom = classrooms[c];
          bool isFirstInGrade = false;
          if (c == 0 || classrooms[c - 1].grade != classroom.grade) {
            isFirstInGrade = true;
          }
          bool isLastInGrade = false;
          if (c == classrooms.length - 1 || classrooms[c + 1].grade != classroom.grade) {
            isLastInGrade = true;
          }

          final lesson = lessonMap['${classroom.id}_${d}_${p}'];
          if (lesson != null) {
            final subjectName = lesson.subject.value?.name ?? 'غير محدد';
            final teacherName = lesson.teacher.value?.name.split(' ').first ?? 'فارغ';
            cells.add(
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  border: Border(
                    right: isFirstInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
                    left: isLastInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(subjectName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(teacherName,
                        style: const TextStyle(fontSize: 8, color: Colors.grey),
                        textAlign: TextAlign.center),
                  ],
                ),
              )
            );
          } else {
            cells.add(
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: isFirstInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
                    left: isLastInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
                  ),
                ),
                child: const SizedBox(height: 40),
              )
            );
          }
        }

        rows.add(TableRow(
          decoration: BoxDecoration(
            color: p % 2 == 0 ? Colors.grey.shade50 : Colors.white
          ),
          children: cells,
        ));
      }
    }

    final now = DateTime.now();
    int startYear = now.month >= 9 ? now.year : now.year - 1;
    final academicYear = '$startYear/${startYear + 1}';

    return RepaintBoundary(
      key: _exportKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24.0),
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      settings.schoolName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(children: [
                      const Text(
                        'جدول الدروس الأسبوعي',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'العام الدراسي: $academicYear',
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'المدير : ${settings.principalName}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                ),
                child: Table(
                  border: TableBorder.all(color: Colors.black26),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: IntrinsicColumnWidth(),
                  },
                  children: rows,
                ),
              ),
            ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableGrid(
      BuildContext context, List<Lesson> lessons, List<Classroom> classrooms, AppSettings settings) {
    final assigned = lessons.where((l) => !l.isUnassigned).toList();
    final unassigned = lessons.where((l) => l.isUnassigned).toList();

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

    // Build Rows for Table
    List<TableRow> rows = [];

    List<Widget> headerCells = [
      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('اليوم', style: TextStyle(fontWeight: FontWeight.bold)))),
      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('الدرس', style: TextStyle(fontWeight: FontWeight.bold)))),
    ];

    for (int c = 0; c < classrooms.length; c++) {
      var classroom = classrooms[c];
      bool isFirstInGrade = false;
      if (c == 0 || classrooms[c - 1].grade != classroom.grade) {
        isFirstInGrade = true;
      }
      bool isLastInGrade = false;
      if (c == classrooms.length - 1 || classrooms[c + 1].grade != classroom.grade) {
        isLastInGrade = true;
      }
      headerCells.add(
        Container(
          decoration: BoxDecoration(
            border: Border(
              right: isFirstInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
              left: isLastInGrade ? const BorderSide(color: Colors.black, width: 3.0) : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Center(
            child: Text(classroom.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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

        // Sequence column
        cells.add(Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text((p + 1).toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ));

        // Classrooms columns
        for (int c = 0; c < classrooms.length; c++) {
          var classroom = classrooms[c];
          bool isFirstInGrade = false;
          if (c == 0 || classrooms[c - 1].grade != classroom.grade) {
            isFirstInGrade = true;
          }
          bool isLastInGrade = false;
          if (c == classrooms.length - 1 || classrooms[c + 1].grade != classroom.grade) {
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
            // السر الأول: تثبيت العرض لكي لا ينهار الجدول
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

    return LayoutBuilder(
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
                clipBehavior: Clip.hardEdge,
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(150.0),
                  minScale: 0.1,
                  maxScale: 5.0,
                  constrained: false, // السر الثاني: السماح للمحتوى بأخذ مساحته
                  scaleEnabled: true,
                  panEnabled: true,
                  alignment: Alignment.center,
                  transformationController: _transformationController,
                  // السر الثالث: إزالة SingleChildScrollView الكارثي واستخدام ConstrainedBox فقط
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
        final subjectName = lesson.subject.value?.name ?? 'غير محدد';
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
