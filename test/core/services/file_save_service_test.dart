import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal_v2/core/services/file_save_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('file_save_service_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String insideTemp(String name) => '${tempDir.path}/$name';

  group('FileSaveService.ensureCanonicalExtension', () {
    test('appends the canonical extension when the user typed none', () {
      expect(
        FileSaveService.ensureCanonicalExtension(r'C:\Docs\timetable', 'pdf'),
        r'C:\Docs\timetable.pdf',
      );
    });

    test('does not duplicate an already-present extension', () {
      expect(
        FileSaveService.ensureCanonicalExtension(
            r'C:\Docs\timetable.pdf', 'pdf'),
        r'C:\Docs\timetable.pdf',
      );
    });

    test('is case-insensitive like Windows file systems', () {
      expect(
        FileSaveService.ensureCanonicalExtension(
            r'C:\Docs\timetable.PDF', 'pdf'),
        r'C:\Docs\timetable.PDF',
      );
    });

    test('tolerates a leading dot in the requested extension', () {
      expect(
        FileSaveService.ensureCanonicalExtension(r'C:\Docs\timetable', '.pdf'),
        r'C:\Docs\timetable.pdf',
      );
    });

    test('appends when a foreign extension was typed', () {
      expect(
        FileSaveService.ensureCanonicalExtension(r'C:\Docs\timetable.txt', 'pdf'),
        r'C:\Docs\timetable.txt.pdf',
      );
    });
  });

  group('FileSaveService.saveBytes (desktop flow)', () {
    test('returns FileSaveCancelled when the dialog is dismissed', () async {
      const service = FileSaveService(
        chooser: _cancellationChooser,
        writer: _countingWriter,
      );

      final outcome = await service.saveBytes(
        dialogTitle: 'حفظ',
        fileName: 'report.pdf',
        allowedExtensions: const ['pdf'],
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );

      expect(outcome, isA<FileSaveCancelled>());
      expect(lastWrittenPath, isNull);
    });

    test('persists bytes, enforces extension and verifies the file', () async {
      final pickedPath = insideTemp('جدول_المعلمين_حصة_٣'); // no extension
      final chooser = _fixedChooser(pickedPath);
      final service = FileSaveService(chooser: chooser);

      final payload = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));

      final outcome = await service.saveBytes(
        dialogTitle: 'حفظ',
        fileName: 'teachers_timetable.pdf',
        allowedExtensions: const ['pdf'],
        bytes: payload,
      );

      expect(outcome, isA<FileSaved>());
      final savedPath = (outcome as FileSaved).path;
      expect(savedPath, endsWith('.pdf'));

      final written = File(savedPath);
      expect(written.existsSync(), isTrue);
      expect(await written.readAsBytes(), payload);
    });

    test('keeps the extension when the picked path already has it', () async {
      final pickedPath = insideTemp('teachers_timetable.pdf');
      final chooser = _fixedChooser(pickedPath);
      final service = FileSaveService(chooser: chooser);

      final outcome = await service.saveBytes(
        dialogTitle: 'حفظ',
        fileName: 'teachers_timetable.pdf',
        allowedExtensions: const ['pdf'],
        bytes: Uint8List.fromList(const [10, 20]),
      );

      expect((outcome as FileSaved).path, equals(pickedPath));
      expect(File(pickedPath).existsSync(), isTrue);
    });

    test('reports FileSaveFailed when no writer can persist the bytes', () async {
      final chooser = _fixedChooser(insideTemp('wont_write.pdf'));
      final service = FileSaveService(
        chooser: chooser,
        writer: _explodingWriter,
      );

      final outcome = await service.saveBytes(
        dialogTitle: 'حفظ',
        fileName: 'report.pdf',
        allowedExtensions: const ['pdf'],
        bytes: Uint8List.fromList(const [1]),
      );

      expect(outcome, isA<FileSaveFailed>());
      expect((outcome as FileSaveFailed).error.toString(),
          contains('disk exploded'));
    });

    test('reports FileSaveFailed when verification detects a short write',
        () async {
      final chooser = _fixedChooser(insideTemp('truncated.pdf'));
      final service = FileSaveService(
        chooser: chooser,
        writer: _truncatingWriter,
      );

      final outcome = await service.saveBytes(
        dialogTitle: 'حفظ',
        fileName: 'report.pdf',
        allowedExtensions: const ['pdf'],
        bytes: Uint8List.fromList(const [1, 2, 3, 4, 5]),
      );

      expect(outcome, isA<FileSaveFailed>());
      expect(
        (outcome as FileSaveFailed).error.toString(),
        contains('file size mismatch'),
      );
    });

    test('reports FileSaveFailed when the chooser itself throws', () async {
      const service = FileSaveService(chooser: _explodingChooser);

      final outcome = await service.saveBytes(
        dialogTitle: 'حفظ',
        fileName: 'report.pdf',
        allowedExtensions: const ['pdf'],
        bytes: Uint8List.fromList(const [1]),
      );

      expect(outcome, isA<FileSaveFailed>());
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

String? lastWrittenPath;

Future<String?> _cancellationChooser({
  String dialogTitle = '',
  String fileName = '',
  List<String> allowedExtensions = const [],
  Uint8List? bytes,
}) async =>
    null;

SaveTargetChooser _fixedChooser(String path) => ({
      String dialogTitle = '',
      String fileName = '',
      List<String> allowedExtensions = const [],
      Uint8List? bytes,
    }) async =>
        path;

Future<String?> _explodingChooser({
  String dialogTitle = '',
  String fileName = '',
  List<String> allowedExtensions = const [],
  Uint8List? bytes,
}) async =>
    throw StateError('dialog is unavailable');

Future<void> _countingWriter(String path, Uint8List bytes) async {
  lastWrittenPath = path;
}

Future<void> _explodingWriter(String path, Uint8List bytes) {
  throw const FileSystemException('disk exploded');
}

Future<void> _truncatingWriter(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes.sublist(0, 1), flush: true);
}
