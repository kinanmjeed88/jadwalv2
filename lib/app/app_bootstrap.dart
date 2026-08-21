import 'package:flutter/material.dart';

void installErrorHandlers({
  void Function(Object error, StackTrace? stackTrace)? onError,
}) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    onError?.call(details.exception, details.stack);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '🚨 CRITICAL RENDER ERROR:\n\n${details.exceptionAsString()}\n\n${details.stack.toString()}',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  };
}
