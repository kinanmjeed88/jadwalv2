# Windows EXE/DLL audit

## Result

تم فحص كل ملفات `.exe` و`.dll` الموجودة في حزمة كل نسخة بقراءة جدول PE imports دون تشغيل الملفات.

| النسخة | عدد ملفات PE المفحوصة | `GetHostNameW` | DLLs محلية مفقودة حسب imports |
|---|---:|---|---:|
| Windows 10/11 | 12 | موجودة داخل `flutter_windows.dll` من `WS2_32.dll` | لا يوجد |
| Windows 7 | 11 | غير موجودة؛ الموجود هو `gethostname` القديم | لا يوجد |

## تفسير الخطأ في الصورة

الرسالة `The procedure entry point GetHostNameW could not be located in WS2_32.dll` تعني أن البرنامج الذي تم تشغيله يحتوي على محرك Flutter حديث يطلب `GetHostNameW`، ثم يحاول Windows 7 تحميله من `WS2_32.dll` التي لا توفر هذه الدالة بالطريقة المطلوبة. هذا ليس نقصًا في ملف `flutter_windows.dll` داخل مجلد البرنامج، وليس من الآمن نسخ `WS2_32.dll` من Windows 10 أو Windows 11 إلى Windows 7.

الحزمة القديمة العامة التي ظهر اسمها في الصورة كانت قابلة للخلط بين النسختين. لذلك أصبحت أسماء النسخ الجديدة صريحة:

| الهدف | الملف التنفيذي | ZIP | Setup |
|---|---|---|---|
| Windows 10 و11 | `JadwalV2_Windows10_11.exe` | `Jadwal-V2-Windows-10-11-<version>.zip` | `Jadwal-V2-Windows-10-11-<version>-Setup.exe` |
| Windows 7 | `JadwalV2_Windows7.exe` | `Jadwal-V2-Windows-7-<version>.zip` | `Jadwal-V2-Windows-7-<version>-Setup.exe` |

## DLL dependency conclusions

تتضمن الحزمتان ملفات Flutter والإضافات المحلية التي يشير إليها executable، ولم يظهر أي import إلى DLL محلي غير موجود داخل الحزمة. تعتمد الحزمتان أيضًا على DLLs نظام Windows مثل `KERNEL32.dll` و`USER32.dll` و`WS2_32.dll`، وعلى Microsoft Visual C++ runtime مثل `MSVCP140.dll` و`VCRUNTIME140.dll` و`VCRUNTIME140_1.dll` و`api-ms-win-crt-*.dll`.

يجب توفير Microsoft Visual C++ Redistributable المناسب على الجهاز المستهدف أو تضمينه في عملية التثبيت وفق ترخيص Microsoft. لا ينبغي تضمين DLLs النظام مثل `WS2_32.dll` أو استبدالها يدويًا.

## حالة Windows 7

فرع Windows 7 يستخدم Flutter 3.16.9، ونسخًا أقدم من بعض الحزم، وmanifest خاصًا بـWindows 7، كما أن build ينتج `flutter_windows.dll` لا يستورد `GetHostNameW`. نجح بناء CI وSmoke Test للحزمة، لكن التشغيل النهائي يجب اختباره على Windows 7 SP1 x64 حقيقي؛ لأن Flutter الحديث لا يدعم Windows 7 رسميًا.

## حماية APK

لم تُعدّل ملفات APK أو `lib/main.dart` في تغييرات تسمية Windows وفحص DLL. يبقى APK مبنيًا من workflow Android مستقل ونقطة الدخول `lib/main.dart`.
