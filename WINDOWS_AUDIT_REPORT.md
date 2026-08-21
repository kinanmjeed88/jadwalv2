# تقرير فحص وعزل نسخة Windows

## النتيجة التنفيذية

المشروع هو تطبيق Flutter متعدد المنصات، وليس برنامج Windows مستقلًا بالكامل. قبل التعديل، كان `lib/main.dart` نقطة الدخول المشتركة، وكان يهيئ `window_manager` وخدمات حالة النافذة وسجل أخطاء سطح المكتب عندما تكون المنصة Windows أو Linux أو macOS. أما Android فكان يمر من النقطة نفسها، مع تخطي تهيئة سطح المكتب بسبب شرط المنصة.

ملف Windows نفسه يعلن صراحةً دعم **Windows 10 وWindows 11** فقط، ولا يعلن Windows 7. لذلك لا ينبغي اعتبار Windows 7 منصة مدعومة لهذه النسخة.

تم تنفيذ عزل فعلي في فرع مستقل باسم `feat/windows-isolated-entrypoint`، من دون دمجه في `main`. أصبح APK يستخدم `lib/main.dart`، وأصبحت نسخة Windows تستخدم `lib/main_windows.dart`. كما تم تثبيت هذين المسارين داخل workflows البناء حتى لا تختلط نقطة دخول Windows مع نقطة دخول APK.

## طريقة عمل Windows الحالية قبل العزل

| الجزء | الوضع الذي وجدته |
|---|---|
| الإطار | Flutter Desktop native Windows |
| نقطة الدخول | `lib/main.dart` المشتركة |
| تهيئة النافذة | `window_manager.ensureInitialized()` ثم نافذة ابتدائية 1280×768 وحد أدنى 1024×768 |
| حفظ حالة النافذة | ملف `window_state.json` داخل Application Support، مع استعادة الحجم والموقع والتكبير |
| سجل الأخطاء | ملف `errors.log` داخل Application Support |
| البناء | `flutter build windows --release` داخل GitHub Actions على `windows-latest` |
| التوزيع | ZIP ومثبت Inno Setup، مع توقيع اختياري |
| Android/APK | workflow مستقل على `ubuntu-latest` يبني APK ويستخدم نفس `lib/main.dart` افتراضيًا |

الفرع الأصلي كان يفصل APK عن Windows **وقت التشغيل** فقط؛ أي إن شرط المنصة يمنع استدعاء خدمات النافذة على Android، لكنه لا يفصل نقطة الدخول ولا workflow بصورة صريحة. كذلك كان `isDesktop` يشمل Linux وmacOS، لذلك الكود ليس Windows-only من الناحية المنطقية، بل هو مسار Desktop عام.

## إصدار Windows المستهدف

الملف `windows/runner/runner.exe.manifest` يحتوي على المعرف التالي:

> `{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}`

وفق توثيق Microsoft، هذا المعرف يوافق Windows 10 وWindows 11. كما يعلن الملف `PerMonitorV2` لـDPI، وهو إعداد حديث مرتبط بإصدارات Windows الحديثة. النتيجة العملية هي أن النسخة الحالية مخصصة لـ**Windows 10 وWindows 11، غالبًا x64** عبر مسار Flutter Windows x64، وليست مخصصة لـWindows 7.

| النظام | الحكم |
|---|---|
| Windows 7 | غير مستهدف وغير موصى به |
| Windows 10 | مستهدف |
| Windows 11 | مستهدف |

هذا يتوافق أيضًا مع كون Flutter الحالي يوجه بناء تطبيقات Windows إلى بيئة Visual Studio وتطوير C++ لسطح المكتب، ومع إعلان الحزم المستخدمة لإدارة النافذة واسترجاع الشاشات دعم Linux وmacOS وWindows فقط.[^1] [^2] [^3]

## العزل الذي تم تنفيذه

أُضيفت نقطة دخول Windows مستقلة في `lib/main_windows.dart`. هذه النقطة فقط تستورد `window_manager` و`DesktopErrorLogService` و`DesktopWindowStateService`، وتهيئها قبل تشغيل الواجهة المشتركة.

أصبح `lib/main.dart` مخصصًا لمسار APK والويب، ولا يحتوي على استيراد `window_manager` أو `screen_retriever` أو خدمات سطح المكتب أو `dart:io`. وتم استخراج الواجهة المشتركة إلى `lib/app/jadwal_app.dart`، ومعالجة الأخطاء إلى `lib/app/app_bootstrap.dart`، حتى لا تضطر نقطة دخول Windows إلى استيراد `main.dart` أو العكس.

تم أيضًا تعديل workflow الخاص بـAndroid إلى:

```bash
flutter build apk --release --target=lib/main.dart
```

وworkflow الخاص بـWindows إلى:

```bash
flutter build windows --release --target=lib/main_windows.dart
```

بهذا أصبح اختيار نقطة الدخول صريحًا في كل بناء. لم تُعدّل ملفات `android/app` أو Manifest Android أو إعدادات Gradle الخاصة بالتطبيق. كما بقي بناء APK في workflow منفصل عن بناء Windows.

## التحقق من عدم تأثر APK

أُجريت الفحوص التالية على الفرع المعزول:

| الفحص | النتيجة |
|---|---|
| `git diff --check` | ناجح |
| عدم وجود مراجع Windows في `lib/main.dart` | ناجح |
| وجود مراجع `window_manager` وخدمات سطح المكتب في `lib/main_windows.dart` فقط كنقطة دخول | ناجح |
| تثبيت `--target=lib/main.dart` في APK workflow | ناجح |
| تثبيت `--target=lib/main_windows.dart` في Windows workflow | ناجح |
| بقاء فرع `main` دون تعديل | ناجح؛ بقي commit الرئيسي `9d3a21547c7f4e36a1831ff9da7eafb6e2461daf` |
| فرع التعديل | `927399b58bd96f03919c351506491eacfcd44d1e` |

بيئة الفحص الحالية لا تحتوي Flutter أو Dart، لذلك لم أستطع تنفيذ `flutter analyze` أو بناء APK/Windows محليًا. كما أن محاولة تشغيل CI عن بُعد لم تُنشئ تشغيلًا ظاهرًا في سجل GitHub؛ لذلك يجب اعتبار التحقق الحالي **تحققًا ساكنًا وبنيويًا**، وينبغي تشغيل البناءين في بيئة Flutter قبل الدمج.

## مكان التغيير

التغييرات موجودة في فرع GitHub التالي، وليس في `main`:

[feat/windows-isolated-entrypoint](https://github.com/kinanmjeed88/jadwalv2/tree/feat/windows-isolated-entrypoint)

والـcommit هو:

[927399b — feat: isolate Windows entrypoint from APK](https://github.com/kinanmjeed88/jadwalv2/commit/927399b58bd96f03919c351506491eacfcd44d1e)

أوصي بعدم دمج الفرع في `main` إلا بعد نجاح الأمرين التاليين في CI أو على جهاز تطوير Windows/Android:

```bash
flutter analyze
flutter build apk --release --target=lib/main.dart
flutter build windows --release --target=lib/main_windows.dart
```

## المراجع

[^1]: [Flutter — Supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)

[^2]: [Flutter — Set up Windows development](https://docs.flutter.dev/platform-integration/windows/setup)

[^3]: [window_manager — Platform Support](https://pub.dev/packages/window_manager) و [screen_retriever — Platform Support](https://pub.dev/packages/screen_retriever)

[^4]: [Microsoft Learn — Application manifests](https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests)

[^5]: [المستودع الأصلي jadwalv2](https://github.com/kinanmjeed88/jadwalv2)
