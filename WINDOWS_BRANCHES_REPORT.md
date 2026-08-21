# تقرير تسليم فروع Windows

## الفروع المنشأة

| الاستخدام | اسم الفرع في GitHub | commit الأخير | النتيجة |
|---|---|---|---|
| Windows 10 وWindows 11 | `برنامج-مخصص-لوندوز-١٠-و-١١` | `260bf0b` | تم البناء بنجاح |
| Windows 7 | `برنامج-مخصص-لوندوز-٧` | `4763339` | تم البناء بنجاح على CI، مع ضرورة اختبار التشغيل على جهاز Windows 7 فعلي |
| الفرع الرئيسي | `main` | `9d3a215` | لم يتغير |

استخدمت أسماء الفروع شرطات بدل المسافات لأن Git يرفض أسماء المراجع التي تحتوي مسافات؛ بقي الاسم العربي والمعنى المطلوبان محفوظين.

## نتائج البناء

بناء فرع Windows 10 و11 نجح في GitHub Actions عبر التشغيل [32525739555](https://github.com/kinanmjeed88/jadwalv2/actions/runs/32525739555). استخدم Flutter المستقر الحالي، ونقطة الدخول `lib/main_windows.dart`، وأنتج ملف ZIP ومثبت Inno Setup.

بناء فرع Windows 7 نجح في GitHub Actions عبر التشغيل [32529483563](https://github.com/kinanmjeed88/jadwalv2/actions/runs/32529483563). استخدم Flutter 3.16.9، وmanifest خاصًا بـWindows 7، ونجح في `flutter analyze` والاختبارات وبناء Windows وSmoke Test والتغليف. لم يتم تشغيل الملف التنفيذي على جهاز Windows 7 حقيقي داخل هذه البيئة؛ لذلك لا أصف ذلك بأنه ضمان دعم نهائي.

## حماية APK

لم يتم تعديل `main`، كما أن APK بقي مرتبطًا بنقطة الدخول `lib/main.dart` في workflow Android. مسار Windows يستخدم `lib/main_windows.dart`. فرع Windows 7 يحذف مجلد Android من مساحة CI المؤقتة فقط كي يستطيع Flutter 3.16 حل الاعتمادات القديمة، ولا يحذف ملفات Android من المستودع ولا يغير APK في `main`.

## المخرجات

تم تنزيل مخرجات البناء من GitHub Actions. لكل فرع يوجد ZIP للتوزيع ومثبت Inno Setup بصيغة EXE. نسخة Windows 7 مبنية تقنيًا بنجاح، لكن اختبارها النهائي يجب أن يتم على Windows 7 SP1 x64 حقيقي بسبب إسقاط Flutter الحديث دعم Windows 7 وWindows 8.[^1] [^2]

## المراجع

[^1]: [Flutter — Supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)

[^2]: [Flutter issue #149124 — 3.22.1 does not support win7](https://github.com/flutter/flutter/issues/149124)
