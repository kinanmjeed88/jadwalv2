# برنامج مخصص لوندوز ٧

هذا الفرع منفصل عن فرع Windows 10 و11 وعن `main`، ويستخدم محاولة توافق خاصة مع Windows 7 SP1 x64.

## طريقة البناء

يستخدم workflow الخاص بهذا الفرع Flutter 3.16.9 وrunner من نوع Windows 2022، ثم يبني من نقطة الدخول المعزولة:

```bash
flutter build windows --release --target=lib/main_windows.dart
```

تم تعديل manifest إلى GUID الخاص بـWindows 7، واستُبدل `PerMonitorV2` بإعداد DPI أقدم مناسب للنظام. كما خُفضت بعض الحزم التي تتطلب Flutter 3.19 أو أحدث. وأزيل اعتماد `gal` من هذا الفرع فقط؛ التطبيق لا يستعمله، وكان `gal_plugin.dll` يستورد `api-ms-win-core-libraryloader-l1-2-0.dll` غير المتوفر في Windows 7. وتستخدم نقطة دخول Windows واجهة مكتبية مستقلة لا تستورد Firebase أو خدمة analytics الخاصة بالـAPK. يحذف CI مجلد Android من مساحة البناء المؤقتة فقط حتى لا يفحص Flutter 3.16 embedding القديم؛ ملفات Android الأصلية لا تُحذف من المستودع.

## التحذير المهم

Flutter الحديث لا يدعم Windows 7. توثيق Flutter الحالي يصنف Windows 10 و11 كمنصات مدعومة، ويصنف Windows 8 وما قبله كمنصات غير مدعومة. كما أن Flutter 3.19 أسقط دعم Windows 7 وWindows 8، وقد ظهرت في Flutter 3.22 مشكلة تشغيل بسبب اعتماد `flutter_windows.dll` على `GetHostNameW` غير المتوفر بالطريقة المطلوبة في Windows 7.

لذلك فهذا الفرع **ليس ضمانًا نهائيًا لتشغيل Windows 7** قبل اختبار ملف التنفيذ الناتج على جهاز Windows 7 SP1 x64 نظيف. لا تنسخ أي DLL نظام من Windows 10/11 إلى Windows 7. إذا ظهر خطأ جديد في DLL، يجب تحديد المستورد أولًا وإزالة الإضافة غير المتوافقة أو إعادة بنائها بإعدادات Win7، وليس تعديل APK.

## عزل APK

يبقى APK على نقطة الدخول `lib/main.dart`، بينما Windows يستخدم `lib/main_windows.dart`. لا ينبغي دمج هذا الفرع في `main` أو استخدامه لبناء APK.
