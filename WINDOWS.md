# Windows desktop build

يستخدم المشروع نقطتي دخول منفصلتين لتقليل احتمال تأثر تطبيق Android بأي تهيئة خاصة بسطح المكتب.

| الهدف | نقطة الدخول | أمر البناء |
|---|---|---|
| Android APK | `lib/main.dart` | `flutter build apk --release --target=lib/main.dart` |
| Windows desktop | `lib/main_windows.dart` | `flutter build windows --release --target=lib/main_windows.dart` |

`lib/main.dart` لا يستورد `window_manager` ولا خدمات حالة النافذة أو سجل أخطاء سطح المكتب. أما `lib/main_windows.dart` فيهيئ هذه الخدمات صراحةً قبل تشغيل الواجهة المشتركة.

نسخة Windows الحالية مبنية على Flutter Desktop x64 وتُنتج حزمة ZIP ومثبت Inno Setup عبر `.github/workflows/build_windows.yml`. ملف `windows/runner/runner.exe.manifest` يعلن دعم Windows 10 وWindows 11؛ لا ينبغي اعتبار Windows 7 نظامًا مستهدفًا لهذه النسخة.

يجب إبقاء مسار APK مثبتًا على `lib/main.dart`، ومسار Windows مثبتًا على `lib/main_windows.dart`. أي إضافة مستقبلية خاصة بسطح المكتب يجب أن تُستورد من `main_windows.dart` أو من طبقة desktop منفصلة، لا من `main.dart`.
