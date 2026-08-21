# التقرير النهائي لفحص EXE وDLL

## النتيجة المختصرة

تم فحص حزم ZIP الناتجة حديثًا لفرعي Windows 10/11 وWindows 7. تمت قراءة جدول PE imports لكل ملف EXE وDLL، ومقارنة المراجع المحلية داخل الحزمة، والبحث عن `GetHostNameW`.

| الحزمة | الملفات المفحوصة | اسم EXE | `GetHostNameW` | مراجع DLL محلية مفقودة |
|---|---:|---|---|---:|
| Windows 10 و11 | 12 | `JadwalV2_Windows10_11.exe` | موجود داخل `flutter_windows.dll`، وهذا متوقع لهذا النظام | 0 |
| Windows 7 | 11 | `JadwalV2_Windows7.exe` | غير موجود؛ يستخدم `gethostname` القديم | 0 |

## تفسير صورة الخطأ

الخطأ الظاهر في الصورة هو:

> `The procedure entry point GetHostNameW could not be located in the dynamic link library WS2_32.dll.`

هذا يعني أن الملف الذي تم تشغيله هو محرك Flutter حديث أو حزمة Windows 10/11 تعمل على Windows 7. لا يعني الخطأ أن `WS2_32.dll` مفقود من مجلد البرنامج. ملف `WS2_32.dll` ملف نظام Windows، ولا يجوز نسخه من Windows 10 أو Windows 11 إلى Windows 7 أو استبداله يدويًا.

الحزمة الجديدة الخاصة بـWindows 7 تستخدم محرك Flutter 3.16.9 وتبين نتيجة الفحص أنها لا تستورد `GetHostNameW`. لذلك يجب التأكد من أن المستخدم شغّل `JadwalV2_Windows7.exe` من مجلد ZIP الخاص بـWindows 7، وليس نسخة Windows 10/11 أو ZIP قديمًا باسم عام `jadwal_v2.exe`.

توثيق Flutter الحالي يصنف Windows 10 و11 كمنصات مدعومة وWindows 8 وما قبله كمنصات غير مدعومة.[^1] وتوضح مناقشة Flutter الرسمية أن دعم Windows 7 وWindows 8 أُسقط في خط Flutter الحديث، وأن `GetHostNameW` سبب معروف لفشل Flutter الحديث على Windows 7.[^2]

## الأسماء الجديدة للتمييز

| الهدف | اسم البرنامج | الملف التنفيذي | ZIP | Setup |
|---|---|---|---|---|
| Windows 10 و11 | Jadwal V2 - Windows 10 and 11 | `JadwalV2_Windows10_11.exe` | `Jadwal-V2-Windows-10-11-1.0.0.zip` | `Jadwal-V2-Windows-10-11-1.0.0-Setup.exe` |
| Windows 7 | Jadwal V2 - Windows 7 | `JadwalV2_Windows7.exe` | `Jadwal-V2-Windows-7-1.0.0.zip` | `Jadwal-V2-Windows-7-1.0.0-Setup.exe` |

كما تم تغيير اسم النافذة وخصائص الملف والاختصارات ومجلد التثبيت واسم artifact في GitHub Actions. لم يعد من المفترض أن تظهر النسختان باسم `jadwal_v2.exe` أو `Jadwal-V2-Windows-1.0.0.zip`.

## مراجعة DLLs

الحزمتان تحتويان على جميع DLLs المحلية التي يستوردها executable. في نسخة Windows 10/11 توجد `flutter_windows.dll` و`dartjni.dll` و`gal_plugin.dll` و`isar.dll` و`isar_flutter_libs_plugin.dll` و`pdfium.dll` و`printing_plugin.dll` و`screen_retriever_windows_plugin.dll` و`share_plus_plugin.dll` و`url_launcher_windows_plugin.dll` و`window_manager_plugin.dll`. وفي نسخة Windows 7 توجد المكونات المناظرة، مع اسم `screen_retriever_plugin.dll` المتوافق مع النسخة القديمة.

لم يظهر أي import إلى DLL محلي غير موجود. أما DLLs مثل `KERNEL32.dll` و`USER32.dll` و`WS2_32.dll` و`OLE32.dll` و`DWMAPI.dll` و`UIAutomationCore.dll` فهي DLLs نظامية، ولا ينبغي وضع نسخ بديلة منها داخل مجلد البرنامج.

تحتاج الحزمتان إلى Microsoft Visual C++ Runtime، بما في ذلك `MSVCP140.dll` و`VCRUNTIME140.dll` و`VCRUNTIME140_1.dll` وبعض `api-ms-win-crt-*.dll`. إذا ظهر خطأ جديد متعلقًا بهذه الملفات على جهاز نظيف، يجب تثبيت Microsoft Visual C++ Redistributable المناسب x64 من Microsoft، لا تنزيل DLL منفرد من مواقع غير موثوقة.

## نتيجة البناء

نجح بناء نسخة Windows 10/11 بعد إعادة التسمية عبر تشغيل GitHub Actions رقم [32531500140](https://github.com/kinanmjeed88/jadwalv2/actions/runs/32531500140)، ونجح بناء نسخة Windows 7 بعد إعادة التسمية عبر التشغيل رقم [32531548066](https://github.com/kinanmjeed88/jadwalv2/actions/runs/32531548066). شمل ذلك التحليل والاختبارات والبناء واختبار التشغيل والتغليف.

نجاح Smoke Test يثبت أن البرنامج بدأ على runner الخاص بـGitHub، لكنه لا يثبت وحده تشغيل Windows 7 على كل جهاز حقيقي. يجب اختبار `JadwalV2_Windows7.exe` على Windows 7 SP1 x64 فعليًا. لا تستخدم نسخة Windows 10/11 على Windows 7.

## حماية APK

تغييرات التسمية وفحص DLL محصورة في فرعي Windows. يبقى APK في `main` ويُبنى من `lib/main.dart` عبر workflow Android مستقل. لم يتم تغيير `android/` أو `lib/main.dart` ضمن تغييرات التسمية الحالية.

## المراجع

[^1]: [Flutter — Supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)

[^2]: [Flutter issue #149124 — 3.22.1 does not support win7](https://github.com/flutter/flutter/issues/149124)

[^3]: [Microsoft Learn — Application manifests](https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests)
