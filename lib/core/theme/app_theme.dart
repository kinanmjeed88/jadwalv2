import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
      fontFamily: 'Cairo', // Will be using an Arabic font. Assuming Cairo for now
    );
  }
}
