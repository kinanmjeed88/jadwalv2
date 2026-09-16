import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the shared [FileSaveService] instance.
///
/// The service is stateless, so a single construction for the whole app is
/// correct and keeps call sites free of manual wiring.
final fileSaveServiceProvider = Provider<FileSaveService>(
  (ref) => const FileSaveService(),
);

/// Asks the user where a file should be saved and returns the chosen path, or
/// `null` when the user cancels.
///
/// On desktop platforms this is *only* a location choice (the documented
/// contract of `file_picker` on Windows/Linux/macOS); persistence is owned by
/// [FileSaveService]. On Android/iOS the plugin persists [bytes] itself, which
/// is its documented mobile contract.
typedef SaveTargetChooser = Future<String?> Function({
  String dialogTitle,
  String fileName,
  List<String> allowedExtensions,
  Uint8List? bytes,
});

/// Strategy used by [FileSaveService] to physically persist bytes.
///
/// Injectable so tests can simulate disk failures without touching the real
/// file system.
typedef FileBytesWriter = Future<void> Function(String path, Uint8List bytes);

/// Outcome of a save request, modelled as a sealed type so every call site is
/// forced by the compiler to handle all three possibilities.
sealed class FileSaveOutcome {
  const FileSaveOutcome();
}

/// The bytes were written and verified at [path].
final class FileSaved extends FileSaveOutcome {
  const FileSaved(this.path);

  /// Absolute path of the written, verified file.
  final String path;

  @override
  String toString() => 'FileSaved($path)';
}

/// The user dismissed the save dialog without choosing a location.
final class FileSaveCancelled extends FileSaveOutcome {
  const FileSaveCancelled();

  @override
  String toString() => 'FileSaveCancelled()';
}

/// Saving failed after a location was chosen (or could not be requested at
/// all). Never reported as success: callers must surface [error] to the user.
final class FileSaveFailed extends FileSaveOutcome {
  const FileSaveFailed(this.error);

  /// The original error that made persistence impossible.
  final Object error;

  @override
  String toString() => 'FileSaveFailed($error)';
}

/// Central, version-agnostic owner of "export bytes to a user-picked file".
///
/// ### Why this exists
///
/// `file_picker` ≤ 9.1.x (every 8.x release) **does not save files on desktop
/// platforms**: `saveFile(bytes: …)` ignores `bytes` and merely returns a
/// path from the native save dialog — explicit, documented behaviour. Only
/// `file_picker` ≥ 9.2.0 writes bytes on the caller's behalf.
///
/// This app must run on toolchains (notably the Windows 7 branch pinned to
/// Flutter 3.16.9 / Dart 3.2) that cannot resolve `file_picker` ≥ 9.2.0, so
/// delegating persistence to the plugin produces exactly this defect: the UI
/// announces "saved successfully" while nothing was ever written.
///
/// The robust contract that holds for **every** plugin version and platform is
/// therefore:
///
/// 1. Use the plugin only to *choose a destination* (desktop) — or to persist
///    via SAF/UIDocumentPicker on mobile, where `bytes` is honoured everywhere.
/// 2. Let this service persist the bytes itself on desktop: normalise the
///    extension, write atomically (temp file + rename), and verify the result
///    before reporting success.
class FileSaveService {
  const FileSaveService({
    SaveTargetChooser chooser = _pickSaveLocationViaFilePicker,
    FileBytesWriter writer = _writeAtomicFile,
  })  : _chooseSaveTarget = chooser,
        _writeBytes = writer;

  /// Shows the native save dialog and returns the chosen absolute path, or
  /// `null` when the user cancels ([FileSaveCancelled] is returned on cancel).
  final SaveTargetChooser _chooseSaveTarget;

  /// Physically writes the file. Defaults to an atomic write (temp file in the
  /// target directory, flush, then rename over the destination).
  final FileBytesWriter _writeBytes;

  /// Saves [bytes] under [fileName] after letting the user pick a location.
  ///
  /// * [dialogTitle] – title of the native save dialog.
  /// * [fileName] – default file name suggested to the user. Its extension is
  ///   the canonical one for the content and will be enforced on the result.
  /// * [allowedExtensions] – extension filter for the dialog; the first entry
  ///   is authoritative when normalising the final path.
  ///
  /// Never throws: every failure is reported as [FileSaveFailed] so that UI
  /// code can show truthful feedback in one place.
  Future<FileSaveOutcome> saveBytes({
    required String dialogTitle,
    required String fileName,
    required List<String> allowedExtensions,
    required Uint8List bytes,
  }) async {
    assert(
      allowedExtensions.isNotEmpty,
      'allowedExtensions must name at least the canonical extension.',
    );

    final bool mobileHandledByPlugin = Platform.isAndroid || Platform.isIOS;

    try {
      final String? pickedPath = await _chooseSaveTarget(
        dialogTitle: dialogTitle,
        fileName: fileName,
        allowedExtensions: allowedExtensions,
        // On Android/iOS the plugin persists the bytes itself (its documented
        // mobile contract). On desktop passing bytes is either ignored
        // (file_picker ≤ 9.1.x) or redundant (≥ 9.2.0), so we stay explicit
        // and persist below for full control and verifiability.
        bytes: mobileHandledByPlugin ? bytes : null,
      );

      if (pickedPath == null || pickedPath.trim().isEmpty) {
        return const FileSaveCancelled();
      }

      if (mobileHandledByPlugin) {
        // The plugin owns persistence on mobile (Android SAF / iOS document
        // picker). A non-null path means the platform granted the write.
        return FileSaved(pickedPath.trim());
      }

      final String targetPath =
          ensureCanonicalExtension(pickedPath.trim(), allowedExtensions.first);

      await _writeBytes(targetPath, bytes);

      _verifyWrite(targetPath, bytes.length);

      return FileSaved(targetPath);
    } catch (error) {
      return FileSaveFailed(error);
    }
  }

  /// Returns [path] guaranteed to end with the canonical [extension] derived
  /// from the export format.
  ///
  /// The classic Win32 save dialog used by `file_picker` 8.x never sets
  /// `lpstrDefExt`, so a user who types `timetable` instead of
  /// `timetable.pdf` receives an extensionless path unless it is normalised.
  /// The comparison is case-insensitive to match Windows' case-insensitive
  /// file systems and to avoid producing `file.PDF.pdf`.
  static String ensureCanonicalExtension(String path, String extension) {
    final normalisedExtension = extension.startsWith('.')
        ? extension.toLowerCase()
        : '.${extension.toLowerCase()}';
    if (path.toLowerCase().endsWith(normalisedExtension)) {
      return path;
    }
    return '$path$normalisedExtension';
  }

  /// Confirms the file on disk matches what was supposed to be written.
  ///
  /// Throws [FileSystemException] when the verification fails, which the
  /// caller maps to [FileSaveFailed] — no false "saved" messages, ever.
  static void _verifyWrite(String path, int expectedLength) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('file was not created', path);
    }
    final actualLength = file.lengthSync();
    if (actualLength != expectedLength) {
      throw FileSystemException(
        'file size mismatch (expected $expectedLength bytes, found $actualLength)',
        path,
      );
    }
  }

  /// Default dialog implementation backed by `file_picker`.
  static Future<String?> _pickSaveLocationViaFilePicker({
    String dialogTitle = 'حفظ الملف',
    String fileName = '',
    List<String> allowedExtensions = const <String>[],
    Uint8List? bytes,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      lockParentWindow: true,
      bytes: bytes,
    );
  }

  /// Persists [bytes] at [path] atomically.
  ///
  /// Writing straight to the destination can leave a truncated file behind if
  /// the process or disk fails mid-write. We therefore write to a sibling
  /// temporary file first, flush it to disk, then move it over the target.
  /// File systems that reject the rename while the destination exists (FAT32
  /// device drivers, quirky AV filters) fall back to a direct write.
  static Future<void> _writeAtomicFile(String path, Uint8List bytes) async {
    final tempPath = _temporarySiblingPath(path);
    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      try {
        await tempFile.rename(path);
      } on FileSystemException {
        // Rename refused (e.g. certain drive formats); write directly.
        await File(path).writeAsBytes(bytes, flush: true);
      }
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // A leftover *.tmp file is a nuisance, not a data problem.
        }
      }
    }
  }

  static String _temporarySiblingPath(String path) {
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final seed = utf8.encode('$path:$nonce').fold<int>(
          0x811c9dc5,
          (hash, byte) => (hash ^ byte) * 0x01000193 & 0x7fffffff,
        );
    return '$path.$seed.jadwal_tmp';
  }
}
