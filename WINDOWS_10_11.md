# برنامج مخصص لوندوز ١٠ و ١١

هذا الفرع مخصص لبناء نسخة Windows Desktop على Windows 10 وWindows 11 فقط.

يستخدم البناء نقطة الدخول:

```bash
flutter build windows --release --target=lib/main_windows.dart
```

وتعلن `windows/runner/runner.exe.manifest` دعم Windows 10 وWindows 11 عبر `supportedOS`. لا يُستهدف Windows 7 بهذا الفرع.

يظل تطبيق Android منفصلًا ويُبنى من:

```bash
flutter build apk --release --target=lib/main.dart
```

لا تُستورد خدمات `window_manager` أو حالة النافذة أو سجل سطح المكتب من نقطة دخول APK.
