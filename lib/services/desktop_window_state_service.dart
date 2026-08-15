import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset, Size;

import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowStateService with WindowListener {
  DesktopWindowStateService._(this._stateFile);

  final File _stateFile;
  Timer? _saveTimer;

  static Future<DesktopWindowStateService> initialize() async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final service = DesktopWindowStateService._(
      File(
          '${appSupportDirectory.path}${Platform.pathSeparator}window_state.json'),
    );
    windowManager.addListener(service);
    return service;
  }

  Future<void> restore() async {
    try {
      if (!await _stateFile.exists()) return;

      final decoded = jsonDecode(await _stateFile.readAsString());
      if (decoded is! Map<String, dynamic>) return;

      final width = _readPositiveDouble(decoded['width']);
      final height = _readPositiveDouble(decoded['height']);
      final left = _readFiniteDouble(decoded['left']);
      final top = _readFiniteDouble(decoded['top']);

      if (width != null && height != null) {
        await windowManager.setSize(Size(width, height));
      }
      if (left != null && top != null) {
        final restoredSize = Size(width ?? 1280, height ?? 768);
        final safePosition = await _keepPositionVisible(
          Offset(left, top),
          restoredSize,
        );
        await windowManager.setPosition(safePosition);
      }
      if (decoded['maximized'] == true) {
        await windowManager.maximize();
      }
    } catch (_) {
      // A damaged state file must never prevent the application from starting.
    }
  }

  Future<Offset> _keepPositionVisible(Offset position, Size size) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      for (final display in displays) {
        final visiblePosition = display.visiblePosition ?? Offset.zero;
        final visibleSize = display.visibleSize ?? display.size;
        final visibleRect = visiblePosition & visibleSize;
        final windowRect = position & size;
        if (visibleRect.overlaps(windowRect)) {
          return Offset(
            _clamp(
              position.dx,
              visibleRect.left - size.width + 80,
              visibleRect.right - 80,
            ),
            _clamp(
              position.dy,
              visibleRect.top - size.height + 80,
              visibleRect.bottom - 80,
            ),
          );
        }
      }

      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final visiblePosition = primaryDisplay.visiblePosition ?? Offset.zero;
      final visibleSize = primaryDisplay.visibleSize ?? primaryDisplay.size;
      return Offset(
        visiblePosition.dx + (visibleSize.width - size.width) / 2,
        visiblePosition.dy + (visibleSize.height - size.height) / 2,
      );
    } catch (_) {
      return position;
    }
  }

  static double _clamp(double value, double minimum, double maximum) {
    if (maximum < minimum) return minimum;
    return value.clamp(minimum, maximum).toDouble();
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    try {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final maximized = await windowManager.isMaximized();

      await _stateFile.parent.create(recursive: true);
      await _stateFile.writeAsString(
        jsonEncode({
          'width': size.width,
          'height': size.height,
          'left': position.dx,
          'top': position.dy,
          'maximized': maximized,
        }),
        flush: true,
      );
    } catch (_) {
      // Window state persistence is best-effort and must not affect the app.
    }
  }

  static double? _readPositiveDouble(Object? value) {
    final number = _readFiniteDouble(value);
    return number != null && number > 0 ? number : null;
  }

  static double? _readFiniteDouble(Object? value) {
    final number = value is num ? value.toDouble() : null;
    return number != null && number.isFinite ? number : null;
  }
}
