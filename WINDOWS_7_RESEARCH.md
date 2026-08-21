# Windows 7 compatibility research

- Flutter issue #149124 documents that Flutter 3.22.1 fails on Windows 7 because `flutter_windows.dll` depends on `GetHostNameW`; the issue discussion states that Flutter dropped Windows 7 and Windows 8 support with Flutter 3.19.
- Current Flutter supported-platforms documentation (Flutter 3.44.7) lists Windows 10 and 11 as supported, Windows 8 and earlier as unsupported.
- Therefore this branch is a compatibility attempt based on an older Flutter SDK line, not a currently supported Flutter target. A real Windows 7 executable must be tested on a clean Windows 7 SP1 x64 machine.

Sources:
- https://github.com/flutter/flutter/issues/149124
- https://docs.flutter.dev/reference/supported-platforms
